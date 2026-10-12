class_name PauseMenu
extends CanvasLayer
## Esc in game: Resume, Settings, Save and return to the title, Quit.

signal map_requested

var _menu: MenuColumn
var _settings: SettingsPanel
var _view: Control

func _ready() -> void:
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view)
	_view.draw.connect(_paint)
	_menu = MenuColumn.new()
	_menu.position = Vector2(450, 250)
	_view.add_child(_menu)
	_menu.set_items([
		{"id": "resume", "label": "Resume"},
		{"id": "map", "label": "Map"},
		{"id": "settings", "label": "Settings"},
		{"id": "title", "label": "Save and return to title"},
		{"id": "quit", "label": "Quit game"},
	])
	_menu.chosen.connect(_on_chosen)
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.closed.connect(func(): _view.show())

func _paint() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.6))
	var font := ThemeDB.get_default_theme().default_font
	_view.draw_string(font, Vector2(480, 200), "Paused", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 64, Palette.PAPER_LIGHT)

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_view.show()
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _settings.visible and MenuInput.back(event):
		get_viewport().set_input_as_handled()
		close()

func _on_chosen(id: String) -> void:
	match id:
		"resume":
			close()
		"map":
			map_requested.emit()
		"settings":
			_view.hide()
			_settings.open()
		"title":
			GameState.save_game()
			Telemetry.flush()
			close()
			Transition.go("res://scenes/title.tscn")
		"quit":
			GameState.save_game()
			Telemetry.flush()
			get_tree().quit()
