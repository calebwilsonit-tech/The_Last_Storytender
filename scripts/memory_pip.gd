extends LevelBase
## Pip's memory: "The Unfinished Library". A pop-up storybook where Pip peeked at the
## ending and decided every story ends badly. A hub of rooms (see docs/dungeon_plans/pip_library.png):
##  Front Matter      - learn to REWRITE a sentence with the Quill (the bridge), then the Reading Hall (hub).
##  The Dark Wood     - sleep the wolves, open the gate, freeze the river and leave an Echo on the ledge plate. Page I.
##  The Tall Tower    - Lantern bars across the stair, a missing flight, a floor that must be written solid. Page II.
##  The Margin Archive - sleep the guards, open the way, read the lock sentence, hold two plates. Page III.
##  The Last Page     - The Spoiler (unchanged). Three Torn Pages open its door.

const OVERWORLD := "res://scenes/main.tscn"
const RETURN_CELL := Vector2i(26, 13) + PrologueMap.OFFSET
const ICE_TIME := 12.0
const FLOOR_TIME := 10.0
const R_FRONT := 0
const R_HALL := 1
const R_WOOD := 2
const R_TOWER := 3
const R_ARCHIVE := 4
const R_LAST := 5
const ECHO_GATES := [["u", ["k"]], ["y", ["m", "n"]]]
const GATE_SPEC := {"G": [Vector2(1, 0), 3.0], "u": [Vector2(1, 0), 3.0], "v": [Vector2(1, 0), 3.0], "w": [Vector2(1, 0), 3.0], "y": [Vector2(1, 0), 3.0]}
const PAGES := {"f": 1, "F": 2, "N": 3}
const WOLF_SLEEP := 18.0
const REGIONS := {
	"WEST": Vector2i(32, 2), "EAST": Vector2i(39, 2), "NORTH": Vector2i(36, 1),
	"SOUTH": Vector2i(36, 4), "MIDDLE": Vector2i(36, 3),
}
const WOLF_SIDES := {
	"WEST": [Vector2i(31, 3), Vector2i(31, 2), Vector2i(31, 4)], "EAST": [Vector2i(40, 3), Vector2i(40, 4), Vector2i(40, 2)],
	"NORTH": [Vector2i(35, 0), Vector2i(37, 0), Vector2i(36, 0)],
}

var _enemy_spawns: Array[Dictionary] = []
var _stone_bridge: SentenceStone
var _stone_gate: SentenceStone
var _gate: StoryGate
var _gate_nodes: Dictionary = {}       # char -> StoryGate
var _plate_nodes: Dictionary = {}      # char -> EchoPlate
var _stones: Dictionary = {}           # char -> SentenceStone
var _sleepers := {"wood": {"t": 0.0, "stone": "b", "enemies": []}, "archive": {"t": 0.0, "stone": "i", "enemies": []}}
var _temps := {"river": {"cells": [], "t": 0.0, "stone": "d", "dur": ICE_TIME}, "floor": {"cells": [], "t": 0.0, "stone": "h", "dur": FLOOR_TIME}}
var _pages := {}
var _lock_read := false
var _y_seen := false
var _w_seen := false
var _door: StoryGate
var _spoiler: Spoiler
var _pip: Prop
var _arena_cells: Array[Vector2i] = []
var _hazards: Array[Dictionary] = []
var _wolves_t := 0.0
var _rewrites := 0
var _boss_started := false
var _finale_done := false
var _leaving := false
var _room_seen := {}
var _darkness := 0.0

# --- LevelBase hooks ------------------------------------------------------------------------
func _music_slot() -> String:
	return "memory_pip"

func _dungeon_extras() -> Array:
	return [
		{"kind": "post", "cell": Vector2i(16, 12)},
		{"kind": "post", "cell": Vector2i(38, 12)},
		{"kind": "vault", "cell": Vector2i(8, 14), "tier": 1},
		{"kind": "vault", "cell": Vector2i(26, 22), "tier": 2},
		{"kind": "vault", "cell": Vector2i(56, 17), "tier": 3},
	]

func _map_rows() -> Array[String]:
	return MemoryPipMap.ROWS

func _map_heights() -> Array[String]:
	return MemoryPipMap.HEIGHTS

