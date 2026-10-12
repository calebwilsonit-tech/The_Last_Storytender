class_name Glyph
extends RefCounted
## Draws button glyphs: key caps for keyboard and mouse, round coloured buttons for the
## controller (A/B/X/Y, or the PlayStation shapes), pills for shoulders and triggers.

const FACE := {
	"xbox": [Color("5aa85a"), Color("d2584a"), Color("4a7fc8"), Color("e0b840")],
	"ps": [Color("5b82d6"), Color("d65b6a"), Color("c878b8"), Color("4fb88a")],
	"nintendo": [Color("8c8c94"), Color("8c8c94"), Color("8c8c94"), Color("8c8c94")],
}

## Draws one glyph with its left edge at pos.x and vertical middle at pos.y. Returns its width.
static func draw(ci: CanvasItem, font: Font, spec: Dictionary, pos: Vector2, h: float = 30.0) -> float:
	var t: String = spec.get("t", "")
	if t == "btn" and int(spec["b"]) <= JOY_BUTTON_Y:
		return _face(ci, font, int(spec["b"]), pos, h)
	if t == "stick" or t == "move":
		return _cap(ci, font, "L-Stick" if InputSetup.device == InputSetup.PAD else "WASD", pos, h, true)
	var label := InputSetup.spec_text(spec)
	var pill := t == "axis" or t == "btn" or t == "mouse"
	return _cap(ci, font, label, pos, h, pill)

static func draw_text(ci: CanvasItem, font: Font, text: String, pos: Vector2, h: float = 30.0, pill: bool = false) -> float:
	return _cap(ci, font, text, pos, h, pill)

static func _cap(ci: CanvasItem, font: Font, text: String, pos: Vector2, h: float, pill: bool) -> float:
	var fs := int(h * 0.55)
	var w := maxf(h, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x + h * 0.55)
	var r := Rect2(pos.x, pos.y - h * 0.5, w, h)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(int(h * (0.5 if pill else 0.22)))
	ci.draw_style_box(shadow, Rect2(r.position + Vector2(0, 3), r.size))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4ecd8") if not pill else Color("3d4a5a")
	sb.border_color = Palette.INK_BROWN if not pill else Color("1c242e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(h * (0.5 if pill else 0.22)))
	ci.draw_style_box(sb, r)
	var col := Palette.INK if not pill else Color("f4ecd8")
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	ci.draw_string(font, Vector2(r.position.x + (w - ts.x) * 0.5, pos.y + ts.y * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
	return w

static func _face(ci: CanvasItem, font: Font, b: int, pos: Vector2, h: float) -> float:
	var style := InputSetup.pad_style()
	var c: Vector2 = pos + Vector2(h * 0.5, 0)
	var col: Color = FACE[style][b]
	ci.draw_circle(c + Vector2(0, 3), h * 0.5, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, h * 0.5, Color("2c3440"))
	ci.draw_arc(c, h * 0.5, 0.0, TAU, 24, Color("141a22"), 2.0, true)
	if style == "ps":
		var r := h * 0.2
		match b:
			0:   # cross
				ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 3.0)
				ci.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 3.0)
			1:   # circle
				ci.draw_arc(c, r * 1.1, 0.0, TAU, 20, col, 3.0, true)
			2:   # square
				ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), col, false, 3.0)
			3:   # triangle
				var tri := PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 1.1, r * 0.8), c + Vector2(-r * 1.1, r * 0.8), c + Vector2(0, -r * 1.15)])
				ci.draw_polyline(tri, col, 3.0, true)
	else:
		var letter: String = InputSetup.spec_text({"t": "btn", "b": b})
		var fs := int(h * 0.55)
		var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		ci.draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.28), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
	return h
