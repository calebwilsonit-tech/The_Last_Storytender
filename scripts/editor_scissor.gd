extends LevelBase
## The Cutting Room: the Scissor-Man, Thistledown's Editor. His verb is the CLIPBOARD
## (cut, copy, paste). He cuts the arena apart along telegraphed lines. Each cut
## leaves clippings you can pick up (strike them) and paste back (V). A patched cell
## cannot be cut; if his line crosses a patch, his shears JAM and he can be hurt.

const OVERWORLD := "res://scenes/main.tscn"
const RETURN_CELL := Vector2i(24, 14) + PrologueMap.OFFSET
const SHAPES := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
]
const MAX_CLIPPINGS := 4

var _scissor: ScissorMan
var _arena: Array[Vector2i] = []
var _bounds_min := Vector2i.ZERO
var _bounds_max := Vector2i.ZERO
var _held: Array[Vector2i] = []
var _ghost: PasteGhost
var _clippings: Array[Clipping] = []
var _lines: Array[Dictionary] = []          # telegraphed cut lines {cells, t}
var _cuts: Dictionary = {}                  # cell -> seconds until the paper heals
var _patches: Dictionary = {}               # cell -> seconds the patch lasts
var _snip_cd := 7.0
var _phase := 1
var _started := false
var _finale_done := false
var _leaving := false
var _first_paste := false
var _snip_t := -1.0                         # >= 0 while the blades are sweeping
var _sweep: Dictionary = {}
var _minions_spawned := {}

# --- LevelBase hooks ---------------------------------------------------------------------------------
func _map_rows() -> Array[String]:
	return EditorScissorMap.ROWS

func _map_heights() -> Array[String]:
	return EditorScissorMap.HEIGHTS

func _paper_params() -> Dictionary:
	# A workroom after dark: deep teal wall behind a lit mat.
	return {"paper_light": Color(0.13, 0.27, 0.27), "paper_dark": Color(0.06, 0.14, 0.16),
		"script_color": Color(0.7, 0.9, 0.85), "script_strength": 0.07, "vignette": 0.75}

func _spawn_char(ch: String, cell: Vector2i, _consumed: Dictionary) -> bool:
	if ch in "cPEZkC":
		_floor.cells[cell] = "c"
	match ch:
		"P":
			_start = Iso.to_screen(Vector2(cell))
			_map_start = _start
		"E":
			var portal := _add_prop(Prop.Kind.PORTAL, cell)
			_register(portal, func(): return "" if _leaving else "Leave the Cutting Room", _leave, 70.0)
		"Z":
			_scissor = ScissorMan.new()
			_scissor.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(_scissor)
		"k":
			_spawn_clipping(cell, SHAPES[randi() % SHAPES.size()])
		"C":
			_crystals.append(_add_prop(Prop.Kind.CRYSTAL, cell))
		_:
			return false
	return true

func _level_ready() -> void:
	for cell: Vector2i in _floor.cells.keys():
		if _floor.cells[cell] == "c":
			_arena.append(cell)
	_bounds_min = Vector2i(999, 999)
	_bounds_max = Vector2i(-999, -999)
	for c in _arena:
		_bounds_min = Vector2i(mini(_bounds_min.x, c.x), mini(_bounds_min.y, c.y))
		_bounds_max = Vector2i(maxi(_bounds_max.x, c.x), maxi(_bounds_max.y, c.y))
	_ghost = PasteGhost.new()
	_ghost.visible = false
	_actors.add_child(_ghost)
	_scissor.damaged.connect(_on_boss_damaged)
	_scissor.defeated.connect(_on_defeated)
	_scissor.unjammed.connect(func(): _snip_cd = 3.0; _hud.set_objective(Story.SCISSOR_OBJECTIVES[0]))
	_hud.set_region("The Cutting Room")
	_hud.set_objective("")

func _room_name(_cell: Vector2i) -> String:
	return "The Cutting Room"

func _checkpoint_for(_cell: Vector2i) -> Vector2:
	return _map_start