func _paper_params() -> Dictionary:
	return {"paper_light": Color(0.55, 0.74, 0.86), "paper_dark": Color(0.38, 0.56, 0.74),
		"script_color": Color(1, 1, 1), "script_strength": 0.10, "vignette": 0.5}

func _make_stone(cell: Vector2i, prefix: String, options: Array, suffix: String = ".") -> SentenceStone:
	var st := SentenceStone.new()
	st.prefix = prefix
	st.options = PackedStringArray(options)
	st.suffix = suffix
	st.position = Iso.to_screen(Vector2(cell))
	st.elev = _lift_at(cell)
	_actors.add_child(st)
	_register(st, func(): return "Rewrite" if not st.locked else "", func(): st.rewrite(), 80.0)
	return st

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	if ch in "pPETCabcdehijGHgxRSfFNZYklmnuvwy":
		_floor.cells[cell] = "p"
	match ch:
		"P":
			_start = Iso.to_screen(Vector2(cell))
		"E":
			var portal := _add_prop(Prop.Kind.PORTAL, cell)
			_register(portal, func(): return "" if _leaving else "Leave the memory", _leave, 70.0)
		"T":
			_add_prop(Prop.Kind.TREE, cell, false, cell.x + cell.y)
		"C":
			_crystals.append(_add_prop(Prop.Kind.CRYSTAL, cell))
		"a":
			_stone_bridge = _make_stone(cell, "The bridge", ["BREAKS", "HOLDS"])
			_stone_bridge.rewritten.connect(_on_bridge)
		"b":
			_stones[ch] = _make_stone(cell, "The wolves are", ["HUNGRY", "ASLEEP"])
			_stones[ch].rewritten.connect(func(_s, idx): _on_sleepers("wood", idx))
		"i":
			_stones[ch] = _make_stone(cell, "The guards are", ["AWAKE", "ASLEEP"])
			_stones[ch].rewritten.connect(func(_s, idx): _on_sleepers("archive", idx))
		"c":
			_stone_gate = _make_stone(cell, "The gate is", ["LOCKED", "OPEN"])
			_stone_gate.rewritten.connect(_on_gate)
		"d":
			_stones[ch] = _make_stone(cell, "The river is", ["FLOWING", "FROZEN"])
			_stones[ch].rewritten.connect(func(_s, idx): _on_temp("river", idx))
		"h":
			_stones[ch] = _make_stone(cell, "The floor is", ["GONE", "SOLID"])
			_stones[ch].rewritten.connect(func(_s, idx): _on_temp("floor", idx))
		"e":
			_stones[ch] = _make_stone(cell, "The stairs are", ["MISSING", "PRESENT"])
			_stones[ch].rewritten.connect(func(st, idx): _on_open_gate("v", st, idx, "The stairs are there. They always were; nobody had written them down."))
		"j":
			_stones[ch] = _make_stone(cell, "The door is", ["LOCKED", "OPEN"])
			_stones[ch].rewritten.connect(func(st, idx): _on_lock_sentence(st, idx))
		"k", "l", "m", "n":
			var plate := EchoPlate.new()
			plate.floor_ref = _floor
			plate.position = Iso.to_screen(Vector2(cell))
			plate.elev = _lift_at(cell)
			_actors.add_child(plate)
			_plate_nodes[ch] = plate
		"G", "u", "v", "w", "y":
			var gate := StoryGate.new()
			gate.axis = GATE_SPEC[ch][0]
			gate.length = GATE_SPEC[ch][1]
			gate.label = "WRITTEN SHUT" if ch in "Gv" else "FORGOTTEN"
			gate.position = Iso.to_screen(Vector2(cell))
			gate.elev = _lift_at(cell)
			_actors.add_child(gate)
			_gate_nodes[ch] = gate
			if ch == "G":
				_gate = gate
		"H":
			_door = StoryGate.new()
			_door.axis = Vector2(1, 0)
			_door.length = 3.0
			_door.label = "THE END  0/3"
			_door.position = Iso.to_screen(Vector2(cell))
			_door.elev = _lift_at(cell)
			_actors.add_child(_door)
			_register(_door, _door_prompt, _use_door, 130.0)
		"g", "x":
			_enemy_spawns.append({"kind": Enemy.Kind.BARE if ch == "g" else Enemy.Kind.MITE, "cell": cell})
		"R", "S":
			_add_redactor(cell, Vector2(1, 0) if ch == "R" else Vector2(0, 1), 3.0, "keep climbing")
		"f", "F", "N":
			var key := DungeonKey.new()
			key.kind = "page"
			key.position = Iso.to_screen(Vector2(cell))
			key.elev = _lift_at(cell)
			_actors.add_child(key)
			_register(key, func(): return "Take the torn page", func(): _take_page(key, int(PAGES[ch])), 80.0)
		"Z":
			_spoiler = Spoiler.new()
			_spoiler.position = Iso.to_screen(Vector2(cell))
			_spoiler.lift = _lift_at(cell)
			_actors.add_child(_spoiler)
		"Y":
			_pip = _add_prop(Prop.Kind.FIGURE, cell, false, 2)
			_register(_pip, func(): return "Turn the page with Pip" if (_finale_done and not _leaving) else "", _turn_the_page, 90.0)
		_:
			return false
	return true

