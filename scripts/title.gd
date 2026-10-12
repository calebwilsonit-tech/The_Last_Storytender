extends Node2D
## The title screen: Continue / New Game / Settings / Quit. New Game asks for a
## difficulty, which is then fixed for that save.

const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro_book.tscn"
const PARCHMENT := preload("res://shaders/parchment.gdshader")

var _menu: MenuColumn
var _settings: SettingsPanel
var _view: Control
var _mode := "main"
var _t := 0.0
var _doll: Player

func _ready() -> void:
	Music.play("title")
	get_tree().paused = false
	GameState.in_dialogue = false
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var paper := ColorRect.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = PARCHMENT
	mat.set_shader_parameter("screen_size", Vector2(1280, 720))
	mat.set_shader_parameter("vignette", 0.6)
	paper.material = mat
	bg.add_child(paper)
	# The Storytender, lantern lit, waiting.
	_doll = Player.new()
	_doll.preview = true
	_doll.position = Vector2(320, 668)
	_doll.scale = Vector2(4.2, 4.2)
	add_child(_doll)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_view)
	_view.draw.connect(_paint)
	_menu = MenuColumn.new()
	_menu.position = Vector2(770, 300)
	_menu.item_size = Vector2(440, 64)
	_view.add_child(_menu)
	_menu.chosen.connect(_on_chosen)
	_settings = SettingsPanel.new()
	ui.add_child(_settings)
	_settings.closed.connect(func(): _view.show(); _menu.show())
	_show_main()

func _process(delta: float) -> void:
	_t += delta
	_view.queue_redraw()

func _has_save() -> bool:
	return FileAccess.file_exists(GameState.SAVE_PATH)

func _show_main() -> void:
	_mode = "main"
	_menu.set_items([
		{"id": "continue", "label": "Continue", "enabled": _has_save()},
		{"id": "new", "label": "New Game"},
		{"id": "settings", "label": "Settings"},
		{"id": "quit", "label": "Quit"},
	])

func _show_confirm() -> void:
	_mode = "confirm"
	_menu.set_items([
		{"id": "confirm_new", "label": "Yes, begin again", "desc": "Your current save will be erased."},
		{"id": "back", "label": "Cancel"},
	])

func _show_difficulty() -> void:
	_mode = "difficulty"
	_menu.set_items([
		{"id": "story", "label": "Story", "desc": "Gentler. Enemies hit softer; crumpling costs nothing."},
		{"id": "normal", "label": "Normal", "desc": "The intended game. Crumpling costs Mnemosynth and restarts the room."},
		{"id": "back", "label": "Back"},
	])

func _on_chosen(id: String) -> void:
	match id:
		"continue":
			Transition.go(GAME_SCENE)
		"new":
			if _has_save():
				_show_confirm()
			else:
				_show_difficulty()
		"confirm_new":
			_show_difficulty()
		"story", "normal":
			GameState.new_game(id)
			Transition.go(INTRO_SCENE, Color("14111a"))
		"back":
			_show_main()
		"settings":
			_view.hide()
			_menu.hide()
			_settings.open()
		"quit":
			get_tree().quit()

func _paint() -> void:
	_paint_body()
	MenuLegend.draw(_view, [["move","move","Move"], ["confirm","confirm","Select"]])

func _paint_body() -> void:
	var font := ThemeDB.get_default_theme().default_font
	var ital := load("res://assets/fonts/IMFellEnglish-Italic.ttf") as Font
	var ink := Palette.INK
	# Title.
	_view.draw_string(font, Vector2(103, 163), "The Last", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 76, Color(0, 0, 0, 0.25))
	_view.draw_string(font, Vector2(100, 160), "The Last", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 76, ink)
	_view.draw_string(font, Vector2(103, 263), "Storytender", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 120, Color(0, 0, 0, 0.25))
	_view.draw_string(font, Vector2(100, 260), "Storytender", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 120, ink)
	_view.draw_line(Vector2(100, 285), Vector2(760, 285), Color(ink, 0.5), 3.0)
	_view.draw_string(ital, Vector2(104, 322), "The world is not ending; it is being edited.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.INK_BROWN)
	# Mode header.
	match _mode:
		"confirm":
			_view.draw_string(font, Vector2(770, 262), "Begin a new story?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, ink)
		"difficulty":
			_view.draw_string(font, Vector2(770, 240), "How should the story treat you?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, ink)
			_view.draw_string(ital, Vector2(770, 268), "This is fixed for the save you are about to begin.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Palette.INK_BROWN)
	# Lantern motes drifting up beside the Storytender.
	for i in 6:
		var ph := fmod(_t * 0.25 + i * 0.17, 1.0)
		_view.draw_circle(Vector2(360 + i * 16.0 + sin(_t + i) * 8.0, 560 - ph * 260.0), 2.4, Color(Palette.CYAN, (1.0 - ph) * 0.8))
