class_name LevelBase
extends Node2D
## Shared machinery for every isometric level (the overworld and each memory):
## parchment backdrop, elevation-aware floor, player + camera, HUD, dialogue,
## interactions, plot-hole falls, cliff walls.
##
## Subclasses override the `_map_*` / `_spawn_char` / `_level_*` hooks.

const PARCHMENT_SHADER := preload("res://shaders/parchment.gdshader")
const INTERACT_RANGE := 64.0
const ZOOM := 1.5
const STAIR_DIRS := {"e": Vector2i(1, 0), "w": Vector2i(-1, 0), "s": Vector2i(0, 1), "n": Vector2i(0, -1)}

var _paper: ColorRect
var _floor: IsoFloor
var _actors: Node2D
var _player: Player
var _camera: Camera2D
var _hud: Hud
var _dialogue: DialogueBox

var _start := Vector2.ZERO
var _safe_pos := Vector2.ZERO
var _interactables: Array[Dictionary] = []   # {node, prompt: Callable, action: Callable, range: float}
var _fell_once := false
var _busy := false
var _crystals: Array[Prop] = []
var _first_proofread := false
var _shake := 0.0
var _shake_mag := 0.0

# --- Hooks -------------------------------------------------------------------------
func _map_rows() -> Array[String]:
	return []

func _map_heights() -> Array[String]:
	return []

## Shader parameter overrides for the backdrop (colors of the "page").
func _paper_params() -> Dictionary:
	return {}

## Handle a map character. Return true if consumed. `consumed` marks cells already used.
func _spawn_char(_ch: String, _cell: Vector2i, _consumed: Dictionary) -> bool:
	return false

func _level_ready() -> void:
	pass

func _level_process(_delta: float) -> void:
	pass

func _handle_cue(_cue: String) -> void:
	pass

func _spawn_override() -> Vector2i:
	return Vector2i(-1, -1)

# --- Lifecycle ---------------------------------------------------------------------
func _ready() -> void:
	GameState.in_dialogue = false
	_build_background()
	_floor = IsoFloor.new()
	add_child(_floor)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_load_map()
	_floor.build(_actors)       # slices live in the Y-sorted layer so cliffs occlude correctly
	_add_edge_walls()
	_add_void_walls()
	_build_player()
	_build_ui()
	GameState.mnemosynth_changed.connect(_hud.set_mnemo)
	_hud.set_mnemo(GameState.mnemosynth)
	_level_ready()

func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	_paper = ColorRect.new()
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PARCHMENT_SHADER
	for k in _paper_params():
		mat.set_shader_parameter(k, _paper_params()[k])
	_paper.material = mat
	bg.add_child(_paper)

# --- Map loading ---------------------------------------------------------------------
func _load_map() -> void:
	_parse_heights()
	var rows := _map_rows()
	var consumed := {}
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var cell := Vector2i(x, y)
			if consumed.has(cell) or ch == " ":
				continue
			if _spawn_char(ch, cell, consumed):
				continue
			match ch:
				".", ",", "#", "m":
					_floor.cells[cell] = ch
				"P":
					_floor.cells[cell] = "."
					_start = Iso.to_screen(Vector2(cell))
	var ov := _spawn_override()
	if ov != Vector2i(-1, -1):
		_start = Iso.to_screen(Vector2(ov))