func _level_ready() -> void:
	# Arena cells: the Last Page's platform (height 2), excluding the door cell.
	echo_enabled = true
	for plate: EchoPlate in _plate_nodes.values():
		plate.player = _player
	_temps["river"]["cells"] = MemoryPipMap.RIVER_CELLS
	_temps["floor"]["cells"] = MemoryPipMap.FLOOR_CELLS
	for cell: Vector2i in _floor.cells.keys():
		if cell.y <= 5 and cell.x >= 30 and cell.x <= 41 and _floor.cells[cell] == "p" and not _floor.stairs.has(cell):
			_arena_cells.append(cell)
	for sp in _enemy_spawns:
		var e := _add_enemy(sp["kind"], sp["cell"])
		_assign_group(e, sp["cell"])
	_spoiler.target = _player
	_spoiler.speak.connect(_on_spoiler_speak)
	_spoiler.damaged.connect(func(frac: float): _hud.set_boss("The Spoiler", frac))
	_spoiler.rewritten.connect(_on_spoiler_rewritten)
	_spoiler.fired.connect(_on_spoiler_fired)
	_spoiler.slam.connect(_on_spoiler_slam)
	_spoiler.defeated_fight.connect(_on_spoiler_beaten)
	_hud.set_region("The Last Page")
	_hud.set_objective(Story.PIP_OBJECTIVES[0])
	await get_tree().create_timer(2.4).timeout
	await _hud.tutorial("rewrite")
	_hud.narrate(Story.PIP_INTRO, false, 4.0)

# --- Frame loop ---------------------------------------------------------------------------------
func _room_for(cell: Vector2i) -> int:
	if cell.x >= 30 and cell.x <= 41 and cell.y <= 5:
		return R_LAST
	if cell.x <= 13:
		return R_FRONT
	if cell.x >= 45:
		return R_ARCHIVE
	if cell.y >= 20 and cell.x <= 29:
		return R_WOOD
	if cell.y <= 10 and cell.x <= 29:
		return R_TOWER
	return R_HALL

func _group_of(cell: Vector2i) -> String:
	match _room_for(cell):
		R_WOOD: return "wood"
		R_ARCHIVE: return "archive"
	return ""

func _assign_group(e: Enemy, cell: Vector2i) -> void:
	var g := _group_of(cell)
	if g != "":
		_sleepers[g]["enemies"].append(e)

func _level_process(delta: float) -> void:
	var cell := _floor.cell_at(_player.position)
	var room := _room_for(cell)
	if not _room_seen.has(room):
		_room_seen[room] = true
		_on_room(room)
	if room == R_LAST and not _boss_started and _door.is_open and not GameState.in_dialogue:
		_start_boss()
	_tick_sleepers(delta)
	_tick_temps(delta)
	_tick_echo_gates()
	_tick_latches()
	_check_pages()
	_tick_hazards(delta)
	_tick_palette(delta)

func _on_room(room: int) -> void:
	match room:
		R_FRONT:
			_hud.narrate(Story.PIP_STONE_HINT, false, 5.0)
		R_HALL:
			_hud.set_objective(Story.PIP_WING_OBJECTIVES[0] if not _all_pages() else Story.PIP_PAGES_DONE)
		R_WOOD:
			_hud.set_objective(Story.PIP_WING_OBJECTIVES[1])
		R_TOWER:
			_hud.set_objective(Story.PIP_WING_OBJECTIVES[2])
			_hud.narrate(Story.PIP_TOWER_HINT, false, 6.0)
		R_ARCHIVE:
			_hud.set_objective(Story.PIP_WING_OBJECTIVES[3])

