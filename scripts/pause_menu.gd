class_name PauseMenu
extends CanvasLayer
## Esc in game: Resume, Settings, Save and return to the title, Quit. Inside a dungeon it also offers
## "Travel to a lantern" (the entrance and any post you have rested at) and "Restart this dungeon".

signal map_requested
signal restart_requested
signal travel_requested(id: String)

var level: LevelBase          # the level that owns this menu (asked for travel points)
var _menu: MenuColumn
var _settings: SettingsPanel
var _view: Control
var _mode := "main"           # main | travel | restart
var _note := ""

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
	_menu.position = Vector2(450, 222)
	_menu.item_size = Vector2(380, 50)
	_menu.gap = 8.0
	_menu.font_size = 26
	_view.add_child(_menu)
	_show_main()
	_menu.chosen.connect(_on_chosen)
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.closed.connect(func(): _view.show())

func _paint() -> void:
	_paint_body()
	MenuLegend.draw(_view, [["move","move","Move"], ["confirm","confirm","Select"], ["back","back","Resume"]])

func _paint_body() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.6))
	var font := ThemeDB.get_default_theme().default_font
	var title: String = {"main": "Paused", "travel": "Travel by lantern", "restart": "Start this place again?"}[_mode]
	_view.draw_string(font, Vector2(450, 196), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 56 if _mode == "main" else 44, Palette.PAPER_LIGHT)
	if _note != "":
		_view.draw_multiline_string(font, Vector2(450, 222), _note, HORIZONTAL_ALIGNMENT_LEFT, 560.0, 17, 3, Color(Palette.PAPER_LIGHT, 0.8))

func _in_dungeon() -> bool:
	return level != null and is_instance_valid(level) and level.dungeon_menu

func _show_main() -> void:
	_mode = "main"
	_note = ""
	var list: Array[Dictionary] = [{"id": "resume", "label": "Resume"}]
	if _in_dungeon():
		list.append({"id": "travel", "label": "Travel to a lantern"})
		list.append({"id": "restart", "label": "Restart this dungeon"})
	list.append({"id": "map", "label": "Map"})
	list.append({"id": "settings", "label": "Settings"})
	list.append({"id": "title", "label": "Save and return to title"})
	list.append({"id": "quit", "label": "Quit game"})
	_menu.position.y = 222
	_menu.set_items(list)
	_view.queue_redraw()

func _show_travel() -> void:
	_mode = "travel"
	var blocked: String = level.travel_blocked()
	var list: Array[Dictionary] = []
	if blocked != "":
		_note = blocked
	else:
		_note = "Lanterns you have rested at in here, and the way you came in."
		for p: Dictionary in level.travel_points():
			list.append({"id": "go:" + String(p["id"]), "label": String(p["label"])})
	list.append({"id": "back", "label": "Back"})
	_menu.position.y = 276
	_menu.set_items(list)
	_view.queue_redraw()

func _show_restart() -> void:
	_mode = "restart"
	_note = "You go back to the entrance and every puzzle in here resets: gates, plates, echoes and anything you were carrying for the doors. Rewards you already took are still yours."
	var list: Array[Dictionary] = [{"id": "restart_yes", "label": "Yes, start again"}, {"id": "back", "label": "No, keep going"}]
	_menu.position.y = 300
	_menu.set_items(list)
	_view.queue_redraw()

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_view.show()
	_show_main()
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _settings.visible and MenuInput.back(event):
		get_viewport().set_input_as_handled()
		if _mode != "main":
			_show_main()
		else:
			close()

func _on_chosen(id: String) -> void:
	if id.begins_with("go:"):
		close()
		travel_requested.emit(id.substr(3))
		return
	match id:
		"resume":
			close()
		"travel":
			_show_travel()
		"restart":
			_show_restart()
		"back":
			_show_main()
		"restart_yes":
			close()
			restart_requested.emit()
		"map":
			map_requested.emit()
		"settings":
			_view.hide()
			_settings.open()
		"title":
			GameState.prepare_exit()
			GameState.save_game()
			Telemetry.flush()
			close()
			Transition.go("res://scenes/title.tscn")
		"quit":
			GameState.prepare_exit()
			GameState.save_game()
			Telemetry.flush()
			get_tree().quit()
