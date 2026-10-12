class_name GraphicsPanel
extends Control
## Graphics options. Pick a preset (Low / Balanced / High) or change any single option and
## it becomes "Custom". Each option shows how much it helps a slow computer.
## Up/Down pick a row, Left/Right change it, Back closes.

signal closed

var _row := 0
var _font: Font
var _head: Font

const PANEL := Rect2(180, 24, 920, 672)
const Y0 := 150.0
const STEP := 28.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Italic.ttf")

func _count() -> int:
	return Settings.GFX.size() + 2      # preset row + options + Back

func open() -> void:
	_row = 0
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	Settings.save_settings()
	closed.emit()

func _row_y(i: int) -> float:
	var extra := 14.0 if i >= 1 else 0.0
	if i == _count() - 1:
		extra += 10.0
	return Y0 + i * STEP + extra

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.back(event):
		get_viewport().set_input_as_handled()
		close()
		return
	var d := MenuInput.nav(event)
	if d.y != 0:
		_row = (_row + d.y + _count()) % _count()
	elif d.x != 0:
		_change(d.x)
	elif MenuInput.accept(event):
		if _row == _count() - 1:
			close()
		else:
			_change(1)
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()

func _change(dir: int) -> void:
	if _row == 0:
		var cur := Settings.preset if Settings.preset < 3 else (0 if dir > 0 else 2)
		Settings.set_preset((cur + dir + 3) % 3)
	elif _row <= Settings.GFX.size():
		var opt: Dictionary = Settings.GFX[_row - 1]
		var n: int = (opt["opts"] as Array).size()
		Settings.set_gfx(opt["id"], (Settings.g(opt["id"]) + dir + n) % n)

func _gui_input(event: InputEvent) -> void:
	var hit := -1
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		for i in _count():
			if absf(event.position.y - (_row_y(i) - 8.0)) < STEP * 0.5 and event.position.x > PANEL.position.x and event.position.x < PANEL.end.x:
				hit = i
				break
	if hit >= 0:
		_row = hit
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if hit == _count() - 1:
				close()
			else:
				_change(1)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			_change(-1)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.7))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_LIGHT
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	draw_style_box(sb, PANEL)
	draw_string(_head, Vector2(220, 82), "Graphics", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44, Palette.INK)
	draw_string(_head, Vector2(220, 112), "Trade looks for speed. Each option shows how much it helps a slow computer.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(Palette.INK, 0.6))
	draw_line(Vector2(220, 124), Vector2(PANEL.end.x - 40.0, 124), Color(Palette.INK, 0.5), 2.0)
	var gpu := Settings.adapter_name()
	if gpu != "":
		draw_string(_head, Vector2(PANEL.end.x - 40.0 - 330.0, 82), "Graphics chip: %s" % gpu.left(34), HORIZONTAL_ALIGNMENT_LEFT, 330.0, 15, Color(Palette.INK, 0.5))
	for i in _count():
		var y := _row_y(i)
		if i == _row:
			draw_rect(Rect2(210.0, y - 22.0, PANEL.size.x - 60.0, 28.0), Color(Palette.GOLD, 0.25))
		if i == 0:
			draw_string(_font, Vector2(230, y), "Preset", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21, Palette.INK)
			draw_string(_font, Vector2(660, y), "◂  %s  ▸" % Settings.PRESET_NAMES[clampi(Settings.preset, 0, 3)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21, Palette.INK_BROWN)
		elif i <= Settings.GFX.size():
			var opt: Dictionary = Settings.GFX[i - 1]
			draw_string(_font, Vector2(230, y), opt["label"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK)
			var choices: Array = opt["opts"]
			draw_string(_font, Vector2(660, y), "◂  %s  ▸" % choices[Settings.g(opt["id"])], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK_BROWN)
			# how much this option matters on a slow computer
			var impact: int = opt["impact"]
			for k in 3:
				draw_circle(Vector2(560.0 + k * 16.0, y - 7.0), 5.0, Palette.GOLD.darkened(0.1) if k < impact else Color(Palette.INK, 0.18))
		else:
			draw_string(_font, Vector2(230, y), "Back", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK)
	if _row >= 1 and _row <= Settings.GFX.size():
		var o: Dictionary = Settings.GFX[_row - 1]
		draw_string(_head, Vector2(220, PANEL.end.y - 16.0), "%s  (Dots: how much it helps speed)" % o["cost"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.75))
	elif _row == 0:
		draw_string(_head, Vector2(220, PANEL.end.y - 16.0), "Low: smoothest on old computers.  Balanced: good for most laptops.  High: everything on.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.75))
