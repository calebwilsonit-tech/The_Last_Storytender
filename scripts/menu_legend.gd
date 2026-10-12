class_name MenuLegend
extends RefCounted
## The button legend along the bottom of every menu: "[A] Select  [B] Back ...", drawn with the
## glyphs of whichever device was used last (keyboard caps or controller buttons).
## An entry is [keyboard token, controller token, label]. Tokens: "move", "confirm", "back",
## "a:<action id>" (the bound input), "t:<text>" (a plain cap), or "" to hide it on that device.

const MOVE := ["move", "move"]
const PICK := ["confirm", "confirm"]
const BACK := ["back", "back"]

static func draw(ci: CanvasItem, entries: Array, vs: Vector2 = Vector2(1280, 720)) -> void:
	var font: Font = ThemeDB.get_default_theme().default_font
	var head: Font = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	var pad: bool = InputSetup.device == InputSetup.PAD
	var items: Array = []
	var total := 0.0
	for e: Array in entries:
		var tok: String = e[1] if pad else e[0]
		if tok == "":
			continue
		var label: String = e[2]
		var spec := _spec(tok, pad)
		var gw := _glyph_w(font, spec, pad)
		var lw := head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
		items.append({"spec": spec, "label": label, "gw": gw, "lw": lw})
		total += gw + 8.0 + lw + 26.0
	if items.is_empty():
		return
	var h := 36.0
	var bar := Rect2((vs.x - total - 20.0) * 0.5, vs.y - h - 14.0, total + 20.0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.13, 0.82)
	bg.set_corner_radius_all(int(h * 0.5))
	ci.draw_style_box(bg, bar)
	var x := bar.position.x + 18.0
	var cy := bar.position.y + h * 0.5
	for it: Dictionary in items:
		_draw_spec(ci, font, it["spec"], Vector2(x, cy), 26.0)
		x += float(it["gw"]) + 8.0
		ci.draw_string(head, Vector2(x, cy + 7.0), it["label"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("f4ecd8"))
		x += float(it["lw"]) + 26.0

static func _spec(tok: String, pad: bool) -> Dictionary:
	if tok == "move":
		return {"t": "text", "s": "D-pad / Stick" if pad else "W A S D"}
	if tok == "confirm":
		return InputSetup.display_spec("interact")
	if tok == "back":
		return InputSetup.B(JOY_BUTTON_B) if pad else InputSetup.K(KEY_ESCAPE)
	if tok.begins_with("a:"):
		return InputSetup.display_spec(tok.substr(2))
	return {"t": "text", "s": tok.substr(2) if tok.begins_with("t:") else tok}

static func _glyph_w(font: Font, spec: Dictionary, _pad: bool) -> float:
	var h := 26.0
	if spec.get("t", "") == "text":
		return maxf(h, font.get_string_size(spec["s"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(h * 0.55)).x + h * 0.55)
	if spec.get("t", "") == "btn" and int(spec["b"]) <= JOY_BUTTON_Y:
		return h
	return maxf(h, font.get_string_size(InputSetup.spec_text(spec), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(h * 0.55)).x + h * 0.55)

static func _draw_spec(ci: CanvasItem, font: Font, spec: Dictionary, pos: Vector2, h: float) -> void:
	if spec.get("t", "") == "text":
		Glyph.draw_text(ci, font, spec["s"], pos, h, InputSetup.device == InputSetup.PAD)
	else:
		Glyph.draw(ci, font, spec, pos, h)