func _tick_palette(delta: float) -> void:
	var target := 0.0
	if _boss_started and not _finale_done:
		target = 0.25 + 0.6 * float(_spoiler.certainty if is_instance_valid(_spoiler) else 0) / 5.0
	_darkness = lerpf(_darkness, target, 1.0 - exp(-1.5 * delta))
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("paper_light", Color(0.55, 0.74, 0.86).lerp(Color(0.12, 0.08, 0.20), _darkness))
	mat.set_shader_parameter("paper_dark", Color(0.38, 0.56, 0.74).lerp(Color(0.06, 0.04, 0.12), _darkness))

# --- Front Matter: the bridge -----------------------------------------------------------------
func _on_bridge(_stone: SentenceStone, idx: int) -> void:
	for c in MemoryPipMap.BRIDGE_CELLS:
		_floor.cells[c] = "b" if idx == 1 else "#"
	if idx == 1:
		_hud.narrate(Story.PIP_BRIDGE_HOLDS, false, 4.0)

# --- Sleepers: wolves in the Dark Wood, guards in the Archive -------------------------------------
func _on_sleepers(group: String, idx: int) -> void:
	var g: Dictionary = _sleepers[group]
	if idx == 1:
		g["t"] = WOLF_SLEEP
		for e: Enemy in g["enemies"]:
			if is_instance_valid(e) and not e.friendly:
				e.sleep_for(WOLF_SLEEP)
		_hud.narrate(Story.PIP_WOLVES_ASLEEP if group == "wood" else Story.PIP_GUARDS_ASLEEP, false, 4.0)
	else:
		g["t"] = 0.0
		for e: Enemy in g["enemies"]:
			if is_instance_valid(e):
				e.asleep_t = 0.0

func _tick_sleepers(delta: float) -> void:
	for group in _sleepers:
		var g: Dictionary = _sleepers[group]
		var st: SentenceStone = _stones.get(g["stone"])
		if float(g["t"]) <= 0.0 or not is_instance_valid(st):
			continue
		g["t"] = float(g["t"]) - delta
		st.ttl_max = WOLF_SLEEP
		st.ttl = maxf(float(g["t"]), 0.0)
		if float(g["t"]) <= 0.0:
			st.index = 0
			_hud.narrate(Story.PIP_WOLVES_WAKE, false, 3.0)

func _on_gate(stone: SentenceStone, idx: int) -> void:
	if idx == 1:
		stone.locked = true
		_gate.open()
		_hud.narrate(Story.PIP_GATE_OPEN, false, 4.0)

func _on_open_gate(key: String, stone: SentenceStone, idx: int, msg: String) -> void:
	if idx == 1 and _gate_nodes.has(key):
		stone.locked = true
		_gate_nodes[key].open()
		_hud.narrate(msg, false, 4.0)

# --- Timed bridges: the river freezes, the missing floor is written solid -------------------------
func _on_temp(key: String, idx: int) -> void:
	var tmp: Dictionary = _temps[key]
	if idx == 1:
		tmp["t"] = float(tmp["dur"])
		for c: Vector2i in tmp["cells"]:
			_floor.cells[c] = "b"
		_hud.narrate(Story.PIP_ICE if key == "river" else Story.PIP_SOLID, false, 4.0)
	else:
		_melt(key)

func _melt(key: String) -> void:
	var tmp: Dictionary = _temps[key]
	tmp["t"] = 0.0
	for c: Vector2i in tmp["cells"]:
		_floor.cells[c] = "#"
	var st: SentenceStone = _stones.get(tmp["stone"])
	if is_instance_valid(st):
		st.index = 0

func _tick_temps(delta: float) -> void:
	for key in _temps:
		var tmp: Dictionary = _temps[key]
		if float(tmp["t"]) <= 0.0:
			continue
		var st: SentenceStone = _stones.get(tmp["stone"])
		tmp["t"] = float(tmp["t"]) - delta
		if is_instance_valid(st):
			st.ttl_max = float(tmp["dur"])
			st.ttl = maxf(float(tmp["t"]), 0.0)
		if float(tmp["t"]) <= 0.0:
			# It does not melt under your feet.
			var here := _floor.cell_at(_player.position)
			if tmp["cells"].has(here) and not _player.is_falling:
				tmp["t"] = 0.05
				continue
			_melt(key)
			_hud.narrate(Story.PIP_WEARS_OFF, false, 3.0)