# --- Frame loop -----------------------------------------------------------------------------------------------
func _level_process(delta: float) -> void:
	if not _started and not GameState.in_dialogue and _floor.cell_at(_player.position).y <= 13:
		_start_fight()
	_update_ghost()
	_tick_cuts(delta)
	_tick_patches(delta)
	if _started and not _finale_done:
		_tick_fight(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("paste") and not get_tree().paused and not GameState.in_dialogue:
		_paste()

# --- Clippings and the clipboard -------------------------------------------------------------------------------
func _spawn_clipping(cell: Vector2i, shape: Array) -> void:
	var c := Clipping.new()
	c.shape.assign(shape)
	c.floor_ref = _floor
	c.position = Iso.to_screen(Vector2(cell))
	_actors.add_child(c)
	_clippings.append(c)
	c.picked.connect(_on_picked)
	_register(c, func(): return "Pick up clipping", func(): _on_picked(c), 70.0)

func _on_picked(c: Clipping) -> void:
	if not is_instance_valid(c) or not _clippings.has(c):
		return
	if not _held.is_empty():
		_hud.toast("Your clipboard is full. Paste it first ({paste}).")
		return
	_held.assign(c.shape)
	_clippings.erase(c)
	c.queue_free()
	_hud.set_clipboard(_held)
	Telemetry.log_event("puzzle", {"p": "clip_picked"})
	if not _first_paste:
		_hud.narrate(Story.SCISSOR_FIRST_PASTE, false, 5.0)

func _paste_anchor() -> Vector2i:
	var g := Vector2(_player.aim_ground.x, _player.aim_ground.y * 0.5) * 96.0
	return _floor.cell_at(_player.position + g)

func _paste_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := _paste_anchor()
	for o in _held:
		out.append(a + o)
	return out

func _update_ghost() -> void:
	if _held.is_empty():
		_ghost.visible = false
		return
	var cells := _paste_cells()
	_ghost.cells = cells
	_ghost.visible = true
	var ok := true
	for c in cells:
		if not _floor.cells.has(c):
			ok = false
	_ghost.valid = ok

func _paste() -> void:
	if _held.is_empty():
		return
	var cells := _paste_cells()
	for c in cells:
		if not _floor.cells.has(c):
			_hud.toast("There's nowhere to paste that.")
			return
	var life := 26.0 if GameState.is_story() else 18.0
	for c in cells:
		if _floor.cells[c] == "#":
			_floor.cells[c] = "c"
			_cuts.erase(c)
		_patches[c] = life
		_floor.marks[c] = {"kind": "patch", "t": 0.0, "ttl": life}
	_held.clear()
	_hud.set_clipboard(_held)
	_first_paste = true
	Telemetry.log_event("puzzle", {"p": "pasted", "n": cells.size()})

func _tick_patches(delta: float) -> void:
	for c in _patches.keys():
		_patches[c] = float(_patches[c]) - delta
		if _floor.marks.has(c) and _floor.marks[c]["kind"] == "patch":
			_floor.marks[c]["ttl"] = _patches[c]
		if _patches[c] <= 0.0:
			_patches.erase(c)
			if _floor.marks.has(c) and _floor.marks[c]["kind"] == "patch":
				_floor.marks.erase(c)

func _tick_cuts(delta: float) -> void:
	for c in _cuts.keys():
		_cuts[c] = float(_cuts[c]) - delta
		if _cuts[c] <= 0.0:
			_floor.cells[c] = "c"
			_cuts.erase(c)

# --- The fight -----------------------------------------------------------------------------------------------------
func _start_fight() -> void:
	_started = true
	_busy = true
	await _say(Story.scissor_boss_intro())
	await _hud.tutorial("paste")
	_hud.set_boss("The Scissor-Man", 1.0)
	_hud.set_objective(Story.SCISSOR_OBJECTIVES[0])
	_snip_cd = 5.0
	_busy = false
	Telemetry.log_event("boss", {"boss": "scissor_man", "what": "start"})

func _telegraph_time() -> float:
	return 3.8 if GameState.is_story() else 3.0

func _tick_fight(delta: float) -> void:
	if _scissor.vulnerable or _scissor.dead:
		return
	if _snip_t >= 0.0:
		_tick_sweep(delta)
		return
	if _lines.is_empty():
		_snip_cd -= delta
		if _snip_cd <= 0.0:
			_start_snip()
		return
	for ln in _lines:
		ln["t"] = float(ln["t"]) - delta
	if float(_lines[0]["t"]) <= 0.0:
		_begin_sweep()

func _make_line(horizontal: bool, idx: int, width: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	for c in _arena:
		var key := c.y if horizontal else c.x
		if key >= idx and key < idx + width:
			cells.append(c)
	return {"cells": cells, "t": _telegraph_time(), "horizontal": horizontal, "idx": idx, "width": width}

func _start_snip() -> void:
	var pc := _floor.cell_at(_player.position)
	var width := 2 if _phase == 2 else 1
	var count := 2 if _phase == 3 else 1
	_lines.clear()
	var horizontal := randi() % 2 == 0
	for i in count:
		var idx := 0
		if horizontal:
			idx = clampi(pc.y + randi_range(-3, 3), _bounds_min.y + 1, _bounds_max.y - width)
		else:
			idx = clampi(pc.x + randi_range(-3, 3), _bounds_min.x + 1, _bounds_max.x - width)
		_lines.append(_make_line(horizontal, idx, width))
		horizontal = not horizontal
	for ln in _lines:
		for c in ln["cells"]:
			if not _patches.has(c):
				_floor.marks[c] = {"kind": "cut", "t": 0.0}
	# He walks to the start of the first line.
	var first: Dictionary = _lines[0]
	var start_cell: Vector2i = first["cells"][0]
	_scissor.move_to(Iso.to_screen(Vector2(start_cell)) + Vector2(0, 0), 1.2)
	_hud.narrate("He is going to cut along the marked line.", false, 2.4)
	Telemetry.log_event("boss", {"boss": "scissor_man", "what": "snip_telegraph", "phase": _phase})

func _begin_sweep() -> void:
	_snip_t = 0.0
	_sweep = {"cut_done": false}
	_scissor.snip_blades()
	var first: Dictionary = _lines[0]
	var cells: Array = first["cells"]
	_scissor.move_to(Iso.to_screen(Vector2(cells[cells.size() - 1])), 0.7)

func _tick_sweep(delta: float) -> void:
	_snip_t += delta
	if _snip_t >= 0.45 and not _sweep["cut_done"]:
		_sweep["cut_done"] = true
		_resolve_cuts()
	if _snip_t >= 0.9:
		_snip_t = -1.0
		_lines.clear()
		_snip_cd = [0.0, 6.5, 5.5, 5.0][_phase] + (1.5 if GameState.is_story() else 0.0)

func _resolve_cuts() -> void:
	var jammed := false
	var cut_cells: Array[Vector2i] = []
	for ln in _lines:
		for c in ln["cells"]:
			_floor.marks.erase(c) if _floor.marks.has(c) and _floor.marks[c]["kind"] == "cut" else null
			if _patches.has(c):
				jammed = true
				continue
			if _floor.cells.get(c, "") == "c":
				_floor.cells[c] = "#"
				_cuts[c] = 11.0 if not GameState.is_story() else 8.0
				cut_cells.append(c)
	camera_shake(0.3, 5.0)
	Telemetry.log_event("boss", {"boss": "scissor_man", "what": "snipped", "cells": cut_cells.size(), "jammed": jammed})
	# What he cuts out stays behind as clippings you can paste back.
	var drops := mini(2, cut_cells.size() / 3 + 1)
	for i in drops:
		if _clippings.size() >= MAX_CLIPPINGS:
			break
		var at := _random_free_cell()
		_spawn_clipping(at, SHAPES[randi() % SHAPES.size()])
	if jammed:
		_scissor.jam(7.0 if GameState.is_story() else 5.5)
		_hud.set_objective(Story.SCISSOR_OBJECTIVES[1])
		_hud.narrate(Story.SCISSOR_JAM, false, 3.0)
		Telemetry.log_event("boss", {"boss": "scissor_man", "what": "jammed"})
		_lines.clear()
		_snip_t = -1.0

func _random_free_cell() -> Vector2i:
	var pool := _arena.duplicate()
	pool.shuffle()
	var pc := _floor.cell_at(_player.position)
	for c in pool:
		if _floor.cells[c] == "c" and not _cuts.has(c) and Vector2(c - pc).length() > 2.0:
			return c
	return pool[0]

func _on_boss_damaged(frac: float) -> void:
	_hud.set_boss("The Scissor-Man", frac)
	var new_phase := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if new_phase != _phase:
		_phase = new_phase
		_hud.narrate(Story.SCISSOR_PHASE[_phase - 1], false, 4.0)
		_spawn_minions(_phase)
		Telemetry.log_event("boss", {"boss": "scissor_man", "what": "phase", "n": _phase})

func _spawn_minions(phase: int) -> void:
	if _minions_spawned.has(phase):
		return
	_minions_spawned[phase] = true
	for i in 2:
		var c := _random_free_cell()
		_add_enemy(Enemy.Kind.MITE, c)
	if phase == 3:
		_add_enemy(Enemy.Kind.BARE, _random_free_cell())

func _on_defeated() -> void:
	_finale()

func _finale() -> void:
	if _finale_done:
		return
	_finale_done = true
	_busy = true
	_lines.clear()
	for c in _arena:
		_floor.marks.erase(c)
	for c in _cuts.keys():
		_floor.cells[c] = "c"
	_cuts.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	_hud.set_boss("", 0.0)
	_hud.set_objective("")
	Telemetry.log_event("boss", {"boss": "scissor_man", "what": "won"})
	await get_tree().create_timer(1.4).timeout
	await _say(Story.scissor_finale())
	_give_item("thimble")
	GameState.set_flag("scissor_done")
	GameState.add_mnemosynth(60)
	await get_tree().create_timer(2.0).timeout
	_leave()

func _handle_cue(cue: String) -> void:
	if cue == "restore_town":
		camera_shake(0.5, 4.0)

func _on_death_reset() -> void:
	_lines.clear()
	for c in _arena:
		_floor.marks.erase(c)
	for c in _cuts.keys():
		_floor.cells[c] = "c"
	_cuts.clear()
	_patches.clear()
	_snip_t = -1.0
	_snip_cd = 5.0
	_scissor.move_to(Iso.to_screen(Vector2(12, 8)), 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

# --- Leaving ---------------------------------------------------------------------------------------------------------
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.spawn_cell = RETURN_CELL
	Transition.go(OVERWORLD, Color("e8f4ee"))
	await get_tree().create_timer(30.0).timeout
