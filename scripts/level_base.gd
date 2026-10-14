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
var _paper_vp: SubViewport
var _paper_view: TextureRect
var _paper_flat: ColorRect
var _paper_vignette := 0.2
var _floor: IsoFloor
var _actors: Node2D
var ambient_leaves := false          # the overworld sets this: drifting leaves and paper scraps
var _player: Player
var _camera: Camera2D
var _hud: Hud
var _dialogue: DialogueBox
var _inventory: InventoryScreen
var _index: IndexHub
var _pause: PauseMenu
var _world_map: WorldMap
var _chunks: GroundChunks

var _start := Vector2.ZERO
## Dungeons offer "Travel to a lantern" and "Restart this dungeon" in the pause menu. The overworld turns it off.
var dungeon_menu := true
var _dpost_list: Array[Dictionary] = []   # this dungeon's lantern posts: {cell: Vector2i, name: String}
var _map_start := Vector2.ZERO     # the map's own start cell, ignoring return-spawn overrides
var _safe_pos := Vector2.ZERO
var _interactables: Array[Dictionary] = []   # {node, prompt: Callable, action: Callable, range: float}
var _fell_once := false
var _busy := false
var echo_enabled := false            # Garrick's memory verb: R records a ghost of you that stands on plates
var _echoes: Array[Echo] = []
var _recording: Echo
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

## Which music slot plays in this level (see assets/music/README.md).
func _music_slot() -> String:
	return "overworld"

func _level_process(_delta: float) -> void:
	pass

func _handle_cue(_cue: String) -> void:
	pass

func _spawn_override() -> Vector2i:
	return Vector2i(-1, -1)

## Name of the room/area a cell belongs to (for the playtest log).
func _room_name(_cell: Vector2i) -> String:
	return ""

## Where you wake up after being crumpled (normal difficulty): the start of the current room.
func _checkpoint_for(_cell: Vector2i) -> Vector2:
	return _start

## Reset the room's enemies / hazards after a death.
func _on_death_reset() -> void:
	pass

# --- Lifecycle ---------------------------------------------------------------------
func _ready() -> void:
	GameState.in_dialogue = false
	Telemetry.enter_scene(String(name))
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
	if ambient_leaves:
		add_child(AmbientDrift.new())
	_build_ui()
	GameState.mnemosynth_changed.connect(_hud.set_mnemo)
	GameState.renown_changed.connect(func(_v: int, _r: int): _hud.set_renown())
	GameState.rank_up.connect(_on_rank_up)
	_hud.set_renown()
	_hud.set_mnemo(GameState.mnemosynth)
	_place_dungeon_extras()
	Music.play(_music_slot())
	_level_ready()

func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	# The parchment shader is expensive per pixel, and it is soft grain, so it renders into a
	# smaller viewport and is stretched to fill the screen. Settings > Graphics sets the size.
	_paper_vp = SubViewport.new()
	_paper_vp.disable_3d = true
	_paper_vp.transparent_bg = false
	_paper_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bg.add_child(_paper_vp)
	_paper = ColorRect.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PARCHMENT_SHADER
	for k in _paper_params():
		mat.set_shader_parameter(k, _paper_params()[k])
	_paper.material = mat
	_paper_vp.add_child(_paper)
	_paper_vignette = float(_paper_params().get("vignette", 0.2))
	# "Flat color" paper: no shader at all, just the average paper tone.
	_paper_flat = ColorRect.new()
	_paper_flat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper_flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pl: Color = _paper_params().get("paper_light", Color(0.91, 0.84, 0.68))
	var pd: Color = _paper_params().get("paper_dark", Color(0.72, 0.60, 0.40))
	_paper_flat.color = pl.lerp(pd, 0.35)
	bg.add_child(_paper_flat)
	_paper_view = TextureRect.new()
	_paper_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper_view.stretch_mode = TextureRect.STRETCH_SCALE
	_paper_view.texture = _paper_vp.get_texture()
	_paper_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.add_child(_paper_view)
	Settings.quality_changed.connect(_apply_paper_scale)
	_apply_paper_scale()