# --- Echo gates, and the lock sentence in the Archive -----------------------------------------------
func _on_lock_sentence(stone: SentenceStone, idx: int) -> void:
	_lock_read = idx == 1
	if idx == 1:
		stone.locked = true
		_hud.narrate(Story.PIP_LOCK_OPEN, false, 4.0)

func _tick_echo_gates() -> void:
	for pair in ECHO_GATES:
		var gk: String = pair[0]
		if not _gate_nodes.has(gk):
			continue
		var gate: StoryGate = _gate_nodes[gk]
		var want := true
		for pk: String in pair[1]:
			if not _plate_nodes.has(pk) or not (_plate_nodes[pk] as EchoPlate).pressed:
				want = false
		if gk == "y" and not _lock_read:
			want = false
		if want and not gate.is_open:
			gate.open()
			Telemetry.log_event("puzzle", {"p": "pip_gate_" + gk})
			if gk == "u" and not _y_seen:
				_y_seen = true
				_hud.narrate(Story.PIP_ECHO_HOLDS, false, 4.0)
		elif not want and gate.is_open and _dist(_player.position, gate.position) > 90.0:
			gate.close()

## The Archive's first gate stays open once its plate has been pressed.
func _tick_latches() -> void:
	if not _w_seen and _plate_nodes.has("l") and (_plate_nodes["l"] as EchoPlate).pressed:
		_w_seen = true
		_gate_nodes["w"].open()
		_hud.narrate(Story.PIP_GATE_OPEN, false, 4.0)

# --- Torn Pages and the door to the Last Page -----------------------------------------------------
func _all_pages() -> bool:
	return _pages.size() >= PAGES.size()

func _take_page(key: DungeonKey, n: int) -> void:
	_pages[n] = true
	Telemetry.log_event("puzzle", {"p": "pip_page_%d" % n})
	create_tween().tween_property(key, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(key.queue_free)
	_hud.toast("Found: a Torn Page (%d/3)" % _pages.size())
	if is_instance_valid(_door):
		_door.label = "THE END  %d/3" % _pages.size()
		_door.queue_redraw()
	if _all_pages():
		_hud.set_objective(Story.PIP_PAGES_DONE)
		_hud.narrate(Story.PIP_ALL_PAGES, false, 5.0)
	else:
		_hud.narrate(Story.PIP_PAGE_NARRATION[_pages.size() - 1], false, 4.0)

func _door_prompt() -> String:
	if _door.is_open:
		return ""
	return "Fit the Torn Pages" if _all_pages() else "Locked (%d/3 pages)" % _pages.size()

func _use_door() -> void:
	if _all_pages():
		await _say(Story.pip_door_fit())
		_door.open()
	else:
		await _say([Story.line("", Story.PIP_DOOR_LOCKED, "action")])

# --- Room 4: The Spoiler ----------------------------------------------------------------------------
func _start_boss() -> void:
	_boss_started = true
	_busy = true
	Music.play("boss_spoiler")
	await cinematic([{"at": _spoiler.position, "zoom": ZOOM * 1.2, "pan": 1.6, "hold": 0.5, "lines": Story.pip_boss_intro()}])
	await _hud.tutorial("spoiler")
	_spoiler.interval = 8.0 if GameState.is_story() else 6.5
	_spoiler.active = true
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "start"})
	_hud.set_objective(Story.PIP_OBJECTIVES[3] % 0)
	_busy = false

## How long you have to rewrite a spoiler: shrinks as the Spoiler warms up.
func _window() -> float:
	return maxf(5.6 - 0.4 * _rewrites, 3.8) + GameState.spoiler_window_bonus()

func _free_arena_cell(avoid: Vector2i, min_dist: float) -> Vector2i:
	var pool := _arena_cells.duplicate()
	pool.shuffle()
	for c in pool:
		if Vector2(c - avoid).length() < min_dist:
			continue
		var clash := false
		for hz in _hazards:
			if is_instance_valid(hz["stone"]) and Vector2(_floor.cell_at(hz["stone"].position) - c).length() < 2.0:
				clash = true
		if not clash and Vector2(_floor.cell_at(_player.position) - c).length() > 1.5:
			return c
	return pool[0]

