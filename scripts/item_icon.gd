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
		"bookmark":
			_o(ci, PackedVector2Array([c + Vector2(-6, -16) * u, c + Vector2(6, -16) * u, c + Vector2(6, 14) * u, c + Vector2(0, 8) * u, c + Vector2(-6, 14) * u]), Palette.CRITIC_RED.lightened(0.15))
			ci.draw_line(c + Vector2(0, -14) * u, c + Vector2(0, 4) * u, Color(1, 1, 1, 0.3), 1.6)
		_:
			ci.draw_circle(c, 10.0 * u, Palette.PENCIL)