func _apply_paper_scale() -> void:
	var sc := Settings.paper_scale()
	var flat := sc <= 0.0
	_paper_view.visible = not flat
	_paper_flat.visible = flat
	_paper_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if flat else SubViewport.UPDATE_ALWAYS
	var size := Vector2i(int(1280.0 * maxf(sc, 0.25)) + 1, int(720.0 * maxf(sc, 0.25)) + 1)
	_paper_vp.size = size
	_paper.size = Vector2(size)
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("detail", float(Settings.g("paper_detail")))
	mat.set_shader_parameter("vignette", _paper_vignette if Settings.gfx_on("vignette") else 0.0)

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
					_map_start = _start
	var ov := _spawn_override()
	if ov != Vector2i(-1, -1):
		_start = Iso.to_screen(Vector2(ov))
		GameState.spawn_cell = Vector2i(-1, -1)   # consumed

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
	if kind == Prop.Kind.TREE:
		_floor.blockers[cell] = true
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
	_camera.reset_smoothing()          # start on the player, not gliding in from the page origin
	_floor.focus = _start
	_player.floor_ref = _floor
	_player.hit_landed.connect(func(): camera_shake(0.12, 2.5))
	_player.fell.connect(_on_player_fell)
	_player.style_changed.connect(func(st: String): _hud.set_style(st))
	_player.crumpled.connect(_on_player_crumpled)
	_player.max_ink = 100.0 + GameState.max_ink_bonus()
	_player.ink = minf(GameState.ink, _player.max_ink)
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
	_hud.show_toolbar(GameState.has_flag("format_mark"))
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_inventory = InventoryScreen.new()
	add_child(_inventory)
	_pause = PauseMenu.new()
	_pause.level = self
	add_child(_pause)
	_pause.restart_requested.connect(restart_dungeon)
	_pause.travel_requested.connect(dungeon_travel)
	_index = IndexHub.new()
	add_child(_index)
	_index.map_requested.connect(_open_map)
	_world_map = WorldMap.new()
	var map_layer := CanvasLayer.new()
	map_layer.layer = 55
	map_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	map_layer.add_child(_world_map)
	add_child(map_layer)
	_world_map.travel_requested.connect(_on_travel_requested)
	_pause.map_requested.connect(_open_map)
	_inventory.use_requested.connect(use_item)
	GameState.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()

# --- Frame loop -----------------------------------------------------------------------
## Safety net: if the game believes a conversation is open but nothing is (no dialogue, card,
## cutscene or interaction), release the player after a moment instead of leaving them frozen.
var _stuck_t := 0.0
func _watchdog(delta: float) -> void:
	var busy := _busy or _in_cutscene or _dialogue.visible or _hud.tutorial_open() or get_tree().paused
	if GameState.in_dialogue and not busy:
		_stuck_t += delta
		if _stuck_t > 1.5:
			_stuck_t = 0.0
			GameState.in_dialogue = false
			Telemetry.log_event("watchdog_unstick", {"scene": String(name)})
	else:
		_stuck_t = 0.0

func _process(delta: float) -> void:
	_watchdog(delta)
	for rd in get_tree().get_nodes_in_group("redactors"):
		if is_instance_valid(rd):
			rd.near = _dist(rd.position, _player.position) < 320.0
	_update_elevation(delta)
	_update_sort_z()
	_update_occlusion(delta)
	_floor.focus = _camera.get_screen_center_position()
	var size := get_viewport_rect().size
	var view := size / _camera.zoom
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", view)
	mat.set_shader_parameter("scroll", _camera.get_screen_center_position() - view * 0.5)
	_track_cell()
	Telemetry.enter_room(_room_name(_floor.cell_at(_player.position)))
	_update_prompt()
	_collect_crystals()
	_level_process(delta)

## Everything standing in the world is drawn in order of the diagonal row of cells it occupies
## (z = 3 * (x + y) + 1), which matches the ground nodes in IsoFloor.build. Unlike sorting by y
## position, this never flips while something crosses the middle of a cell.
func _update_sort_z() -> void:
	for n in _actors.get_children():
		if n is IsoSlice or not (n is Node2D):
			continue
		if n.has_meta("z_done"):
			continue
		var node := n as Node2D
		var cell := _floor.cell_at(node.position)
		var s := cell.x + cell.y
		var extra := 0
		var flat := false
		if node is Prop:
			var pk: int = (node as Prop).kind
			if pk == Prop.Kind.HOUSE or pk == Prop.Kind.FORGE:
				extra = 1            # a 2x2 building spans one more row than its centre cell
			elif pk == Prop.Kind.TABLE:
				extra = int((node as Prop).table_len * 0.5)
			node.set_meta("z_done", true)       # props never move
		elif node is PressurePlate or node is EchoPlate or node is PasteGhost:
			flat = true
		node.z_index = 3 * (s + extra) + (0 if flat else 1)