func _on_spoiler_speak() -> void:
	var n := 2 if _rewrites >= 3 else 1
	for i in n:
		_spawn_spoiler_event()

func _spawn_spoiler_event() -> void:
	var roll := randf()
	var kind := "collapse" if roll < 0.4 else ("wolves" if roll < 0.7 else "lightning")
	var cells: Array[Vector2i] = []
	var prefix := ""
	var options := []
	var region_name := ""
	var center := Vector2i.ZERO
	if kind == "wolves":
		region_name = WOLF_SIDES.keys()[randi() % WOLF_SIDES.size()]
		cells.assign(WOLF_SIDES[region_name])
		center = cells[0]
		prefix = "Wolves from the %s" % region_name
		options = ["ATTACK", "NAP"]
	else:
		region_name = REGIONS.keys()[randi() % REGIONS.size()]
		center = REGIONS[region_name]
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := center + Vector2i(dx, dy)
				if _arena_cells.has(c):
					cells.append(c)
		if kind == "collapse":
			prefix = "The floor beneath the %s" % region_name
			options = ["COLLAPSES", "BLOOMS"]
		else:
			prefix = "Lightning in the %s" % region_name
			options = ["STRIKES", "SPARKLES"]
	var window := _window()
	var hz := {"kind": kind, "cells": cells, "stone": null, "t": window, "phase": "warn", "orig": {}}
	_hazards.append(hz)
	for c in cells:
		_floor.marks[c] = {"kind": "crack", "t": 0.0}
	_spoiler.announce("%s %s." % [prefix, options[0]], window)
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "spoke", "kind": kind, "window": snappedf(window, 0.1)})

## The Quill struck the book while it was reading: the oldest sentence it is still reading is rewritten.
func _on_spoiler_rewritten() -> void:
	for hz in _hazards:
		if hz["phase"] == "warn":
			_rewrite_hazard(hz)
			return

func _rewrite_hazard(hz: Dictionary) -> void:
	if _reckoning:
		_cancel_hazard(hz)
		_hud.toast("Struck out")
		return
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "rewritten", "n": _rewrites + 1})
	hz["phase"] = "rewritten"
	hz["t"] = 8.0
	for c in hz["cells"]:
		_floor.marks[c] = {"kind": "flower", "t": 0.0}
	if hz["kind"] == "wolves":
		drop_crystals(Iso.to_screen(Vector2(hz["cells"][0])), 2)
	_rewrites += 1
	_spoiler.rewrites = _rewrites
	_spoiler.certainty = maxi(5 - _rewrites, 0)
	camera_shake(0.4, 5.0)
	_hud.set_objective(Story.PIP_OBJECTIVES[3] % _rewrites)
	_hud.narrate(Story.PIP_REWRITE_NARRATION[mini(_rewrites, 5) - 1], false, 3.5)
	if _rewrites >= 5:
		_begin_reckoning()

# --- The Spoiler's paper ---------------------------------------------------------------------------------
func _on_spoiler_fired(origin: Vector2, dirs: Array, speed: float) -> void:
	for d: Vector2 in dirs:
		var pc := PageCut.new()
		pc.floor_ref = _floor
		pc.position = origin
		pc.vel = d * speed
		_actors.add_child(pc)

func _on_spoiler_slam(at: Vector2) -> void:
	camera_shake(0.35, 6.0)
	if _player.is_falling or _player.is_crumpled:
		return
	if _dist(at, _player.position) < 76.0 and absf(_floor.height_at(at) - _floor.height_at(_player.position)) < 0.7:
		_player.take_damage(14.0 * GameState.enemy_dmg_mult(), true, "spoiler_dive")
		_player.knockback((_player.position - at).normalized(), 320.0)

func _check_pages() -> void:
	if _player.is_falling or _player.is_crumpled:
		return
	for pc: PageCut in get_tree().get_nodes_in_group("page_cuts"):
		if _dist(pc.position, _player.position) > 20.0:
			continue
		if absf(_floor.height_at(pc.position) - _floor.height_at(_player.position)) > 0.7:
			continue
		_player.take_damage(8.0 * GameState.enemy_dmg_mult(), true, "spoiler_page")
		pc.queue_free()

