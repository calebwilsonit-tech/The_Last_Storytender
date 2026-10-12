extends LevelBase
## Pip's memory: "The Last Page". A pop-up storybook where Pip peeked at the
## ending and decided every story ends badly. Four rooms:
##  1. Front Matter   - learn to REWRITE a sentence with the Quill (the bridge).
##  2. The Dark Wood  - wolves you can rewrite to sleep, and a gate to rewrite open.
##  3. The Tall Tower - Redactor bars (Lantern) and the Torn Page.
##  4. The Last Page  - The Spoiler: it announces the future; rewrite it before it happens.

const OVERWORLD := "res://scenes/main.tscn"
const RETURN_CELL := Vector2i(26, 13)
const BRIDGE_CELLS: Array[Vector2i] = [Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17)]
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
var _room2_enemies: Array[Enemy] = []
var _stone_bridge: SentenceStone
var _stone_wolves: SentenceStone
var _stone_gate: SentenceStone
var _gate: StoryGate
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
	if ch in "pPETCabcGHgxRfZY":
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
			_stone_wolves = _make_stone(cell, "The wolves are", ["HUNGRY", "ASLEEP"])
			_stone_wolves.rewritten.connect(_on_wolves)
		"c":
			_stone_gate = _make_stone(cell, "The gate is", ["LOCKED", "OPEN"])
			_stone_gate.rewritten.connect(_on_gate)
		"G":
			_gate = StoryGate.new()
			_gate.axis = Vector2(0, 1)
			_gate.length = 3.0
			_gate.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(_gate)
		"H":
			_door = StoryGate.new()
			_door.axis = Vector2(1, 0)
			_door.length = 3.0
			_door.label = "THE END"
			_door.position = Iso.to_screen(Vector2(cell))
			_door.elev = _lift_at(cell)
			_actors.add_child(_door)
			_register(_door, _door_prompt, _use_door, 130.0)
		"g", "x":
			_enemy_spawns.append({"kind": Enemy.Kind.BARE if ch == "g" else Enemy.Kind.MITE, "cell": cell})
		"R":
			_add_redactor(cell, Vector2(1, 0), 3.0, "keep climbing")
		"f":
			_add_pickup(cell, "torn_page")
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
	for cell: Vector2i in _floor.cells.keys():
		if cell.y <= 5 and cell.x >= 30 and _floor.cells[cell] == "p" and not _floor.stairs.has(cell):
			_arena_cells.append(cell)
	for sp in _enemy_spawns:
		var e := _add_enemy(sp["kind"], sp["cell"])
		if sp["cell"].x >= 14 and sp["cell"].x <= 27:
			_room2_enemies.append(e)
	_spoiler.target = _player
	_spoiler.speak.connect(_on_spoiler_speak)
	_hud.set_region("The Last Page")
	_hud.set_objective(Story.PIP_OBJECTIVES[0])
	await get_tree().create_timer(2.4).timeout
	await _hud.tutorial("rewrite")
	_hud.narrate(Story.PIP_INTRO, false, 4.0)

# --- Frame loop ---------------------------------------------------------------------------------
func _room_for(cell: Vector2i) -> int:
	if cell.x <= 13:
		return 0
	if cell.x <= 30:
		return 1
	if cell.y >= 6:
		return 2
	return 3

func _level_process(delta: float) -> void:
	var cell := _floor.cell_at(_player.position)
	var room := _room_for(cell)
	if not _room_seen.has(room):
		_room_seen[room] = true
		_on_room(room)
	if room == 3 and not _boss_started and _door.is_open and not GameState.in_dialogue:
		_start_boss()
	_tick_wolves(delta)
	_tick_hazards(delta)
	_tick_palette(delta)

func _on_room(room: int) -> void:
	match room:
		0:
			_hud.narrate(Story.PIP_STONE_HINT, false, 5.0)
		1:
			_hud.set_objective(Story.PIP_OBJECTIVES[1])
		2:
			_hud.set_objective(Story.PIP_OBJECTIVES[2])
			_hud.narrate(Story.PIP_TOWER_HINT, false, 6.0)

