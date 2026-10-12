class_name PromptTag
extends Control
## The "press this to do that" chip that appears next to things you can interact with.

var _text := ""
var _font: Font
var _head: Font
var _pop := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	InputSetup.device_changed.connect(func(_d): queue_redraw())
	InputSetup.bindings_changed.connect(queue_redraw)
	visible = false

func set_text(t: String) -> void:
	if t == _text:
		return
	if _text == "" and t != "":
		_pop = 0.0
	_text = t
	visible = t != ""
	queue_redraw()

func _process(delta: float) -> void:
	if visible and _pop < 1.0:
		_pop = minf(_pop + delta / 0.18, 1.0)
		queue_redraw()

func _draw() -> void:
	if _text == "":
		return
	var h := 38.0
	var spec := InputSetup.display_spec("interact")
	var tw := _head.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x
	var gw := 40.0 if InputSetup.device == InputSetup.PAD else maxf(40.0, _font.get_string_size(InputSetup.spec_text(spec), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21).x + 22.0)
	var total := gw + 14.0 + tw + 28.0
	var s := 0.85 + 0.15 * _pop
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0.0, Vector2(s, s))
	var r := Rect2(-total * 0.5, -h * 0.5 - 6.0, total, h + 12.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.17, 0.82 * _pop)
	bg.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(bg, r)
	var gx := r.position.x + 12.0
	Glyph.draw(self, _font, spec, Vector2(gx, 0.0), h - 4.0)
	draw_string(_head, Vector2(gx + gw + 14.0, 9.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color("f4ecd8"))