## Things that stand between the camera and the player fade out, so you can always see yourself:
## raised ground and stairs in front of you, and trees, houses and other tall props.
func _update_occlusion(delta: float) -> void:
	var on := Settings.gfx_on("see_through") and _player and is_instance_valid(_player) and not _player.preview
	var pc := _floor.cell_at(_player.position)
	var list: Array = []
	if on:
		var pl := _floor.level(pc)
		# Only ground that is actually drawn over the Storytender fades. A raised cell covers the
		# convex shape swept from its top face down to the level the player stands on, so test
		# whether the player's head or chest lies inside that shape. (Fading everything in front,
		# as before, left big see-through blocks of cliff hanging over houses and ground.)
		var feet := _player.position + Vector2(0, -_player.elev)
		var probes := [feet + Vector2(0, -34), feet + Vector2(0, -20), feet + Vector2(0, -6)]
		for dx in range(0, 4):
			for dy in range(0, 4):
				if dx == 0 and dy == 0:
					continue
				var c := pc + Vector2i(dx, dy)
				if not _floor.cells.has(c) or _floor.level(c) <= pl:
					continue
				var lc := float(_floor.level(c))
				var hull_pts := PackedVector2Array()
				for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
					hull_pts.append(Iso.pt(Vector2(c) + corner, lc))
					hull_pts.append(Iso.pt(Vector2(c) + corner, float(pl)))
				var hull := Geometry2D.convex_hull(hull_pts)
				for pr: Vector2 in probes:
					if Geometry2D.is_point_in_polygon(pr, hull):
						list.append(c)
						break
	_floor.set_fade(list)
	# tall props in front of the player
	var pp := _player.position
	for n in _actors.get_children():
		if not (n is Prop):
			continue
		var pr := n as Prop
		var want := 1.0
		if on and pr.kind in [Prop.Kind.TREE, Prop.Kind.HOUSE, Prop.Kind.FORGE, Prop.Kind.OVEN, Prop.Kind.GATE, Prop.Kind.POST, Prop.Kind.SIGN]:
			var tall := 110.0 if pr.kind == Prop.Kind.TREE else (150.0 if pr.kind in [Prop.Kind.HOUSE, Prop.Kind.FORGE] else 70.0)
			var half_w := 46.0 if pr.kind == Prop.Kind.TREE else (96.0 if pr.kind in [Prop.Kind.HOUSE, Prop.Kind.FORGE] else 30.0)
			var d := pr.position - pp
			if d.y > 6.0 and d.y < tall and absf(d.x) < half_w:
				want = 0.4
		if absf(pr.modulate.a - want) > 0.01:
			pr.modulate.a = move_toward(pr.modulate.a, want, delta * 6.0)

func _update_elevation(delta: float) -> void:
	var target := _floor.height_at(_player.position) * Iso.LEVEL_H
	_player.elev = lerpf(_player.elev, target, 1.0 - exp(-16.0 * delta))
	var off := Vector2(0, -_player.elev)
	if _shake > 0.0:
		_shake -= delta
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_mag * clampf(_shake / 0.4, 0.0, 1.0)
	if _cine_w > 0.0:
		var look := (_cine_at - _player.position) + Vector2(0, -_player.elev)
		off = off.lerp(look, _cine_w)
	_camera.offset = off

# --- Cutscenes -------------------------------------------------------------------------------------
var _cine_at := Vector2.ZERO     # world point the camera looks at during a cutscene
var _cine_w := 0.0               # 0 = follow the player, 1 = look at _cine_at
var _in_cutscene := false

