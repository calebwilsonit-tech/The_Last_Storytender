class_name SettingsPanel
extends Control
## The Settings page, shared by the title screen and the pause menu.
## Up/Down (W/S) pick a row; Left/Right (A/D) adjust it; Enter toggles; Esc goes back.

signal closed

var _row := 0
var _font: Font
var _ital: Font
var _bar_rects: Array[Rect2] = []
var _rows := ["volume", "fullscreen", "graphics", "shake", "dialogue", "tips", "log", "controls", "difficulty", "back"]
var _controls: ControlsPanel
var _graphics: GraphicsPanel

const PANEL := Rect2(310, 80, 660, 560)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.get_default_theme().default_font
	_ital = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	_controls = ControlsPanel.new()
	add_child(_controls)
	_controls.closed.connect(queue_redraw)
	_graphics = GraphicsPanel.new()
	add_child(_graphics)
	_graphics.closed.connect(queue_redraw)

func open() -> void:
	_row = 0
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	Settings.save_settings()
	closed.emit()

func _row_y(i: int) -> float:
	var extra := 22.0 if _rows[i] == "back" else 0.0   # a little air before Back
	return PANEL.position.y + 124.0 + i * 42.0 + extra

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _controls.visible or _graphics.visible:
		return
	if MenuInput.back(event):
		get_viewport().set_input_as_handled()
		close()
		return
	var d := MenuInput.nav(event)
	if d.y != 0:
		_row = (_row + d.y + _rows.size()) % _rows.size()
		queue_redraw()
	elif d.x != 0:
		_adjust(d.x)
	elif MenuInput.accept(event):
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()

func _adjust(dir: int) -> void:
	match _rows[_row]:
		"volume":
			Settings.master_volume = clampf(Settings.master_volume + dir * 0.1, 0.0, 1.0)
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
		"shake":
			Settings.screen_shake = not Settings.screen_shake
		"dialogue":
			Settings.dialogue_speed = clampi(Settings.dialogue_speed + dir, 0, 2)
		"log":
			Settings.playtest_log = not Settings.playtest_log
		"tips":
			Settings.tutorial_tips = not Settings.tutorial_tips
	Settings.apply()
	queue_redraw()

func _activate() -> void:
	match _rows[_row]:
		"back":
			close()
		"controls":
			_controls.open()
		"dialogue":
			Settings.dialogue_speed = (Settings.dialogue_speed + 1) % 3
			Settings.apply()
		"graphics":
			_graphics.open()
		"volume", "difficulty":
			pass
		_:
			_adjust(1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _rows.size():
			if absf(event.position.y - (_row_y(i) - 10.0)) < 26.0 and event.position.x > PANEL.position.x and event.position.x < PANEL.end.x:
				if _row != i:
					_row = i
					queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _rows.size():
			if absf(event.position.y - (_row_y(i) - 10.0)) < 26.0 and event.position.x > PANEL.position.x and event.position.x < PANEL.end.x:
				_row = i
				if _rows[i] == "volume":
					var bar := Rect2(740, _row_y(i) - 18.0, 160, 22)
					Settings.master_volume = clampf((event.position.x - bar.position.x) / bar.size.x, 0.0, 1.0)
					Settings.apply()
				else:
					_activate()
				queue_redraw()

func _toggle_text(on: bool) -> String:
	return "ON" if on else "OFF"

func _draw() -> void:
	_draw_body()
	MenuLegend.draw(self, [["move","move","Move"], ["t:A D","t:◄ ►","Change"], ["back","back","Back"]])

func _draw_body() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_LIGHT
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	draw_style_box(sb, PANEL)
	draw_string(_font, PANEL.position + Vector2(40, 66), "Settings", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44, Palette.INK)
	draw_line(PANEL.position + Vector2(40, 80), PANEL.position + Vector2(PANEL.size.x - 40, 80), Color(Palette.INK, 0.5), 2.0)
	for i in _rows.size():
		_draw_row(i)

func _draw_row(i: int) -> void:
	var id: String = _rows[i]
	var y := _row_y(i)
	var sel := i == _row
	var x0 := PANEL.position.x + 40.0
	if sel:
		draw_rect(Rect2(x0 - 14.0, y - 34.0, PANEL.size.x - 52.0, 48.0), Color(Palette.GOLD, 0.22))
		draw_circle(Vector2(x0 - 4.0, y - 10.0), 5.0, Palette.GOLD)
	var label := ""
	match id:
		"volume": label = "Master volume"
		"fullscreen": label = "Fullscreen"
		"shake": label = "Screen shake"
		"dialogue": label = "Dialogue speed"
		"graphics": label = "Graphics (for slower computers)"
		"tips": label = "Tutorial tips"
		"log": label = "Playtest log (F10 saves a report)"
		"controls": label = "Controls (keyboard, mouse, controller)"
		"difficulty": label = "Difficulty"
		"back": label = "Back"
	draw_string(_font, Vector2(x0 + 12.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Palette.INK)
	var vx := 740.0
	match id:
		"volume":
			var bar := Rect2(vx, y - 18.0, 160, 22)
			draw_rect(bar, Color(0, 0, 0, 0.15))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * Settings.master_volume, bar.size.y)), Palette.CYAN_DEEP)
			draw_rect(bar, Palette.INK, false, 2.0)
			draw_string(_font, Vector2(vx + 170.0, y), "%d%%" % int(round(Settings.master_volume * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK)
		"fullscreen":
			_pill(vx, y, _toggle_text(Settings.fullscreen), Settings.fullscreen)
		"shake":
			_pill(vx, y, _toggle_text(Settings.screen_shake), Settings.screen_shake)
		"log":
			_pill(vx, y, _toggle_text(Settings.playtest_log), Settings.playtest_log)
		"tips":
			_pill(vx, y, _toggle_text(Settings.tutorial_tips), Settings.tutorial_tips)
		"graphics":
			draw_string(_font, Vector2(vx, y), "%s  ▸" % Settings.PRESET_NAMES[clampi(Settings.preset, 0, 3)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK_BROWN)
		"controls":
			draw_string(_font, Vector2(vx, y), "Open  ▸", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK_BROWN)
		"dialogue":
			var names := ["Slow", "Normal", "Fast"]
			draw_string(_font, Vector2(vx, y), "◂  %s  ▸" % names[Settings.dialogue_speed], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK)
		"difficulty":
			draw_string(_font, Vector2(vx, y), "Story" if GameState.is_story() else "Normal", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Palette.INK_BROWN)
			draw_string(_ital, Vector2(x0 + 12.0, y + 22.0), "Chosen when you start a New Game, and fixed for that save.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(Palette.INK, 0.6))

func _pill(x: float, y: float, text: String, on: bool) -> void:
	var r := Rect2(x, y - 22.0, 78, 30)
	draw_rect(r, Palette.GRASS_DARK if on else Color(Palette.INK, 0.25))
	draw_rect(r, Palette.INK, false, 2.0)
	draw_string(_font, Vector2(x + 14.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.PAPER_LIGHT)
