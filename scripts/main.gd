extends Node2D
## Phase 2: the Prologue Plains and Thistledown (the first Ghost Town).
## Builds the world from data/prologue_map.gd, wires interactions, and runs
## the restoration cutscene.

const PARCHMENT_SHADER := preload("res://shaders/parchment.gdshader")
const INTERACT_RANGE := 64.0
const ZOOM := 1.5

var _paper: ColorRect
var _floor: IsoFloor
var _actors: Node2D
var _player: Player
var _camera: Camera2D
var _hud: Hud
var _dialogue: DialogueBox

var _start := Vector2.ZERO
var _safe_pos := Vector2.ZERO
var _interactables: Array[Dictionary] = []   # {node, prompt: Callable, action: Callable}
var _crystals: Array[Prop] = []
var _sword_prop: Prop
var _garrick: Npc
var _pip: Npc
var _maud: Npc
var _fell_once := false
var _entered_town := false
var _busy := false

func _ready() -> void:
	_build_background()
	_floor = IsoFloor.new()
	add_child(_floor)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_load_map()
	_floor.build(_actors)       # slices live in the Y-sorted layer so cliffs occlude correctly
	_add_edge_walls()
	_build_player()
	_build_ui()
	GameState.mnemosynth_changed.connect(_hud.set_mnemo)
	_start_intro()

# --- Setup ----------------------------------------------------------------------
func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	_paper = ColorRect.new()
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PARCHMENT_SHADER
	_paper.material = mat
	bg.add_child(_paper)

func _load_map() -> void:
	var rows: Array[String] = PrologueMap.ROWS
	_parse_heights()
	var consumed := {}
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var cell := Vector2i(x, y)
			if consumed.has(cell):
				continue
			match ch:
				" ":
					pass
				".", ",", "#":
					_floor.cells[cell] = ch
				"P":
					_floor.cells[cell] = "."
					_start = Iso.to_screen(Vector2(cell))
				"T":
					_floor.cells[cell] = "."
					_add_prop(Prop.Kind.TREE, cell, false, x + y)
				"C":
					_floor.cells[cell] = "."
					_crystals.append(_add_prop(Prop.Kind.CRYSTAL, cell))
				"S":
					_floor.cells[cell] = "."
					_sword_prop = _add_prop(Prop.Kind.SWORD, cell)
					_interactables.append({"node": _sword_prop, "prompt": func(): return "Take", "action": _take_sword})
				"W":
					_floor.cells[cell] = "."
					var p := _add_prop(Prop.Kind.SIGN, cell)
					_interactables.append({"node": p, "prompt": func(): return "Read", "action": func(): await _say(Story.tutorial_sign())})
				"X":
					_floor.cells[cell] = ","
					var p2 := _add_prop(Prop.Kind.SIGN, cell, true)
					_interactables.append({"node": p2, "prompt": func(): return "Read", "action": func(): await _say(Story.town_sign())})
				"H", "F":
					for dx in 2:
						for dy in 2:
							var c2 := cell + Vector2i(dx, dy)
							consumed[c2] = true
							_floor.cells[c2] = ","
					var kind := Prop.Kind.HOUSE if ch == "H" else Prop.Kind.FORGE
					var hp := Prop.new()
					hp.kind = kind
					hp.ghost = true
					hp.variant = x + y
					hp.lift = _lift_at(cell)
					hp.position = Iso.to_screen(Vector2(cell) + Vector2(0.5, 0.5))
					_actors.add_child(hp)
				"N", "K", "B":
					_floor.cells[cell] = ","
					_add_npc(ch, cell)
	_add_void_walls()

const STAIR_DIRS := {"e": Vector2i(1, 0), "w": Vector2i(-1, 0), "s": Vector2i(0, 1), "n": Vector2i(0, -1)}

