class_name MenuColumn
extends Control
## A vertical list of parchment buttons with keyboard (WASD / arrows), mouse and
## gamepad support. Items: {"id": String, "label": String, "desc": String (optional),
## "enabled": bool (optional)}. Emits `chosen(id)`.

signal chosen(id: String)

var items: Array[Dictionary] = []
var selected := 0
var item_size := Vector2(380, 64)
var gap := 14.0
var font_size := 30
var _font: Font
var _ital: Font
var _hover := -1
var _rects: Array[Rect2] = []
var desc_height := 92.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.get_default_theme().default_font
	_ital = load("res://assets/fonts/IMFellEnglish-Italic.ttf")

func set_items(list: Array[Dictionary]) -> void:
	items = list
	selected = 0
	while selected < items.size() - 1 and not items[selected].get("enabled", true):
		selected += 1
	_rects.clear()
	var y := 0.0
	for it in items:
		var h: float = desc_height if it.get("desc", "") != "" else item_size.y
		_rects.append(Rect2(Vector2(0, y), Vector2(item_size.x, h)))
		y += h + gap
	size = Vector2(item_size.x, y)
	queue_redraw()

func _rect(i: int) -> Rect2:
	return _rects[i]

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or items.is_empty():
		return
	var d := MenuInput.nav(event)
	if d.y != 0:
		_step(d.y)
		get_viewport().set_input_as_handled()
	elif MenuInput.accept(event):
		_choose(selected)
		get_viewport().set_input_as_handled()

func _step(dir: int) -> void:
	var n := items.size()
	for k in n:
		selected = (selected + dir + n) % n
		if items[selected].get("enabled", true):
			break
	queue_redraw()

func _choose(i: int) -> void:
	if i >= 0 and i < items.size() and items[i].get("enabled", true):
		chosen.emit(items[i]["id"])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := -1
		for i in items.size():
			if _rect(i).has_point(event.position):
				h = i
		if h != _hover:
			_hover = h
			if h >= 0 and items[h].get("enabled", true):
				selected = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in items.size():
			if _rect(i).has_point(event.position):
				selected = i
				_choose(i)

func _draw() -> void:
	for i in items.size():
		var it := items[i]
		var r := _rect(i)
		var on: bool = it.get("enabled", true)
		var sel := i == selected
		if sel:
			r.position.x += 10.0
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.22))
		draw_rect(r, Palette.PAPER_LIGHT if on else Color(Palette.PAPER_LIGHT, 0.55))
		draw_rect(r, Palette.INK_BROWN if sel else Color(Palette.INK_BROWN, 0.6), false, 4.0 if sel else 2.2)
		var col := Palette.INK if on else Color(Palette.INK, 0.4)
		var has_desc: bool = it.get("desc", "") != ""
		var base_y := r.position.y + (32.0 if has_desc else r.size.y * 0.5 + 10.0)
		draw_string(_font, Vector2(r.position.x + 20, base_y), it["label"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, col)
		if has_desc:
			draw_multiline_string(_ital, Vector2(r.position.x + 20, base_y + 24.0), it["desc"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 17, 2, Color(Palette.INK, 0.65 if on else 0.3))
		if sel:
			draw_circle(Vector2(r.position.x - 14.0, r.position.y + r.size.y * 0.5), 6.0, Palette.GOLD)
