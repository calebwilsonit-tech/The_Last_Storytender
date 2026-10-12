class_name ItemIcon
extends Control
## Procedural item art. `ItemIcon.draw_item(canvas, id, center, size)` can be called
## from any CanvasItem's _draw(); the Control form is used in the HUD and binder.

var item_id := ""
var icon_size := 44.0

func _init() -> void:
	custom_minimum_size = Vector2(52, 52)

func set_item(id: String, sz: float = 44.0) -> void:
	item_id = id
	icon_size = sz
	queue_redraw()

func _draw() -> void:
	if item_id != "":
		draw_item(self, item_id, size * 0.5, icon_size)

static func _o(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.2) -> void:
	if Settings.art_style == "cel" and not Geometry2D.triangulate_polygon(pts).is_empty():
		# Ink Cel: heavy contour, one cel shadow, thin rim light
		CelKit.piece(ci, pts, fill, 0.36, true, maxf(w, 2.0) + 0.3)
		return
	ci.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Palette.OUTLINE, w, true)

static func draw_item(ci: CanvasItem, id: String, c: Vector2, sz: float) -> void:
	var u := sz / 44.0
	match id:
		"eraser_crumbs":
			# A pink eraser broken into crumbs.
			_o(ci, PackedVector2Array([c + Vector2(-14, -2) * u, c + Vector2(4, -10) * u, c + Vector2(12, 4) * u, c + Vector2(-6, 12) * u]), Color("e9a1ae"))
			_o(ci, PackedVector2Array([c + Vector2(-4, -2) * u, c + Vector2(4, -10) * u, c + Vector2(12, 4) * u, c + Vector2(4, 6) * u]), Color("f4f0e6"), 2.0)
			for p in [Vector2(-16, 12), Vector2(14, -12), Vector2(16, 12), Vector2(-4, 16)]:
				_o(ci, PackedVector2Array([c + p * u, c + (p + Vector2(5, -2)) * u, c + (p + Vector2(3, 4)) * u]), Color("e9a1ae"), 1.6)
		"warm_loaf":
			_o(ci, DrawKit.ellipse(c + Vector2(0, 2) * u, 15.0 * u, 10.0 * u, 18), Color("d09a52"))
			for i in 3:
				ci.draw_line(c + Vector2(-8 + i * 8, -5) * u, c + Vector2(-5 + i * 8, 5) * u, Color("8a5a28"), 2.0 * u)
			ci.draw_arc(c + Vector2(0, -8) * u, 7.0 * u, PI, TAU, 8, Color(1, 1, 1, 0.5), 2.0, true)
		"ink_vial":
			_o(ci, PackedVector2Array([c + Vector2(-9, -2) * u, c + Vector2(9, -2) * u, c + Vector2(11, 14) * u, c + Vector2(-11, 14) * u]), Color("1f1b3a"))
			_o(ci, PackedVector2Array([c + Vector2(-4, -12) * u, c + Vector2(4, -12) * u, c + Vector2(4, -2) * u, c + Vector2(-4, -2) * u]), Color("a7c7d6", 0.7))
			_o(ci, PackedVector2Array([c + Vector2(-5, -17) * u, c + Vector2(5, -17) * u, c + Vector2(5, -12) * u, c + Vector2(-5, -12) * u]), Palette.WOOD, 1.8)
			ci.draw_line(c + Vector2(-5, 2) * u, c + Vector2(-6, 10) * u, Color(1, 1, 1, 0.4), 2.0)
		"hardcover_binding":
			# A pauldron plate cut from a book cover, with a raised border and spine ridge.
			_o(ci, PackedVector2Array([c + Vector2(-15, -6) * u, c + Vector2(-6, -15) * u, c + Vector2(10, -15) * u, c + Vector2(16, -4) * u, c + Vector2(12, 14) * u, c + Vector2(-10, 14) * u]), Color("6b4a3a"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-11, -4) * u, c + Vector2(-4, -11) * u, c + Vector2(8, -11) * u, c + Vector2(12, -3) * u, c + Vector2(9, 10) * u, c + Vector2(-7, 10) * u, c + Vector2(-11, -4) * u]), Color("c9a24e"), 1.8)
			ci.draw_circle(c + Vector2(0, 0) * u, 3.5 * u, Color("c9a24e"))
			ci.draw_line(c + Vector2(-13, -2) * u, c + Vector2(-13, 12) * u, Color(0, 0, 0, 0.45), 2.0)
		"softcover_binding":
			# A soft leather jerkin, stitched.
			_o(ci, PackedVector2Array([c + Vector2(-14, -12) * u, c + Vector2(-5, -15) * u, c + Vector2(0, -9) * u, c + Vector2(5, -15) * u, c + Vector2(14, -12) * u, c + Vector2(12, 14) * u, c + Vector2(-12, 14) * u]), Color("a77a52"))
			for i in 6:
				ci.draw_line(c + Vector2(0, -8 + i * 4) * u, c + Vector2(0, -6 + i * 4) * u, Color("efe3c4"), 1.8)
			ci.draw_line(c + Vector2(-12, 4) * u, c + Vector2(12, 4) * u, Color(0, 0, 0, 0.35), 2.0)
		"oxford_comma":
			# A golden comma hung on a chain.
			ci.draw_arc(c + Vector2(0, -8) * u, 14.0 * u, PI * 1.15, PI * 1.85, 14, Palette.OUTLINE, 2.4, true)
			ci.draw_circle(c + Vector2(0, 2) * u, 10.0 * u, Palette.GOLD)
			ci.draw_arc(c + Vector2(0, 2) * u, 10.0 * u, 0.0, TAU, 20, Palette.OUTLINE, 2.4, true)
			_o(ci, PackedVector2Array([c + Vector2(1, 4) * u, c + Vector2(6, 8) * u, c + Vector2(4, 16) * u, c + Vector2(-1, 14) * u, c + Vector2(2, 10) * u]), Palette.OUTLINE, 1.2)
			ci.draw_circle(c + Vector2(-2, -2) * u, 2.0 * u, Palette.OUTLINE)
		"void_ink":
			_o(ci, PackedVector2Array([c + Vector2(-10, -4) * u, c + Vector2(10, -4) * u, c + Vector2(12, 14) * u, c + Vector2(-12, 14) * u]), Color("120a24"))
			_o(ci, PackedVector2Array([c + Vector2(-4, -14) * u, c + Vector2(4, -14) * u, c + Vector2(4, -4) * u, c + Vector2(-4, -4) * u]), Color("a7c7d6", 0.6))
			ci.draw_arc(c + Vector2(0, 6) * u, 5.0 * u, 0.0, TAU * 0.8, 12, Palette.GLITCH, 2.0, true)
			ci.draw_arc(c + Vector2(0, 6) * u, 2.4 * u, 1.0, TAU * 0.9, 8, Palette.GLITCH.lightened(0.3), 1.6, true)
		"torn_page":
			_o(ci, PackedVector2Array([c + Vector2(-12, -14) * u, c + Vector2(10, -16) * u, c + Vector2(13, -4) * u, c + Vector2(9, 4) * u, c + Vector2(12, 14) * u, c + Vector2(-13, 15) * u]), Color("f4ecd6"))
			for i in 4:
				ci.draw_line(c + Vector2(-8, -8 + i * 5) * u, c + Vector2(8 - i * 2, -8 + i * 5) * u, Color(Palette.INK, 0.55), 1.4)
		"thimble":
			_o(ci, PackedVector2Array([c + Vector2(-9, -2) * u, c + Vector2(-6, -12) * u, c + Vector2(6, -12) * u, c + Vector2(9, -2) * u, c + Vector2(11, 12) * u, c + Vector2(-11, 12) * u]), Color("c9ced8"))
			for i in 3:
				for j in 2:
					ci.draw_circle(c + Vector2(-5 + i * 5, -6 + j * 7) * u, 1.3 * u, Color("5a6070"))
			ci.draw_line(c + Vector2(-11, 12) * u, c + Vector2(11, 12) * u, Palette.OUTLINE, 2.4 * u)
		"bookmark":
			_o(ci, PackedVector2Array([c + Vector2(-6, -16) * u, c + Vector2(6, -16) * u, c + Vector2(6, 14) * u, c + Vector2(0, 8) * u, c + Vector2(-6, 14) * u]), Palette.CRITIC_RED.lightened(0.15))
			ci.draw_line(c + Vector2(0, -14) * u, c + Vector2(0, 4) * u, Color(1, 1, 1, 0.3), 1.6)
		"ink_flask":
			_o(ci, PackedVector2Array([c + Vector2(-5, -16) * u, c + Vector2(5, -16) * u, c + Vector2(5, -6) * u, c + Vector2(13, 8) * u, c + Vector2(10, 15) * u, c + Vector2(-10, 15) * u, c + Vector2(-13, 8) * u, c + Vector2(-5, -6) * u]), Color("1f1b3a"))
			_o(ci, PackedVector2Array([c + Vector2(-6, -19) * u, c + Vector2(6, -19) * u, c + Vector2(6, -15) * u, c + Vector2(-6, -15) * u]), Palette.WOOD, 1.8)
			ci.draw_arc(c + Vector2(0, 8) * u, 5.0 * u, PI * 0.1, PI * 0.9, 8, Palette.CYAN, 2.0, true)
			ci.draw_line(c + Vector2(-7, 4) * u, c + Vector2(-9, 11) * u, Color(1, 1, 1, 0.35), 2.0)
		"lantern_oil":
			_o(ci, PackedVector2Array([c + Vector2(-9, -6) * u, c + Vector2(9, -6) * u, c + Vector2(11, 14) * u, c + Vector2(-11, 14) * u]), Color("e2a63c"))
			_o(ci, PackedVector2Array([c + Vector2(-3, -15) * u, c + Vector2(3, -15) * u, c + Vector2(3, -6) * u, c + Vector2(-3, -6) * u]), Color("c9ced8"), 1.8)
			ci.draw_circle(c + Vector2(0, 4) * u, 4.0 * u, Color(1, 0.95, 0.7, 0.9))
			ci.draw_arc(c + Vector2(0, -16) * u, 5.0 * u, PI, TAU, 8, Palette.CYAN, 1.8, true)
		"sticky_note":
			_o(ci, PackedVector2Array([c + Vector2(-13, -13) * u, c + Vector2(13, -13) * u, c + Vector2(13, 6) * u, c + Vector2(5, 14) * u, c + Vector2(-13, 14) * u]), Color("f6e27a"))
			_o(ci, PackedVector2Array([c + Vector2(5, 14) * u, c + Vector2(13, 6) * u, c + Vector2(5, 6) * u]), Color("d8c25a"), 1.6)
			for i in 3:
				ci.draw_line(c + Vector2(-8, -6 + i * 5) * u, c + Vector2(6 - i * 3, -6 + i * 5) * u, Color(Palette.INK, 0.5), 1.4)
		"paperback_binding":
			_o(ci, PackedVector2Array([c + Vector2(-14, -8) * u, c + Vector2(-4, -15) * u, c + Vector2(10, -13) * u, c + Vector2(15, 0) * u, c + Vector2(11, 14) * u, c + Vector2(-11, 14) * u]), Color("e6d6a6"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-10, -4) * u, c + Vector2(-3, -10) * u, c + Vector2(8, -9) * u, c + Vector2(11, 0) * u]), Color(Palette.INK, 0.35), 1.6)
			ci.draw_line(c + Vector2(-12, -2) * u, c + Vector2(-12, 12) * u, Color(0, 0, 0, 0.35), 2.0)
			_o(ci, PackedVector2Array([c + Vector2(10, -13) * u, c + Vector2(15, 0) * u, c + Vector2(8, -2) * u]), Color("cdb98a"), 1.4)
		"leatherbound_binding":
			_o(ci, PackedVector2Array([c + Vector2(-15, -6) * u, c + Vector2(-6, -15) * u, c + Vector2(10, -15) * u, c + Vector2(16, -4) * u, c + Vector2(12, 14) * u, c + Vector2(-10, 14) * u]), Color("4a2f22"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-11, -4) * u, c + Vector2(-4, -11) * u, c + Vector2(8, -11) * u, c + Vector2(12, -3) * u, c + Vector2(9, 10) * u, c + Vector2(-7, 10) * u, c + Vector2(-11, -4) * u]), Color("d8b45e"), 1.8)
			for p in [Vector2(-6, -7), Vector2(6, -7), Vector2(0, 6)]:
				ci.draw_circle(c + p * u, 2.0 * u, Color("d8b45e"))
		"gilded_binding":
			_o(ci, PackedVector2Array([c + Vector2(-15, -6) * u, c + Vector2(-6, -15) * u, c + Vector2(10, -15) * u, c + Vector2(16, -4) * u, c + Vector2(12, 14) * u, c + Vector2(-10, 14) * u]), Color("d8b45e"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-10, -3) * u, c + Vector2(-4, -10) * u, c + Vector2(8, -10) * u, c + Vector2(11, -2) * u, c + Vector2(8, 9) * u, c + Vector2(-6, 9) * u, c + Vector2(-10, -3) * u]), Color("8a6a22"), 1.6)
			ci.draw_circle(c, 4.0 * u, Color("5ad0e8"))
			ci.draw_arc(c, 4.0 * u, 0.0, TAU, 10, Palette.OUTLINE, 1.6, true)
			ci.draw_line(c + Vector2(-12, -1) * u, c + Vector2(-9, -12) * u, Color(1, 1, 1, 0.6), 1.8)
		"highlighter":
			_o(ci, PackedVector2Array([c + Vector2(-14, 8) * u, c + Vector2(-6, 14) * u, c + Vector2(12, -8) * u, c + Vector2(4, -14) * u]), Color("f4e04a"))
			_o(ci, PackedVector2Array([c + Vector2(-14, 8) * u, c + Vector2(-6, 14) * u, c + Vector2(-9, 16) * u, c + Vector2(-17, 12) * u]), Color("d9a52a"), 1.6)
			ci.draw_line(c + Vector2(-12, 16) * u, c + Vector2(12, 16) * u, Color(0.96, 0.88, 0.3, 0.7), 4.0 * u)
		"margin_note":
			_o(ci, PackedVector2Array([c + Vector2(-12, -14) * u, c + Vector2(12, -14) * u, c + Vector2(12, 14) * u, c + Vector2(-12, 14) * u]), Color("f4ecd6"))
			ci.draw_line(c + Vector2(-6, -14) * u, c + Vector2(-6, 14) * u, Color("d96a5c"), 1.6)
			for i in 4:
				ci.draw_line(c + Vector2(-2, -8 + i * 5) * u, c + Vector2(9, -8 + i * 5) * u, Color(Palette.INK, 0.4), 1.2)
			ci.draw_string(ThemeDB.get_default_theme().default_font, c + Vector2(-11, 0) * u, "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(14 * u), Color("d96a5c"))
		"index_tab":
			_o(ci, PackedVector2Array([c + Vector2(-12, -8) * u, c + Vector2(-4, -8) * u, c + Vector2(-2, -15) * u, c + Vector2(8, -15) * u, c + Vector2(10, -8) * u, c + Vector2(12, -8) * u, c + Vector2(12, 14) * u, c + Vector2(-12, 14) * u]), Color("5fb0a0"))
			ci.draw_line(c + Vector2(-6, 0) * u, c + Vector2(6, 0) * u, Color(1, 1, 1, 0.5), 1.6)
			ci.draw_line(c + Vector2(-6, 5) * u, c + Vector2(3, 5) * u, Color(1, 1, 1, 0.5), 1.6)
		"red_pen":
			_o(ci, PackedVector2Array([c + Vector2(-13, 9) * u, c + Vector2(-9, 13) * u, c + Vector2(13, -9) * u, c + Vector2(9, -13) * u]), Color("c8483f"))
			_o(ci, PackedVector2Array([c + Vector2(-13, 9) * u, c + Vector2(-9, 13) * u, c + Vector2(-16, 16) * u]), Color("2b2b3a"), 1.6)
			ci.draw_line(c + Vector2(-2, 2) * u, c + Vector2(4, -4) * u, Color(1, 1, 1, 0.45), 1.8)
		"footnote":
			ci.draw_circle(c + Vector2(0, -2) * u, 12.0 * u, Color("f4ecd6"))
			ci.draw_arc(c + Vector2(0, -2) * u, 12.0 * u, 0.0, TAU, 18, Palette.OUTLINE, 2.4, true)
			ci.draw_string(ThemeDB.get_default_theme().default_font, c + Vector2(-4, 3) * u, "1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(18 * u), Palette.INK)
			ci.draw_line(c + Vector2(0, 10) * u, c + Vector2(0, 17) * u, Palette.OUTLINE, 2.0)
		"bookmark_charm":
			_o(ci, PackedVector2Array([c + Vector2(-5, -17) * u, c + Vector2(5, -17) * u, c + Vector2(5, 4) * u, c + Vector2(0, 0) * u, c + Vector2(-5, 4) * u]), Palette.CRITIC_RED.lightened(0.15))
			var st := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * PI / 5.0
				st.append(c + Vector2(0, 8) * u + Vector2(cos(a), sin(a)) * (8.0 if k % 2 == 0 else 3.6) * u)
			_o(ci, st, Palette.GOLD, 1.6)
		"first_edition":
			_o(ci, PackedVector2Array([c + Vector2(-13, -13) * u, c + Vector2(11, -13) * u, c + Vector2(13, 13) * u, c + Vector2(-11, 13) * u]), Color("6b2f2a"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-9, -9) * u, c + Vector2(8, -9) * u, c + Vector2(9, 9) * u, c + Vector2(-8, 9) * u, c + Vector2(-9, -9) * u]), Color("d8b45e"), 1.6)
			var st2 := PackedVector2Array()
			for k in 10:
				var a2 := -PI / 2.0 + k * PI / 5.0
				st2.append(c + Vector2(0, 0) * u + Vector2(cos(a2), sin(a2)) * (6.0 if k % 2 == 0 else 2.6) * u)
			_o(ci, st2, Color("d8b45e"), 1.4)
		_:
			var ic: Dictionary = ItemDB.info(id).get("icon", {})
			if ic.is_empty():
				ci.draw_circle(c, 10.0 * u, Palette.PENCIL)
			else:
				ItemShapes.draw(ci, String(ic["s"]), c, u, Color(String(ic["c"])), Color(String(ic["c2"])))