## Plays a short cinematic: letterbox bars, the camera glides to each shot, dialogue or narration plays,
## then the camera returns to the player. A shot: {at: Vector2 (world position), zoom: float,
## pan: seconds, lines: Array (dialogue), text: String (narration), hold: seconds, call: Callable}.
## Skippable lines still work like normal dialogue.
func cinematic(shots: Array) -> void:
	if _in_cutscene:
		return
	_in_cutscene = true
	GameState.in_dialogue = true
	_hud.set_boss_hidden(true)
	var bars := create_tween()
	bars.tween_method(func(v: float): _hud.set_letterbox(v), 0.0, 1.0, 0.6)
	for s: Dictionary in shots:
		var at: Vector2 = s.get("at", _player.position)
		var zoom: float = float(s.get("zoom", ZOOM))
		var pan: float = float(s.get("pan", 1.2))
		_cine_at = _cine_at.lerp(at, 1.0) if _cine_w > 0.0 and false else _cine_at
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_cine_at", at, pan)
		tw.tween_property(self, "_cine_w", 1.0, pan)
		tw.tween_property(_camera, "zoom", Vector2(zoom, zoom), pan)
		await tw.finished
		if s.has("call"):
			(s["call"] as Callable).call()
		if s.has("lines"):
			await _say(s["lines"])
			GameState.in_dialogue = true
		elif s.has("text"):
			_hud.narrate(String(s["text"]), false, float(s.get("hold", 2.0)))
		await get_tree().create_timer(float(s.get("hold", 0.8))).timeout
	var back := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	back.tween_property(self, "_cine_w", 0.0, 1.0)
	back.tween_property(_camera, "zoom", Vector2(ZOOM, ZOOM), 1.0)
	back.tween_method(func(v: float): _hud.set_letterbox(v), 1.0, 0.0, 0.8)
	await back.finished
	_hud.set_boss_hidden(false)
	GameState.in_dialogue = false
	_in_cutscene = false

func camera_shake(duration: float = 0.4, mag: float = 6.0) -> void:
	if not Settings.screen_shake:
		return
	_shake = duration
	_shake_mag = mag

# --- Items ---------------------------------------------------------------------------------
func _on_inventory_changed() -> void:
	_hud.refresh_quick()

func _give_item(id: String, n: int = 1) -> void:
	GameState.add_item(id, n)
	_hud.toast("Received: %s%s" % [ItemDB.info(id)["name"], "" if n == 1 else " ×%d" % n])

func use_item(id: String) -> void:
	if id == "" or GameState.count(id) <= 0 or _player.is_crumpled or _player.is_falling or GameState.in_dialogue:
		return
	Telemetry.log_event("item", {"id": id})
	match id:
		"pocket_workbench":
			_index.open_craft()
		"eraser_crumbs":
			var reach := 150.0
			var goal := _player.position + Vector2(_player.aim_ground.x, _player.aim_ground.y * 0.5) * reach
			# Shorten the throw until it lands on the page and not inside a plot hole.
			while reach > 30.0 and (not _floor.has_cell(_floor.cell_at(goal)) or _floor.is_pit(_floor.cell_at(goal))):
				reach -= 25.0
				goal = _player.position + Vector2(_player.aim_ground.x, _player.aim_ground.y * 0.5) * reach
			GameState.remove_item(id)
			var b := EraserBomb.new()
			b.start = _player.position
			b.goal = goal
			b.elev = _floor.height_at(_player.position) * Iso.LEVEL_H
			b.exploded.connect(func(_p: Vector2): camera_shake(0.35, 7.0))
			_actors.add_child(b)
		"warm_loaf":
			if _player.ink >= _player.max_ink - 0.5:
				_hud.toast("Your ink is already full")
				return
			GameState.remove_item(id)
			_player.ink = minf(_player.ink + 60.0, _player.max_ink)
			_player.ink_changed.emit(_player.ink, _player.max_ink)
			_hud.toast("A warm loaf. You feel looked after.")
		"ink_flask":
			if _player.ink >= _player.max_ink - 0.5:
				_hud.toast("Your ink is already full")
				return
			GameState.remove_item(id)
			_player.ink = _player.max_ink
			_player.ink_changed.emit(_player.ink, _player.max_ink)
			_hud.toast("Ink flask: all your ink is back")
		"lantern_oil":
			if _player.lantern_energy >= 99.0:
				_hud.toast("The Lantern is already full")
				return
			GameState.remove_item(id)
			_player.refuel(100.0)
			_hud.toast("The Lantern burns bright")
		"sticky_note":
			var stuck := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and _dist(e.position, _player.position) < 240.0 and not e.friendly:
					e.sleep_for(6.0)
					stuck += 1
			if stuck == 0:
				_hud.toast("Nothing nearby to stick")
				return
			GameState.remove_item(id)
			_hud.toast("Stuck %d Error%s to the page" % [stuck, "" if stuck == 1 else "s"])
		"ink_vial":
			if _player.ink >= _player.max_ink - 0.5:
				_hud.toast("Your ink is already full")
				return
			GameState.remove_item(id)
			_player.ink = minf(_player.ink + 45.0, _player.max_ink)
			_player.ink_changed.emit(_player.ink, _player.max_ink)
			_hud.toast("Ink restored")
		_:
			_use_data_item(id)