func _parse_heights() -> void:
	var hrows: Array[String] = PrologueMap.HEIGHTS
	for y in hrows.size():
		for x in hrows[y].length():
			var ch := hrows[y][x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if STAIR_DIRS.has(ch):
				_floor.stairs[cell] = STAIR_DIRS[ch]
				# Stairs start at the level of whatever is at their low end.
				var low: Vector2i = cell - STAIR_DIRS[ch]
				_floor.heights[cell] = int(hrows[low.y][low.x])
			else:
				_floor.heights[cell] = int(ch)

func _lift_at(cell: Vector2i) -> float:
	return _floor.height_of(cell) * Iso.LEVEL_H

func _add_prop(kind: Prop.Kind, cell: Vector2i, ghost: bool = false, variant: int = 0) -> Prop:
	var p := Prop.new()
	p.kind = kind
	p.ghost = ghost
	p.variant = variant
	p.lift = _lift_at(cell)
	p.position = Iso.to_screen(Vector2(cell))
	_actors.add_child(p)
	return p

func _add_npc(ch: String, cell: Vector2i) -> void:
	var n := Npc.new()
	n.lift = _lift_at(cell)
	n.position = Iso.to_screen(Vector2(cell))
	_actors.add_child(n)
	match ch:
		"N":
			n.kind = Npc.Kind.BLACKSMITH
			_garrick = n
			_interactables.append({"node": n, "prompt": func(): return "Speak", "action": _talk_garrick})
		"K":
			n.kind = Npc.Kind.CHILD
			_pip = n
			_interactables.append({"node": n, "prompt": func(): return "Speak",
				"action": func(): await _say(Story.pip_restored() if GameState.town_restored else Story.pip_ghost())})
		"B":
			n.kind = Npc.Kind.BAKER
			_maud = n
			_interactables.append({"node": n, "prompt": func(): return "Speak",
				"action": func(): await _say(Story.maud_restored() if GameState.town_restored else Story.maud_ghost())})

## Cliffs are solid: block every cell edge where the ground steps up or down
## without a staircase.
func _add_edge_walls() -> void:
	for cell: Vector2i in _floor.cells.keys():
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = cell + step
			if not _floor.cells.has(n) or _floor.edge_open(cell, n):
				continue
			var a: Vector2
			var b: Vector2
			if step.x == 1:
				a = Iso.to_screen(Vector2(cell) + Vector2(0.5, -0.5))
				b = Iso.to_screen(Vector2(cell) + Vector2(0.5, 0.5))
			else:
				a = Iso.to_screen(Vector2(cell) + Vector2(-0.5, 0.5))
				b = Iso.to_screen(Vector2(cell) + Vector2(0.5, 0.5))
			var body := StaticBody2D.new()
			var seg := CollisionShape2D.new()
			var shape := SegmentShape2D.new()
			shape.a = a
			shape.b = b
			seg.shape = shape
			body.add_child(seg)
			add_child(body)

## Collision walls around the page edge so the Storytender can't walk off into the void.
func _add_void_walls() -> void:
	var done := {}
	for cell: Vector2i in _floor.cells.keys():
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := cell + Vector2i(dx, dy)
				if _floor.cells.has(n) or done.has(n):
					continue
				done[n] = true
				var body := StaticBody2D.new()
				var poly := CollisionPolygon2D.new()
				poly.polygon = Iso.diamond(Vector2.ZERO, 1.02)
				body.position = Iso.to_screen(Vector2(n))
				body.add_child(poly)
				add_child(body)

func _build_player() -> void:
	_player = Player.new()
	_player.position = _start
	_safe_pos = _start
	_actors.add_child(_player)
	var cs := CollisionPolygon2D.new()
	cs.polygon = Iso.diamond(Vector2.ZERO, 0.4)
	_player.add_child(cs)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_player.add_child(_camera)
	_player.fell.connect(_on_player_fell)
	_player.crumpled.connect(_on_player_crumpled)

func _build_ui() -> void:
	var ital := load("res://assets/fonts/IMFellEnglish-Italic.ttf") as Font
	ThemeDB.get_default_theme().set_font("italics_font", "RichTextLabel", ital)
	_hud = Hud.new()
	add_child(_hud)
	_player.ink_changed.connect(_hud.set_ink)
	_dialogue = DialogueBox.new()
	add_child(_dialogue)

# --- Intro --------------------------------------------------------------------
func _start_intro() -> void:
	await get_tree().create_timer(1.2).timeout
	for t in Story.INTRO:
		_hud.narrate(t, false, 3.2)
		await get_tree().create_timer(5.6).timeout

# --- Frame loop -----------------------------------------------------------------
func _process(delta: float) -> void:
	_update_elevation(delta)
	_floor.focus = _camera.get_screen_center_position()
	var size := get_viewport_rect().size
	var view := size / _camera.zoom
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", view)
	mat.set_shader_parameter("scroll", _camera.get_screen_center_position() - view * 0.5)

	_track_cell()
	_collect_crystals()
	_update_region()
	_update_prompt()

func _update_elevation(delta: float) -> void:
	var target := _floor.height_at(_player.position) * Iso.LEVEL_H
	_player.elev = lerpf(_player.elev, target, 1.0 - exp(-16.0 * delta))
	_camera.offset.y = -_player.elev

func _dist(a: Vector2, b: Vector2) -> float:
	var d := a - b
	d.y *= 2.0
	return d.length()

func _track_cell() -> void:
	if _player.is_falling or _player.is_crumpled:
		return
	var cell := _floor.cell_at(_player.position)
	if _floor.is_pit(cell):
		_player.fall()
		return
	# Remember the last spot that was safely away from any plot hole.
	var safe := true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _floor.is_pit(cell + Vector2i(dx, dy)):
				safe = false
	if safe and _floor.has_cell(cell):
		_safe_pos = _player.position

func _collect_crystals() -> void:
	for c in _crystals.duplicate():
		if _dist(c.position, _player.position) < 30.0:
			_crystals.erase(c)
			GameState.add_mnemosynth(5)
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
			tw.tween_callback(c.queue_free)

func _update_region() -> void:
	var cell := _floor.cell_at(_player.position)
	if cell.x >= IsoFloor.PLAINS_X_LIMIT:
		_hud.set_region("Thistledown — Published Chapter" if GameState.town_restored else "Thistledown (Draft)")
		if not _entered_town:
			_entered_town = true
			_hud.narrate(Story.SILENCE_WHISPER, true, 5.0)
	else:
		_hud.set_region("The Prologue Plains")

func _nearest() -> Dictionary:
	var best := {}
	var best_d := INTERACT_RANGE
	for it in _interactables:
		var n: Node2D = it["node"]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if it["prompt"].call() == "":
			continue
		var d := _dist(n.position, _player.position)
		# Different floors don't talk to each other.
		if absf(_floor.height_at(n.position) - _floor.height_at(_player.position)) > 0.6:
			continue
		if d < best_d:
			best_d = d
			best = it
	return best

func _update_prompt() -> void:
	if _busy or GameState.in_dialogue or _player.is_falling or _player.is_crumpled:
		_hud.set_prompt("")
		return
	var it := _nearest()
	_hud.set_prompt(it["prompt"].call() if not it.is_empty() else "")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _busy or GameState.in_dialogue:
		return
	var it := _nearest()
	if it.is_empty():
		return
	_busy = true
	await it["action"].call()
	_busy = false

# --- Dialogue plumbing ----------------------------------------------------------------
func _say(lines: Array) -> void:
	await _dialogue.play(lines, _on_cue)

func _on_cue(cue: String) -> void:
	match cue:
		"name_reveal":
			_garrick.named = true
			_garrick.display_name = "Garrick"
		"tear":
			_garrick.tearful = true
		"restore":
			await _restoration_scene()

# --- Story beats ------------------------------------------------------------------------
func _take_sword() -> void:
	await _say(Story.pickup_sword())
	GameState.set_flag("has_sword")
	_hud.toast("Found: The First Sword")
	_hud.narrate(Story.SWORD_NARRATION, false, 4.5)
	var tw := create_tween()
	tw.tween_property(_sword_prop, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_sword_prop.queue_free)

func _talk_garrick() -> void:
	if GameState.town_restored:
		await _say(Story.garrick_restored())
	elif GameState.has_flag("has_sword"):
		await _say(Story.garrick_restoration())
		GameState.add_mnemosynth(25)
		_hud.toast("Chapter Restored: Thistledown")
		_garrick.tearful = false
		GameState.set_flag("town_restored")
	elif GameState.has_flag("met_garrick"):
		await _say(Story.garrick_ghost_repeat())
	else:
		GameState.set_flag("met_garrick")
		await _say(Story.garrick_ghost())

func _restoration_scene() -> void:
	_dialogue.hold(true)
	_hud.set_prompt("")
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_camera, "zoom", Vector2(ZOOM * 1.18, ZOOM * 1.18), 2.0).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.8).timeout
	_hud.narrate(Story.RESTORED_NARRATION, false, 3.0)
	GameState.start_restoration(_garrick.position)
	await get_tree().create_timer(GameState.RESTORE_DURATION * 0.75).timeout
	var back := create_tween()
	back.tween_property(_camera, "zoom", Vector2(ZOOM, ZOOM), 2.5).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.2).timeout
	_dialogue.hold(false)

# --- Falling / crumpling ----------------------------------------------------------------
func _on_player_fell() -> void:
	_player.take_damage(10.0, false)
	_player.respawn_at(_safe_pos)
	if not _fell_once:
		_fell_once = true
		_hud.narrate(Story.FALL_FIRST, false, 4.0)

func _on_player_crumpled() -> void:
	_hud.narrate(Story.CRUMPLED, false, 4.0)
	await get_tree().create_timer(2.2).timeout
	_player.restore_ink(60.0)
	_player.respawn_at(_safe_pos)