func _tick_palette(delta: float) -> void:
	var target := 0.0
	if _boss_started and not _finale_done:
		target = 0.25 + 0.6 * float(_spoiler.certainty if is_instance_valid(_spoiler) else 0) / 5.0
	_darkness = lerpf(_darkness, target, 1.0 - exp(-1.5 * delta))
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("paper_light", Color(0.55, 0.74, 0.86).lerp(Color(0.12, 0.08, 0.20), _darkness))
	mat.set_shader_parameter("paper_dark", Color(0.38, 0.56, 0.74).lerp(Color(0.06, 0.04, 0.12), _darkness))

# --- Room 1: the bridge ------------------------------------------------------------------------
func _on_bridge(_stone: SentenceStone, idx: int) -> void:
	for c in BRIDGE_CELLS:
		_floor.cells[c] = "b" if idx == 1 else "#"
	if idx == 1:
		_hud.narrate(Story.PIP_BRIDGE_HOLDS, false, 4.0)

# --- Room 2: wolves and the gate ----------------------------------------------------------------
func _on_wolves(_stone: SentenceStone, idx: int) -> void:
	if idx == 1:
		_wolves_t = WOLF_SLEEP
		for e in _room2_enemies:
			if is_instance_valid(e) and not e.friendly:
				e.sleep_for(WOLF_SLEEP)
		_hud.narrate(Story.PIP_WOLVES_ASLEEP, false, 4.0)
	else:
		_wolves_t = 0.0
		for e in _room2_enemies:
			if is_instance_valid(e):
				e.asleep_t = 0.0

func _tick_wolves(delta: float) -> void:
	if _wolves_t <= 0.0 or not is_instance_valid(_stone_wolves):
		return
	_wolves_t -= delta
	_stone_wolves.ttl_max = WOLF_SLEEP
	_stone_wolves.ttl = maxf(_wolves_t, 0.0)
	if _wolves_t <= 0.0:
		_stone_wolves.index = 0
		_hud.narrate(Story.PIP_WOLVES_WAKE, false, 3.0)

func _on_gate(stone: SentenceStone, idx: int) -> void:
	if idx == 1:
		stone.locked = true
		_gate.open()
		_hud.narrate(Story.PIP_GATE_OPEN, false, 4.0)

# --- Room 3: the door ---------------------------------------------------------------------------
func _door_prompt() -> String:
	if _door.is_open:
		return ""
	return "Fit the Torn Page" if GameState.count("torn_page") > 0 else "Locked"

func _use_door() -> void:
	if GameState.count("torn_page") > 0:
		GameState.remove_item("torn_page")
		await _say(Story.pip_door_fit())
		_door.open()
	else:
		await _say([Story.line("", Story.PIP_DOOR_LOCKED, "action")])

# --- Room 4: The Spoiler ----------------------------------------------------------------------------
func _start_boss() -> void:
	_boss_started = true
	_busy = true
	await _say(Story.pip_boss_intro())
	_spoiler.interval = 8.0 if GameState.is_story() else 6.5
	_spoiler.active = true
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "start"})
	_hud.set_objective(Story.PIP_OBJECTIVES[3] % 0)
	_busy = false

## How long you have to rewrite a spoiler: shrinks as the Spoiler warms up.
func _window() -> float:
	return maxf(5.0 - 0.45 * _rewrites, 3.2) + GameState.spoiler_window_bonus()

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
	var kind := "collapse" if randf() < 0.6 else "wolves"
	var cells: Array[Vector2i] = []
	var prefix := ""
	var options := []
	var region_name := ""
	var center := Vector2i.ZERO
	if kind == "collapse":
		region_name = REGIONS.keys()[randi() % REGIONS.size()]
		center = REGIONS[region_name]
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := center + Vector2i(dx, dy)
				if _arena_cells.has(c):
					cells.append(c)
		prefix = "The floor beneath the %s" % region_name
		options = ["COLLAPSES", "BLOOMS"]
	else:
		region_name = WOLF_SIDES.keys()[randi() % WOLF_SIDES.size()]
		cells.assign(WOLF_SIDES[region_name])
		center = cells[0]
		prefix = "Wolves from the %s" % region_name
		options = ["ATTACK", "NAP"]
	var window := _window()
	var at := _free_arena_cell(center, 4.0)
	var st := SentenceStone.new()
	st.prefix = prefix
	st.options = PackedStringArray(options)
	st.suffix = "."
	st.position = Iso.to_screen(Vector2(at))
	st.elev = _lift_at(at)
	st.ttl_max = window
	st.ttl = window
	_actors.add_child(st)
	_register(st, func(): return "Rewrite" if not st.locked else "", func(): st.rewrite(), 80.0)
	var hz := {"kind": kind, "cells": cells, "stone": st, "t": window, "phase": "warn", "orig": {}}
	_hazards.append(hz)
	for c in cells:
		_floor.marks[c] = {"kind": "crack", "t": 0.0}
	_spoiler.announce("%s %s." % [prefix, options[0]], window - 0.5)
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "spoke", "kind": kind, "window": snappedf(window, 0.1)})
	st.rewritten.connect(func(s: SentenceStone, idx: int): _on_spoiler_stone(hz, s, idx))