## Consumables defined in ItemCatalog by a "use" dictionary: ink, lantern, sleep, renown, mnemo.
func _use_data_item(id: String) -> void:
	var use: Dictionary = ItemDB.info(id).get("use", {})
	if use.is_empty():
		return
	var did := false
	if use.has("ink") and _player.ink < _player.max_ink - 0.5:
		_player.ink = minf(_player.ink + float(use["ink"]), _player.max_ink)
		_player.ink_changed.emit(_player.ink, _player.max_ink)
		did = true
	if use.has("lantern") and _player.lantern_energy < 99.0:
		_player.refuel(float(use["lantern"]))
		did = true
	if use.has("sleep"):
		var n := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and _dist(e.position, _player.position) < float(use.get("radius", 240.0)) and not e.friendly:
				e.sleep_for(float(use["sleep"]))
				n += 1
		did = did or n > 0
	if use.has("renown"):
		GameState.add_renown(int(use["renown"]))
		did = true
	if use.has("mnemo"):
		GameState.add_mnemosynth(int(use["mnemo"]))
		did = true
	if not did:
		_hud.toast("That wouldn't do anything right now")
		return
	GameState.remove_item(id)
	_hud.toast(String(use.get("msg", "Used " + ItemDB.info(id)["name"])))

func _add_pickup(cell: Vector2i, id: String) -> Prop:
	var p := _add_prop(Prop.Kind.PICKUP, cell)
	p.item_id = id
	_register(p, func(): return "Take " + ItemDB.info(id)["name"], func():
		_give_item(id)
		if p.has_meta("got_key"):
			GameState.set_flag(p.get_meta("got_key"))
		p.queue_free())
	return p

# --- Crystals (Mnemosynth) --------------------------------------------------------------
func _collect_crystals() -> void:
	for c in _crystals.duplicate():
		if not is_instance_valid(c):
			_crystals.erase(c)
			continue
		if _dist(c.position, _player.position) < 30.0 and absf(c.lift - _player.elev) < 20.0:
			_crystals.erase(c)
			_crystal_collected(c)
			GameState.add_mnemosynth(5)
			_player.refuel(12.0)          # the Lantern burns Mnemosynth
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
			tw.tween_callback(c.queue_free)

func _on_rank_up(r: int) -> void:
	_player.max_ink = 100.0 + GameState.max_ink_bonus()
	_player.restore_ink(10.0)
	_hud.toast("Rank %d! The ink bottle grows." % r)
	Telemetry.log_event("rank", {"r": r})

## Overworld levels remember which crystals were taken.
func _crystal_collected(_c: Node2D) -> void:
	pass

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
	e.died.connect(func(en: Enemy):
		GameState.add_renown(EnemyKinds.renown_value(en.kind))
		drop_crystals(en.position, 1 if en.kind == Enemy.Kind.MITE else 2)
		_award_drops(DropTables.roll_mob(String(Enemy.Kind.keys()[en.kind]).to_lower())))
	e.proofread.connect(_on_proofread)
	return e

## Gives the result of a DropTables roll (kills and bosses), with one toast per item.
func _award_drops(drops: Array) -> void:
	for d: Array in drops:
		_give_item(String(d[0]), int(d[1]))

## Extra boss loot, rolled every time the boss is beaten (chances scale with difficulty).
func award_boss_drops(boss_id: String) -> void:
	var drops := DropTables.roll_boss(boss_id)
	_award_drops(drops)
	Telemetry.log_event("boss_drops", {"boss": boss_id, "drops": drops.map(func(d): return d[0])})