func _clear_pages() -> void:
	for pc in get_tree().get_nodes_in_group("page_cuts"):
		pc.queue_free()

var _reckoning := false

## Rewritten (or struck out): the sentence becomes flowers instead of coming true.
func _cancel_hazard(hz: Dictionary) -> void:
	hz["phase"] = "rewritten"
	hz["t"] = 8.0
	if is_instance_valid(hz["stone"]):
		hz["stone"].locked = true
		hz["stone"].ttl = -1.0
	for c in hz["cells"]:
		_floor.marks[c] = {"kind": "flower", "t": 0.0}
	camera_shake(0.3, 4.0)

## Five sentences rewritten: the Spoiler comes down to eye level and can be hurt.
func _begin_reckoning() -> void:
	_busy = true
	_spoiler.active = false
	_clear_pages()
	await get_tree().create_timer(1.2).timeout
	for hz in _hazards:
		for c in hz["cells"]:
			_floor.cells[c] = hz["orig"].get(c, "p")
			_floor.marks.erase(c)
		if is_instance_valid(hz["stone"]):
			hz["stone"].queue_free()
	_hazards.clear()
	await cinematic([{"at": _spoiler.position, "zoom": ZOOM * 1.3, "pan": 1.0, "hold": 0.6, "lines": Story.spoiler_reckoning()}])
	_reckoning = true
	_hud.set_objective(Story.SPOILER_FIGHT_OBJECTIVE)
	_spoiler.interval = 6.0 if GameState.is_story() else 5.0
	_spoiler.begin_reckoning()
	Music.play("boss_spoiler_reckoning", "boss_spoiler")
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "reckoning"})
	_busy = false

func _on_spoiler_beaten() -> void:
	_clear_pages()
	_hud.set_boss("", 0.0)
	Music.play("victory", "memory_pip", 0.8)
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "defeated"})
	camera_shake(0.7, 9.0)
	_finale()

func _tick_hazards(delta: float) -> void:
	for hz in _hazards.duplicate():
		hz["t"] = float(hz["t"]) - delta
		var cells: Array = hz["cells"]
		var st: SentenceStone = hz["stone"]
		match hz["phase"]:
			"warn":
				if is_instance_valid(st):
					st.ttl = maxf(hz["t"], 0.0)
				if hz["t"] <= 0.0:
					_trigger(hz)
			"active":
				if hz["t"] <= 0.0:
					for c in cells:
						_floor.cells[c] = hz["orig"].get(c, "p")
					hz["phase"] = "done"
					hz["t"] = 0.3
			"rewritten":
				# Flowers heal whoever stands in them.
				if cells.has(_floor.cell_at(_player.position)):
					_player.ink = minf(_player.ink + 12.0 * delta, _player.max_ink)
					_player.ink_changed.emit(_player.ink, _player.max_ink)
				if hz["t"] <= 0.0:
					for c in cells:
						_floor.marks.erase(c)
					if is_instance_valid(st):
						st.queue_free()
					_hazards.erase(hz)
			"done":
				if hz["t"] <= 0.0:
					for c in cells:
						_floor.marks.erase(c)
					if is_instance_valid(st):
						st.queue_free()
					_hazards.erase(hz)

func _trigger(hz: Dictionary) -> void:
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "came_true", "kind": hz["kind"]})
	var st: SentenceStone = hz["stone"]
	if is_instance_valid(st):
		st.locked = true
	for c in hz["cells"]:
		_floor.marks.erase(c)
	if hz["kind"] == "collapse":
		for c in hz["cells"]:
			hz["orig"][c] = _floor.cells[c]
			_floor.cells[c] = "#"
		hz["phase"] = "active"
		hz["t"] = 7.0
		camera_shake(0.3, 4.0)
	elif hz["kind"] == "lightning":
		for c in hz["cells"]:
			_floor.marks[c] = {"kind": "wipe", "t": 0.0}
		if hz["cells"].has(_floor.cell_at(_player.position)) and not _player.is_falling:
			_player.take_damage(16.0 * GameState.enemy_dmg_mult(), true, "spoiler_lightning")
		camera_shake(0.45, 7.0)
		hz["phase"] = "done"
		hz["t"] = 0.45
	else:
		for c in hz["cells"]:
			_add_enemy(Enemy.Kind.MITE, c)
		hz["phase"] = "done"
		hz["t"] = 1.5

