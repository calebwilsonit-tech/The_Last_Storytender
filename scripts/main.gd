extends Node2D
## Phase 1 sandbox: parchment world + Storytender + ink bottle HUD.
## Everything is built in code so the scene stays trivial to merge/edit.

const PARCHMENT_SHADER := preload("res://shaders/parchment.gdshader")

var _paper: ColorRect
var _camera: Camera2D
var _player: Player
var _floor: IsoFloor

func _ready() -> void:
	# Parchment background on its own canvas layer, behind the world.
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

	_floor = IsoFloor.new()
	_floor.z_index = -5
	add_child(_floor)
	_build_world()

	# Everything that must depth-sort lives under one Y-sorted node.
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)

	for cell in _block_cells:
		var b := IsoBlock.new()
		b.position = Iso.to_screen(Vector2(cell))
		b.tint = Color.from_hsv(randf_range(0.0, 0.1), 0.55, 0.6)
		b.height = randf_range(27.0, 54.0)
		actors.add_child(b)

	_player = Player.new()
	_player.position = Iso.to_screen(Vector2(20, 20))
	actors.add_child(_player)
	var cs := CollisionPolygon2D.new()
	cs.polygon = Iso.diamond(Vector2.ZERO, 0.4)  # small footprint at the feet
	_player.add_child(cs)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_player.add_child(_camera)

	# HUD
	var hud := CanvasLayer.new()
	add_child(hud)
	var bottle := InkBottle.new()
	bottle.position = Vector2(20, 16)
	hud.add_child(bottle)
	_player.ink_changed.connect(bottle.set_ink)

	var help := Label.new()
	help.text = "WASD move   SPACE take ink damage   H restore ink"
	help.position = Vector2(110, 20)
	help.add_theme_color_override("font_color", Color(0.2, 0.12, 0.08))
	hud.add_child(help)

var _block_cells: Array[Vector2i] = []

func _build_world() -> void:
	# A few void pits ("plot holes") and book-stack obstacles to test with.
	for c in [Vector2i(23, 20), Vector2i(23, 21), Vector2i(24, 21), Vector2i(16, 24), Vector2i(17, 24)]:
		_floor.pits[c] = true
		_add_wall_body(c)
	_block_cells = [Vector2i(18, 17), Vector2i(19, 17), Vector2i(26, 25), Vector2i(14, 19), Vector2i(21, 14)]
	# World boundary so the player can't leave the page.
	var lo := -0.5
	var hi := _floor.grid_size - 0.5
	for edge in [[Vector2(lo, lo), Vector2(hi, lo)], [Vector2(hi, lo), Vector2(hi, hi)],
			[Vector2(hi, hi), Vector2(lo, hi)], [Vector2(lo, hi), Vector2(lo, lo)]]:
		var body := StaticBody2D.new()
		var seg := CollisionShape2D.new()
		var shape := SegmentShape2D.new()
		shape.a = Iso.to_screen(edge[0])
		shape.b = Iso.to_screen(edge[1])
		seg.shape = shape
		body.add_child(seg)
		add_child(body)

func _add_wall_body(cell: Vector2i) -> void:
	# Pits block movement for now; falling in comes later.
	var body := StaticBody2D.new()
	var poly := CollisionPolygon2D.new()
	poly.polygon = Iso.diamond(Vector2.ZERO, 0.95)
	body.position = Iso.to_screen(Vector2(cell))
	body.add_child(poly)
	add_child(body)

func _process(_delta: float) -> void:
	_floor.focus = _player.position
	var size := get_viewport_rect().size
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", size)
	mat.set_shader_parameter("scroll", _camera.get_screen_center_position() - size * 0.5)