## Pays out a reward string: "mnemo:N", "item:id" or "item:id:N" (chests, vaults, bosses).
func _grant_reward(reward: String) -> void:
	var parts := reward.split(":")
	if parts[0] == "mnemo":
		GameState.add_mnemosynth(int(parts[1]))
		_hud.toast("Found %d Mnemosynth" % int(parts[1]))
	else:
		var n := int(parts[2]) if parts.size() > 2 else 1
		_give_item(parts[1], n)
		_hud.toast("Found: %s%s" % [ItemDB.info(parts[1])["name"], (" x%d" % n) if n > 1 else ""])

# --- Vault Trials (overworld vaults and dungeon vaults share this) ---------------------------
var _trial: VaultTrial

## Opens a word-game trial; returns true if it was won.
func _run_trial(id: String, cell: Vector2i, tier: int) -> bool:
	if _trial != null and _trial.is_open():
		return false
	if _trial == null:
		_trial = VaultTrial.new()
		add_child(_trial)
	var seed_v := cell.x * 7919 + cell.y * 104729 + tier
	TrialGames.pad_mode = not Input.get_connected_joypads().is_empty()
	var kind := TrialGames.pick(tier, seed_v, Input.get_connected_joypads().is_empty())
	var g := TrialGames.make(kind, tier, seed_v + int(Time.get_ticks_msec() % 9973))
	_trial.open(g)
	var won: bool = await _trial.finished
	Telemetry.log_event("trial", {"id": id, "kind": kind, "tier": tier, "won": won})
	if not won:
		_hud.toast("The words slip away. Try again whenever you like.")
	return won

# --- Dungeon extras: every memory has a lantern post and a vault chest, like the overworld ---------
## Override: [{"kind": "post" | "vault", "cell": Vector2i, "tier": int}]
func _dungeon_extras() -> Array:
	return []

func _place_dungeon_extras() -> void:
	for e: Dictionary in _dungeon_extras():
		var cell: Vector2i = e["cell"]
		if not _floor.cells.has(cell):
			push_warning("dungeon extra off the map: %s" % cell)
			continue
		match String(e["kind"]):
			"post": _dungeon_post(cell)
			"vault": _dungeon_vault(cell, int(e.get("tier", 2)))
			"mob": _add_enemy(int(e.get("mob", Enemy.Kind.BARE)), cell)

func _dungeon_post(cell: Vector2i) -> void:
	var lit := GameState.has_flag(_post_flag(cell))
	var post := _add_prop(Prop.Kind.POST, cell, false, 1 if lit else 0)
	_floor.blockers[cell] = true
	_dpost_list.append({"cell": cell, "name": _room_name(cell)})
	_register(post, func(): return "Rest at the post" if GameState.has_flag(_post_flag(cell)) else "Light the post", func():
		GameState.dungeon_last_post[_scene_key()] = [cell.x, cell.y]
		if not GameState.has_flag(_post_flag(cell)):
			GameState.set_flag(_post_flag(cell))
			post.variant = 1
			post.queue_redraw()
			_hud.toast("The post is lit. You can travel back to it from the pause menu.")
		_player.restore_ink(100.0)
		_player.refuel(100.0)
		GameState.save_game()
		_hud.toast("You rest by the lantern.")
		_index.open_hub(true), 100.0)

func _post_flag(cell: Vector2i) -> String:
	return "dpost_%s_%d_%d" % [_scene_key(), cell.x, cell.y]

func _scene_key() -> String:
	return scene_file_path.get_file().get_basename()

## Where you wake after crumpling. Outside: the overworld's own rule (_checkpoint_for). In a dungeon: the post
## you last lit or rested at in it, or else the beginning of the dungeon.
func _death_spawn(cell: Vector2i) -> Vector2:
	if not dungeon_menu:
		return _checkpoint_for(cell)
	var lp = GameState.dungeon_last_post.get(_scene_key())
	if lp is Array and lp.size() == 2:
		var pc := Vector2i(int(lp[0]), int(lp[1]))
		for p: Dictionary in _dpost_list:
			if p["cell"] == pc and GameState.has_flag(_post_flag(pc)):
				return Iso.to_screen(Vector2(_beside(pc)))
	return _map_start if _map_start != Vector2.ZERO else _start