func _on_spoiler_stone(hz: Dictionary, stone: SentenceStone, idx: int) -> void:
	if hz["phase"] != "warn" or idx != 1:
		return
	Telemetry.log_event("boss", {"boss": "spoiler", "what": "rewritten", "n": _rewrites + 1})
	hz["phase"] = "rewritten"
	hz["t"] = 8.0
	stone.locked = true
	stone.ttl = -1.0
	for c in hz["cells"]:
		_floor.marks[c] = {"kind": "flower", "t": 0.0}
	if hz["kind"] == "wolves":
		drop_crystals(Iso.to_screen(Vector2(hz["cells"][0])), 2)
	_rewrites += 1
	_spoiler.certainty = maxi(5 - _rewrites, 0)
	_spoiler.recoil()
	camera_shake(0.4, 5.0)
	_hud.set_objective(Story.PIP_OBJECTIVES[3] % _rewrites)
	_hud.narrate(Story.PIP_REWRITE_NARRATION[mini(_rewrites, 5) - 1], false, 3.5)
	if _rewrites >= 5:
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
	await _say(Story.pip_finale())
	await get_tree().create_timer(2.0).timeout
	_hud.set_objective(Story.PIP_OBJECTIVES[4])
	_busy = false

func _handle_cue(cue: String) -> void:
	if cue == "dissolve_spoiler":
		_spoiler.defeat()

func _turn_the_page() -> void:
	await _say(Story.pip_resolution())
	GameState.set_flag("pip_memory_done")
	GameState.add_mnemosynth(40)
	_give_item("bookmark")
	_hud.set_objective("")
	await get_tree().create_timer(3.0).timeout
	_leave()

# --- Rooms, checkpoints and dying -------------------------------------------------------------------
func _room_name(cell: Vector2i) -> String:
	return ["Front Matter", "The Dark Wood", "The Tall Tower", "The Last Page"][_room_for(cell)]

func _checkpoint_for(cell: Vector2i) -> Vector2:
	match _room_for(cell):
		0: return _map_start
		1: return Iso.to_screen(Vector2(14, 16))
		2: return Iso.to_screen(Vector2(31, 15))
		_: return Iso.to_screen(Vector2(35, 7))

func _on_death_reset() -> void:
	var room := _room_for(_floor.cell_at(_player.position))
	# The room's Errors return, but your rewrites stay.
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _room_for(_floor.cell_at(e.position)) == room:
			e.queue_free()
	_room2_enemies.clear()
	for sp in _enemy_spawns:
		if _room_for(sp["cell"]) == room and _dist(Iso.to_screen(Vector2(sp["cell"])), _player.position) > 380.0:
			var e := _add_enemy(sp["kind"], sp["cell"])
			if room == 1:
				_room2_enemies.append(e)
	if room == 1:
		_wolves_t = 0.0
		if is_instance_valid(_stone_wolves):
			_stone_wolves.index = 0
	if _boss_started and not _finale_done:
		# The Spoiler's hazards reset, and it recovers one sentence.
		for hz in _hazards:
			for c in hz["cells"]:
				_floor.cells[c] = hz["orig"].get(c, "p")
				_floor.marks.erase(c)
			if is_instance_valid(hz["stone"]):
				hz["stone"].queue_free()
		_hazards.clear()
		_rewrites = maxi(_rewrites - 1, 0)
		_spoiler.certainty = 5 - _rewrites
		_spoiler._cd = 3.0
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
