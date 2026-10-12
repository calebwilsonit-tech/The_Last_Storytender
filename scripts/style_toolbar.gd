class_name StyleToolbar
extends Control
## A word-processor style toolbar for the Quill's Format mark: [U] [B] [I].
## Keys 1 / 2 / 3 choose the style; then strike a block of text with the Quill.

var current := "underline"
var _font: Font

func _init() -> void:
	custom_minimum_size = Vector2(190, 56)

func _ready() -> void:
	InputSetup.device_changed.connect(func(_d): queue_redraw())
	InputSetup.bindings_changed.connect(queue_redraw)
	_font = ThemeDB.get_default_theme().default_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_style(s: String) -> void:
	current = s
	queue_redraw()

func _draw() -> void:
	var styles := [["underline", "U", "1"], ["bold", "B", "2"], ["italic", "I", "3"]]
	for i in 3:
		var r := Rect2(i * 62.0, 0, 56, 56)
		var sel: bool = current == styles[i][0]
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.22))
		draw_rect(r, Palette.PAPER_LIGHT if sel else Color(Palette.PAPER_LIGHT, 0.7))
		draw_rect(r, Palette.GOLD if sel else Palette.INK_BROWN, false, 4.0 if sel else 2.0)
		var glyph: String = styles[i][1]
		var col := Palette.INK
		match i:
			0:
				draw_string(_font, Vector2(r.position.x + 16, r.position.y + 36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, col)
				draw_line(Vector2(r.position.x + 14, r.position.y + 42), Vector2(r.position.x + 42, r.position.y + 42), col, 3.0)
			1:
				draw_string(_font, Vector2(r.position.x + 15, r.position.y + 37), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, col)
				draw_string(_font, Vector2(r.position.x + 16, r.position.y + 37), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, col)
			2:
				draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.35, 1), Vector2(r.position.x + 22, r.position.y + 36)))
				draw_string(_font, Vector2.ZERO, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, col)
				draw_set_transform_matrix(Transform2D.IDENTITY)
		var key_text := InputSetup.action_text("style_" + styles[i][0])
		if key_text.begins_with("D-pad"):
			key_text = {"D-pad Left": "◄", "D-pad Up": "▲", "D-pad Right": "►"}.get(key_text, key_text)
		draw_string(_font, Vector2(r.position.x + 4, r.position.y + 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(Palette.INK, 0.55))