func _finale() -> void:
	if _finale_done:
		return
	_finale_done = true
	_busy = true
	_spoiler.active = false
	await get_tree().create_timer(1.6).timeout
	# Undo any remaining hazards so the room is calm for the ending.
	for hz in _hazards:
		for c in hz["cells"]:
			_floor.cells[c] = hz["orig"].get(c, "p")
			_floor.marks.erase(c)
		if is_instance_valid(hz["stone"]):
			hz["stone"].queue_free()
	_hazards.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	await cinematic([{"at": _spoiler.position, "zoom": ZOOM * 1.3, "pan": 1.0, "hold": 1.2, "lines": Story.pip_finale()}])
	await get_tree().create_timer(2.0).timeout
	_hud.set_objective(Story.PIP_OBJECTIVES[4])
	_busy = false

func _handle_cue(cue: String) -> void:
	if cue == "dissolve_spoiler":
		_spoiler.defeat()

func _turn_the_page() -> void:
	await cinematic([{"at": _pip.position, "zoom": ZOOM * 1.45, "pan": 1.3, "hold": 1.2, "lines": Story.pip_resolution()}])
	GameState.set_flag("pip_memory_done")
	award_boss_drops("pip")
	GameState.add_mnemosynth(40)
	_give_item("bookmark")
	_hud.set_objective("")
	await get_tree().create_timer(3.0).timeout
	_leave()

# --- Rooms, checkpoints and dying -------------------------------------------------------------------
func _room_name(cell: Vector2i) -> String:
	return ["Front Matter", "The Reading Hall", "The Dark Wood", "The Tall Tower", "The Margin Archive", "The Last Page"][_room_for(cell)]

func _checkpoint_for(cell: Vector2i) -> Vector2:
	match _room_for(cell):
		R_FRONT: return _map_start
		R_HALL: return Iso.to_screen(Vector2(16, 14))
		R_WOOD: return Iso.to_screen(Vector2(21, 21))
		R_TOWER: return Iso.to_screen(Vector2(19, 10))
		R_ARCHIVE: return Iso.to_screen(Vector2(46, 15))
		_: return Iso.to_screen(Vector2(35, 7))

func _on_death_reset() -> void:
	var room := _room_for(_floor.cell_at(_player.position))
	_clear_echoes()
	# The room's Errors return, but your rewrites stay.
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _room_for(_floor.cell_at(e.position)) == room:
			e.queue_free()
	for g in _sleepers.values():
		g["enemies"] = g["enemies"].filter(func(e): return is_instance_valid(e) and _room_for(_floor.cell_at(e.position)) != room)
	for sp in _enemy_spawns:
		if _room_for(sp["cell"]) == room and _dist(Iso.to_screen(Vector2(sp["cell"])), _player.position) > 380.0:
			var e := _add_enemy(sp["kind"], sp["cell"])
			_assign_group(e, sp["cell"])
	if room == R_WOOD or room == R_ARCHIVE:
		var gname := "wood" if room == R_WOOD else "archive"
		_sleepers[gname]["t"] = 0.0
		var st: SentenceStone = _stones.get(_sleepers[gname]["stone"])
		if is_instance_valid(st):
			st.index = 0
	if _boss_started and not _finale_done:
		# The Spoiler's hazards reset, and it recovers one sentence.
		for hz in _hazards:
			for c in hz["cells"]:
				_floor.cells[c] = hz["orig"].get(c, "p")
				_floor.marks.erase(c)
			if is_instance_valid(hz["stone"]):
				hz["stone"].queue_free()
		_hazards.clear()
		_clear_pages()
		if _reckoning:
			_spoiler.reset_fight()
			return
		_rewrites = maxi(_rewrites - 1, 0)
		_spoiler.rewrites = _rewrites
		_spoiler.certainty = 5 - _rewrites
		_spoiler.reset_moves()
		_hud.set_objective(Story.PIP_OBJECTIVES[3] % _rewrites)
		Telemetry.log_event("boss", {"boss": "spoiler", "what": "player_died", "rewrites": _rewrites})

# --- Leaving --------------------------------------------------------------------------------------------
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.spawn_cell = RETURN_CELL
	Transition.go(OVERWORLD, Palette.CYAN.lightened(0.7))
	await get_tree().create_timer(30.0).timeout