# --- Inside a dungeon: travel between lanterns, or start again -------------------------------------------
## Where "Travel to a lantern" can take you: every post here that you have lit. (The way back to the entrance is
## Restart, or crumpling before you have lit a post.)
func travel_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _dpost_list.size():
		var p: Dictionary = _dpost_list[i]
		if GameState.has_flag(_post_flag(p["cell"])):
			out.append({"id": "post%d" % i, "label": "Lantern: %s" % String(p["name"])})
	return out

## Non-empty when travel is not allowed right now (for example in the middle of a boss fight).
func travel_blocked() -> String:
	return ""

func dungeon_travel(id: String) -> void:
	if _busy or _player.is_falling or _player.is_crumpled or travel_blocked() != "":
		return
	if not id.begins_with("post"):
		return
	var i := int(id.substr(4))
	if i < 0 or i >= _dpost_list.size() or not GameState.has_flag(_post_flag(_dpost_list[i]["cell"])):
		return
	var dest := Iso.to_screen(Vector2(_beside(_dpost_list[i]["cell"])))
	GameState.dungeon_last_post[_scene_key()] = [_dpost_list[i]["cell"].x, _dpost_list[i]["cell"].y]
	_player.respawn_at(dest)
	_safe_pos = dest
	_camera.reset_smoothing()
	Telemetry.log_event("travel", {"to": id})
	_hud.toast("You follow the lantern light.")

