extends Node2D
## Phase 1 sandbox: parchment world + Storytender + ink bottle HUD.
## Everything is built in code so the scene stays trivial to merge/edit.

const PARCHMENT_SHADER := preload("res://shaders/parchment.gdshader")

var _paper: ColorRect
var _camera: Camera2D
var _player: Player

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

	_player = Player.new()
	add_child(_player)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	cs.shape = circle
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

func _process(_delta: float) -> void:
	var size := get_viewport_rect().size
	var mat := _paper.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", size)
	mat.set_shader_parameter("scroll", _camera.get_screen_center_position() - size * 0.5)
