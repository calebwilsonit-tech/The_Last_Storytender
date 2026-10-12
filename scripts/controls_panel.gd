class_name ControlsPanel
extends Control
## Rebind keyboard / mouse and controller inputs. Up/Down pick an action, Left/Right pick
## the Keyboard or Controller column, Interact starts listening, then press the new input
## (Esc cancels). Whatever already owned that input takes the one you gave up.

signal closed

var _row := 0
var _col := 0
var _listening := false
var _listen_t := 0.0
var _font: Font
var _head: Font
var _note := ""

const PANEL := Rect2(150, 24, 980, 672)
const X_LABEL := 190.0
const X_KB := 560.0
const X_PAD := 840.0
const Y0 := 128.0
const STEP := 28.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Italic.ttf")

func _rows() -> int:
	return InputSetup.DEFS.size() + 2   # + Reset, Back

func open() -> void:
	_row = 0
	_col = 0
	_listening = false
	_note = ""
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	_listening = false
	closed.emit()

func _row_y(i: int) -> float:
	var extra := 14.0 if i >= InputSetup.DEFS.size() else 0.0
	if i == InputSetup.DEFS.size() + 1:
		extra += 8.0
	return Y0 + i * STEP + extra

func _process(delta: float) -> void:
	if visible:
		if _listening:
			_listen_t += delta
			if _listen_t > 8.0:
				_listening = false
				_note = "Cancelled."
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening:
		_capture(event)
		return
	var handled := true
	if MenuInput.back(event):
		close()
	else:
		var d := MenuInput.nav(event)
		if d.y != 0:
			_row = (_row + d.y + _rows()) % _rows()
			_clamp_col()
		elif d.x != 0:
			_col = clampi(_col + d.x, 0, 1)
			_clamp_col()
		elif MenuInput.accept(event):
			_activate()
		else:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()   # the settings page behind must not react

func _clamp_col() -> void:
	if _row >= InputSetup.DEFS.size():
		_col = 0

func _activate() -> void:
	if _row == InputSetup.DEFS.size():
		InputSetup.reset_all()
		_note = "Everything is back to the defaults."
	elif _row == InputSetup.DEFS.size() + 1:
		close()
	else:
		var id: String = InputSetup.DEFS[_row]["id"]
		var dev := InputSetup.KB if _col == 0 else InputSetup.PAD
		if not InputSetup.is_rebindable(id, dev):
			_note = "That one is fixed (the left stick always moves)."
			return
		_listening = true
		_listen_t = 0.0
		_note = ""

func _capture(event: InputEvent) -> void:
	var dev := InputSetup.KB if _col == 0 else InputSetup.PAD
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_listening = false
		_note = "Cancelled."
		get_viewport().set_input_as_handled()
		return
	if _listen_t < 0.15:
		get_viewport().set_input_as_handled()
		return
	var spec := InputSetup.event_to_spec(event, dev)
	if spec.is_empty():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var id: String = InputSetup.DEFS[_row]["id"]
	var other := ""
	for d: Dictionary in InputSetup.DEFS:
		if d["id"] != id and InputSetup.primary(d["id"], dev) == spec:
			other = d["label"]
	InputSetup.set_binding(id, dev, spec)
	_listening = false
	_note = "Swapped with \"%s\"." % other if other != "" else "Bound."

func _gui_input(event: InputEvent) -> void:
	if _listening:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		for i in _rows():
			if absf(event.position.y - (_row_y(i) - 8.0)) < STEP * 0.5:
				var col := 0 if event.position.x < 700.0 else 1
				if i >= InputSetup.DEFS.size():
					col = 0
				if _row != i or _col != col:
					_row = i
					_col = col
					queue_redraw()
				if event is InputEventMouseButton:
					_activate()
					queue_redraw()
				break

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
	draw_string(_head, Vector2(X_LABEL, 76), "Controls", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44, Palette.INK)
	draw_string(_font, Vector2(X_KB, 104), "Keyboard & mouse", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK_BROWN)
	draw_string(_font, Vector2(X_PAD, 104), "Controller", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK_BROWN)
	draw_line(Vector2(X_LABEL, 110), Vector2(PANEL.end.x - 40.0, 110), Color(Palette.INK, 0.5), 2.0)
	for i in InputSetup.DEFS.size():
		_draw_action(i)
	_draw_button_row(InputSetup.DEFS.size(), "Reset everything to defaults")
	_draw_button_row(InputSetup.DEFS.size() + 1, "Back")
	if _note != "":
		draw_string(_head, Vector2(X_LABEL, PANEL.end.y - 12.0), _note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.7))
	elif _row < InputSetup.DEFS.size():
		draw_string(_head, Vector2(X_LABEL, PANEL.end.y - 12.0), "Fixed extras still work too: arrows, Space / Enter, mouse buttons, right trigger.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(Palette.INK, 0.5))

func _draw_button_row(i: int, text: String) -> void:
	var y := _row_y(i)
	if i == _row:
		draw_rect(Rect2(X_LABEL - 14.0, y - 22.0, PANEL.size.x - 80.0, 30.0), Color(Palette.GOLD, 0.25))
	draw_string(_font, Vector2(X_LABEL, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK)

func _draw_action(i: int) -> void:
	var d: Dictionary = InputSetup.DEFS[i]
	var y := _row_y(i)
	var sel_row := i == _row
	if sel_row:
		draw_rect(Rect2(X_LABEL - 14.0, y - 22.0, PANEL.size.x - 80.0, 28.0), Color(Palette.GOLD, 0.16))
	draw_string(_font, Vector2(X_LABEL, y), d["label"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.INK)
	for c in 2:
		var dev := InputSetup.KB if c == 0 else InputSetup.PAD
		var x := X_KB if c == 0 else X_PAD
		var cell := Rect2(x - 8.0, y - 23.0, 250.0 if c == 0 else 220.0, 28.0)
		var selected := sel_row and c == _col
		if selected:
			draw_rect(cell, Color(Palette.GOLD, 0.35))
			draw_rect(cell, Palette.GOLD.darkened(0.2), false, 2.0)
		var mid := Vector2(x, y - 9.0)
		if selected and _listening:
			var blink := 0.55 + 0.45 * sin(_listen_t * 8.0)
			draw_string(_head, Vector2(x, y), "Press a key…" if c == 0 else "Press a button…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, blink))
			continue
		var spec := InputSetup.primary(d["id"], dev)
		if spec.is_empty():
			var alt: Array = d[dev + "_alt"]
			var fixed := "Left stick" if (dev == InputSetup.PAD and not alt.is_empty()) else "—"
			draw_string(_font, Vector2(x, y), fixed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(Palette.INK, 0.45))
			continue
		var w := Glyph.draw(self, _font, spec, mid, 24.0)
		var alts: Array = d[dev + "_alt"]
		if not alts.is_empty():
			var names: Array[String] = []
			for a: Dictionary in alts:
				names.append(InputSetup.spec_text(a))
			draw_string(_font, Vector2(x + w + 10.0, y - 2.0), "also " + ", ".join(names), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(Palette.INK, 0.5))