## A walkable cell next to `cell` (posts block their own cell).
func _beside(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var c: Vector2i = cell + d
		if _floor.cells.has(c) and not _floor.blockers.has(c) and not _floor.is_pit(c) and _floor.level(c) == _floor.level(cell):
			return c
	return cell

## Starts this dungeon over from the entrance: the scene is loaded fresh, so every puzzle resets.
func restart_dungeon() -> void:
	if not dungeon_menu or scene_file_path == "":
		return
	Telemetry.log_event("restart", {"scene": scene_file_path.get_file()})
	_clear_echoes()
	Transition.go(scene_file_path)

func _dungeon_vault(cell: Vector2i, tier: int) -> void:
	var key := "vault_%s_%d_%d" % [String(name), cell.x, cell.y]
	var chest := _add_prop(Prop.Kind.CHEST, cell, false, 1 if GameState.has_flag(key) else 0)
	_floor.blockers[cell] = true
	_register(chest, func(): return "" if GameState.has_flag(key) else ("Word trial: open the locked chest  " + "★".repeat(tier)), func():
		if GameState.has_flag(key):
			return
		if not await _run_trial(key, cell, tier):
			return
		GameState.set_flag(key)
		GameState.add_renown(4 + 4 * tier)
		chest.variant = 1
		_grant_reward(TrialPrizes.roll(tier, cell))
		_hud.narrate(Story.CHEST_LINES[randi() % Story.CHEST_LINES.size()], false, 4.0), 90.0)

func _on_proofread(e: Enemy) -> void:
	drop_crystals(e.position, 6)
	Telemetry.log_event("proofread")
	if GameState.is_story() or randf() < 0.6:
		_give_item("ink_vial")
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
	# Drop interactables whose nodes were freed (picked-up items, spent stones).
	_interactables = _interactables.filter(func(d): return is_instance_valid(d["node"]))
	for it in _interactables:
		var n: Node2D = it["node"]
		if not n.is_inside_tree():
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

# --- Echoes: Garrick's memory verb ----------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if echo_enabled and event.is_action_pressed("echo") and not get_tree().paused and not GameState.in_dialogue and not _busy \
			and not _player.is_falling and not _player.is_crumpled:
		_toggle_echo()

func _toggle_echo() -> void:
	if is_instance_valid(_recording):
		_recording.stop_record()
		return
	while _echoes.size() >= GameState.echo_capacity():
		var old: Echo = _echoes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var e := Echo.new()
	e.floor_ref = _floor
	e.player = _player
	_actors.add_child(e)
	_recording = e
	e.recorded.connect(_on_echo_recorded)
	e.discarded.connect(func(_x): _recording = null)
	_hud.toast("Remembering... walk, then press {echo} again.")
	Telemetry.log_event("puzzle", {"p": "echo_start"})

func _on_echo_recorded(e: Echo) -> void:
	_recording = null
	_echoes.append(e)
	_hud.toast("Remembered. It will play it back, and stay.")
	Telemetry.log_event("puzzle", {"p": "echo_set", "n": _echoes.size()})

func _clear_echoes() -> void:
	for e in _echoes:
		if is_instance_valid(e):
			e.queue_free()
	_echoes.clear()
	if is_instance_valid(_recording):
		_recording.queue_free()
	_recording = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_report"):
		Telemetry.flush()
		_hud.toast("Playtest report saved: %s" % Telemetry.report_path() if Telemetry.enabled else "Playtest log is disabled")
		return
	if event.is_action_pressed("debug_reset"):
		GameState.reset_all()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event.is_action_pressed("ui_cancel") and not GameState.in_dialogue and not _inventory.is_open() and not _index.is_open() and not _pause.is_open():
		_pause.open()
		return
	if event.is_action_pressed("map") and not GameState.in_dialogue and not _inventory.is_open() and not _index.is_open() and not _pause.is_open() and not _world_map.is_open():
		_open_map()
		return
	if event.is_action_pressed("inventory") and not _busy and not GameState.in_dialogue and not _player.is_falling:
		_inventory.open()
		return
	if event.is_action_pressed("use_item"):
		use_item(GameState.quick_slot)
		return
	if event.is_action_pressed("quick_switch") and not GameState.in_dialogue:
		GameState.switch_quick()
		return
	if not event.is_action_pressed("interact") or _busy or GameState.in_dialogue:
		return
	var it := _nearest()
	if it.is_empty():
		return
	_busy = true
	await it["action"].call()
	_busy = false

# --- The map ---------------------------------------------------------------------------
## Cached ground: only for levels whose ground never changes (the overworld). It is a pure speed-up.
func _setup_chunks() -> void:
	var want := _floor.static_world and Settings.gfx_on("cached_ground")
	if want and _chunks == null:
		_chunks = GroundChunks.new()
		add_child(_chunks)
		_chunks.setup(_floor)
		_floor.set_chunks(true)
	elif not want and _chunks != null:
		_chunks.queue_free()
		_chunks = null
		_floor.set_chunks(false)

## Changes what a cell is while the level runs (a bridge unrolls, a causeway page crumbles), and repaints
## the ground that shows it.
func set_cell_kind(cell: Vector2i, kind: String) -> void:
	_floor.cells[cell] = kind
	_floor.dirty = true
	if _chunks != null:
		_chunks.repaint_cell(cell)

## Levels that have a world to look at override this (the overworld does).
func _map_available() -> bool:
	return false

func _open_map() -> void:
	if _pause.is_open():
		_pause.close()
	if not _map_available():
		_hud.toast("The map only unfolds out in the world.")
		return
	_world_map.open(_floor.cell_at(_player.position))

func _on_travel_requested(_id: String) -> void:
	pass

# --- Dialogue plumbing ----------------------------------------------------------------
func _say(lines: Array) -> void:
	await _dialogue.play(lines, _handle_cue)

# --- Falling / crumpling ----------------------------------------------------------------
func _on_player_fell() -> void:
	_player.take_damage(GameState.fall_damage(), false, "fall")
	Telemetry.log_event("fall")
	_player.respawn_at(_safe_pos)
	if not _fell_once:
		_fell_once = true
		_hud.narrate(Story.FALL_FIRST, false, 4.0)

func _on_player_crumpled() -> void:
	var cell := _floor.cell_at(_player.position)
	Telemetry.log_event("death", {"room": _room_name(cell), "ink_lost": 0})
	_hud.narrate(Story.CRUMPLED, false, 4.0)
	var where := _player.position
	await get_tree().create_timer(2.2).timeout
	if GameState.is_story():
		# Story mode: stand right back up where it is safe, no penalty.
		_player.restore_ink(GameState.crumple_ink())
		_player.respawn_at(_safe_pos)
		return
	# Normal: the page is crumpled. You lose some Mnemosynth (left where you fell) and
	# start the current room again.
	var lost := (int(GameState.mnemosynth * 0.15) / 5) * 5
	if lost > 0:
		GameState.mnemosynth -= lost
		GameState.mnemosynth_changed.emit(GameState.mnemosynth)
		drop_crystals(where, lost / 5)
		_hud.toast("You lost %d Mnemosynth. It lies where you fell." % lost)
	_player.restore_ink(GameState.crumple_ink())
	var cp := _death_spawn(cell)
	_player.respawn_at(cp)
	_safe_pos = cp
	_on_death_reset()