func _parse_heights() -> void:
	var hrows := _map_heights()
	for y in hrows.size():
		for x in hrows[y].length():
			var ch := hrows[y][x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if STAIR_DIRS.has(ch):
				_floor.stairs[cell] = STAIR_DIRS[ch]
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

func _register(node: Node2D, prompt: Callable, action: Callable, rng: float = INTERACT_RANGE) -> void:
	_interactables.append({"node": node, "prompt": prompt, "action": action, "range": rng})

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
	_player.floor_ref = _floor
	_player.hit_landed.connect(func(): camera_shake(0.12, 2.5))
	_player.fell.connect(_on_player_fell)
	_player.crumpled.connect(_on_player_crumpled)
	_player.ink = GameState.ink
	_player.elev = _floor.height_at(_start) * Iso.LEVEL_H
	_player.ink_changed.connect(func(cur: float, _mx: float): GameState.ink = cur)

func _build_ui() -> void:
	var ital := load("res://assets/fonts/IMFellEnglish-Italic.ttf") as Font
	ThemeDB.get_default_theme().set_font("italics_font", "RichTextLabel", ital)
	_hud = Hud.new()
	add_child(_hud)
	_player.ink_changed.connect(_hud.set_ink)
	_hud.set_ink(_player.ink, _player.max_ink)
	_player.lantern_changed.connect(_hud.set_lantern)
	_hud.set_lantern(_player.lantern_energy, Player.LANTERN_MAX)
	_hud.set_controls(_player.can_attack())
	_dialogue = DialogueBox.new()
	add_child(_dialogue)

# --- Frame loop -----------------------------------------------------------------------
func _process(delta: float) -> void:
	_update_elevation(delta)
	_floor.focus = _camera.get_screen_center_position()
	var size := get_viewport_rect().size
	var view := size / _camera.zoom
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", view)
	mat.set_shader_parameter("scroll", _camera.get_screen_center_position() - view * 0.5)
	_track_cell()
	_update_prompt()
	_collect_crystals()
	_level_process(delta)

func _update_elevation(delta: float) -> void:
	var target := _floor.height_at(_player.position) * Iso.LEVEL_H
	_player.elev = lerpf(_player.elev, target, 1.0 - exp(-16.0 * delta))
	var off := Vector2(0, -_player.elev)
	if _shake > 0.0:
		_shake -= delta
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_mag * clampf(_shake / 0.4, 0.0, 1.0)
	_camera.offset = off

func camera_shake(duration: float = 0.4, mag: float = 6.0) -> void:
	_shake = duration
	_shake_mag = mag

# --- Crystals (Mnemosynth) --------------------------------------------------------------
func _collect_crystals() -> void:
	for c in _crystals.duplicate():
		if not is_instance_valid(c):
			_crystals.erase(c)
			continue
		if _dist(c.position, _player.position) < 30.0 and absf(c.lift - _player.elev) < 20.0:
			_crystals.erase(c)
			GameState.add_mnemosynth(5)
			_player.refuel(18.0)          # the Lantern burns Mnemosynth
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
			tw.tween_callback(c.queue_free)

func drop_crystals(pos: Vector2, n: int) -> void:
	for i in n:
		var p := Prop.new()
		p.kind = Prop.Kind.CRYSTAL
		p.position = pos + Vector2(randf_range(-26.0, 26.0), randf_range(-12.0, 12.0))
		p.lift = _floor.height_at(p.position) * Iso.LEVEL_H
		_actors.add_child(p)
		_crystals.append(p)

# --- Enemies and Redactors ---------------------------------------------------------------
func _add_enemy(kind: Enemy.Kind, cell: Vector2i) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.floor_ref = _floor
	e.target = _player
	e.position = Iso.to_screen(Vector2(cell))
	e.elev = _lift_at(cell)
	_actors.add_child(e)
	e.died.connect(func(en: Enemy): drop_crystals(en.position, 2 if en.kind == Enemy.Kind.BARE else 1))
	e.proofread.connect(_on_proofread)
	return e

func _on_proofread(e: Enemy) -> void:
	drop_crystals(e.position, 6)
	_hud.toast("Proofread: Bare → Bear")
	if not _first_proofread:
		_first_proofread = true
		_hud.narrate(Story.PROOFREAD, false, 5.0)

func _add_redactor(cell: Vector2i, axis: Vector2, length: float, text: String) -> Redactor:
	var r := Redactor.new()
	r.axis = axis
	r.length = length
	r.text = text
	r.position = Iso.to_screen(Vector2(cell))
	r.elev = _lift_at(cell)
	_actors.add_child(r)
	return r

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

func _nearest() -> Dictionary:
	var best := {}
	var best_d := 100000.0
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
		if d < it["range"] and d < best_d:
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
	await _dialogue.play(lines, _handle_cue)

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
