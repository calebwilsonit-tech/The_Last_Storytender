class_name ItemShapes
extends RefCounted
## Little procedural pictures for catalog items: one drawing per `shape`, tinted by the item's
## two colours. Everything is drawn around centre c at scale u (size / 44).

static func _p(c: Vector2, u: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(c + v * u)
	return out

static func _o(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Palette.OUTLINE, w, true)

static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color) -> void:
	_o(ci, DrawKit.ellipse(c, rx, ry, 18), fill)

static func _star(c: Vector2, r: float, r2: float, n: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n * 2:
		var a := -PI / 2.0 + k * PI / n
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r2))
	return pts

static func draw(ci: CanvasItem, shape: String, c: Vector2, u: float, c1: Color, c2: Color) -> void:
	var line := Palette.OUTLINE
	match shape:
		"scrap":
			_o(ci, _p(c, u, [Vector2(-13, -10), Vector2(2, -14), Vector2(14, -6), Vector2(11, 10), Vector2(-4, 14), Vector2(-14, 6)]), c1)
			ci.draw_line(c + Vector2(-8, -3) * u, c + Vector2(6, -5) * u, c2, 1.6)
			ci.draw_line(c + Vector2(-8, 3) * u, c + Vector2(7, 2) * u, c2, 1.6)
		"drop":
			_o(ci, _p(c, u, [Vector2(0, -16), Vector2(10, 2), Vector2(8, 10), Vector2(0, 15), Vector2(-8, 10), Vector2(-10, 2)]), c1)
			ci.draw_circle(c + Vector2(-3, 3) * u, 3.0 * u, c2)
		"curl":
			ci.draw_arc(c, 11.0 * u, 0.4, TAU - 0.4, 20, c2, 5.0 * u, true)
			ci.draw_arc(c, 11.0 * u, 0.4, TAU - 0.4, 20, c1, 3.0 * u, true)
		"spool":
			_o(ci, _p(c, u, [Vector2(-10, -13), Vector2(10, -13), Vector2(10, -9), Vector2(-10, -9)]), c2)
			_o(ci, _p(c, u, [Vector2(-10, 9), Vector2(10, 9), Vector2(10, 13), Vector2(-10, 13)]), c2)
			_o(ci, _p(c, u, [Vector2(-8, -9), Vector2(8, -9), Vector2(8, 9), Vector2(-8, 9)]), c1)
			for i in 3:
				ci.draw_line(c + Vector2(-8, -5 + i * 5) * u, c + Vector2(8, -3 + i * 5) * u, c2, 1.4)
		"tube":
			_o(ci, _p(c, u, [Vector2(-6, -14), Vector2(6, -14), Vector2(7, 8), Vector2(-7, 8)]), c1)
			_o(ci, _p(c, u, [Vector2(-5, 8), Vector2(5, 8), Vector2(4, 14), Vector2(-4, 14)]), c2)
		"leaf":
			_o(ci, _p(c, u, [Vector2(0, -15), Vector2(12, -4), Vector2(8, 10), Vector2(0, 14), Vector2(-8, 10), Vector2(-12, -4)]), c1)
			ci.draw_line(c + Vector2(0, -12) * u, c + Vector2(0, 14) * u, c2, 2.0)
			ci.draw_line(c + Vector2(0, 0) * u, c + Vector2(7, -5) * u, c2, 1.6)
			ci.draw_line(c + Vector2(0, 5) * u, c + Vector2(-7, 0) * u, c2, 1.6)
		"seal":
			_ell(ci, c, 14.0 * u, 13.0 * u, c1)
			ci.draw_arc(c, 8.0 * u, 0.0, TAU, 18, c2, 2.0, true)
			ci.draw_polyline(_p(c, u, [Vector2(-4, 3), Vector2(0, -5), Vector2(4, 3)]), c2, 2.0, true)
		"feather":
			_o(ci, _p(c, u, [Vector2(10, -15), Vector2(14, -2), Vector2(2, 10), Vector2(-8, 13), Vector2(-4, 2), Vector2(4, -8)]), c1)
			ci.draw_line(c + Vector2(-12, 16) * u, c + Vector2(10, -13) * u, c2, 2.0)
		"dust":
			for p: Vector2 in [Vector2(-8, 6), Vector2(2, 9), Vector2(10, 4), Vector2(-3, -2), Vector2(6, -8), Vector2(-10, -8)]:
				ci.draw_circle(c + p * u, 4.0 * u, c1)
				ci.draw_circle(c + p * u, 4.0 * u, c2, false, 1.6)
			ci.draw_polygon(_star(c + Vector2(0, -10) * u, 6.0 * u, 2.2 * u, 4), PackedColorArray([Color.WHITE]))
		"gem":
			_o(ci, _p(c, u, [Vector2(-10, -4), Vector2(-5, -12), Vector2(5, -12), Vector2(10, -4), Vector2(0, 14)]), c1)
			ci.draw_polyline(_p(c, u, [Vector2(-10, -4), Vector2(10, -4)]), c2, 1.6)
			ci.draw_polyline(_p(c, u, [Vector2(-5, -12), Vector2(-3, -4), Vector2(0, 14), Vector2(3, -4), Vector2(5, -12)]), c2, 1.4)
		"flame":
			_o(ci, _p(c, u, [Vector2(0, -16), Vector2(8, -4), Vector2(11, 6), Vector2(0, 14), Vector2(-11, 6), Vector2(-7, -4)]), c1)
			_o(ci, _p(c, u, [Vector2(0, -4), Vector2(5, 4), Vector2(0, 11), Vector2(-5, 4)]), c2, 1.4)
		"star":
			_o(ci, _star(c, 15.0 * u, 6.5 * u), c1)
			ci.draw_circle(c, 3.0 * u, c2)
		"cup":
			_o(ci, _p(c, u, [Vector2(-11, -6), Vector2(9, -6), Vector2(7, 9), Vector2(-9, 9)]), c2)
			ci.draw_arc(c + Vector2(10, 1) * u, 5.0 * u, -PI / 2, PI / 2, 8, line, 2.4, true)
			_o(ci, _p(c, u, [Vector2(-10, -6), Vector2(8, -6), Vector2(8, -3), Vector2(-10, -3)]), c1, 1.4)
		"biscuit":
			_ell(ci, c, 14.0 * u, 11.0 * u, c1)
			for p: Vector2 in [Vector2(-5, -2), Vector2(4, -4), Vector2(2, 4), Vector2(-4, 5)]:
				ci.draw_circle(c + p * u, 1.6 * u, c2)
		"bottle":
			_o(ci, _p(c, u, [Vector2(-4, -15), Vector2(4, -15), Vector2(4, -7), Vector2(10, 2), Vector2(9, 13), Vector2(-9, 13), Vector2(-10, 2), Vector2(-4, -7)]), c1)
			_o(ci, _p(c, u, [Vector2(-5, -17), Vector2(5, -17), Vector2(5, -14), Vector2(-5, -14)]), c2, 1.6)
			ci.draw_line(c + Vector2(-5, 3) * u, c + Vector2(-5, 9) * u, Color(1, 1, 1, 0.6), 2.0)
		"book":
			_o(ci, _p(c, u, [Vector2(-12, -12), Vector2(10, -12), Vector2(12, 12), Vector2(-10, 12)]), c1)
			_o(ci, _p(c, u, [Vector2(-9, -9), Vector2(9, -9), Vector2(10, 9), Vector2(-8, 9)]), c2, 1.2)
			ci.draw_line(c + Vector2(-5, -3) * u, c + Vector2(6, -3) * u, c1, 1.6)
		"jar":
			_o(ci, _p(c, u, [Vector2(-8, -10), Vector2(8, -10), Vector2(11, -2), Vector2(11, 12), Vector2(-11, 12), Vector2(-11, -2)]), Color(c1, 0.85))
			_o(ci, _p(c, u, [Vector2(-8, -15), Vector2(8, -15), Vector2(8, -10), Vector2(-8, -10)]), c2, 1.6)
			ci.draw_polygon(_star(c + Vector2(0, 3) * u, 6.0 * u, 2.4 * u, 4), PackedColorArray([Color.WHITE]))
		"cover":
			_o(ci, _p(c, u, [Vector2(-13, -12), Vector2(11, -12), Vector2(13, 13), Vector2(-11, 13)]), c1)
			ci.draw_polyline(_p(c, u, [Vector2(-9, -8), Vector2(8, -8), Vector2(9, 9), Vector2(-8, 9), Vector2(-9, -8)]), c2, 1.8)
			ci.draw_line(c + Vector2(-13, -12) * u, c + Vector2(-11, 13) * u, c2, 3.0)
		"clip":
			ci.draw_polyline(_p(c, u, [Vector2(4, 12), Vector2(-6, 12), Vector2(-6, -8), Vector2(4, -8), Vector2(4, 6), Vector2(-1, 6), Vector2(-1, -4)]), line, 4.6 * u, true)
			ci.draw_polyline(_p(c, u, [Vector2(4, 12), Vector2(-6, 12), Vector2(-6, -8), Vector2(4, -8), Vector2(4, 6), Vector2(-1, 6), Vector2(-1, -4)]), c1, 2.4 * u, true)
		"ring":
			ci.draw_arc(c, 11.0 * u, 0.0, TAU, 20, line, 6.0 * u, true)
			ci.draw_arc(c, 11.0 * u, 0.0, TAU, 20, c1, 3.6 * u, true)
		"bell":
			_o(ci, _p(c, u, [Vector2(-3, -14), Vector2(3, -14), Vector2(9, 2), Vector2(12, 9), Vector2(-12, 9), Vector2(-9, 2)]), c1)
			ci.draw_circle(c + Vector2(0, 12) * u, 3.0 * u, c2)
		"glasses":
			ci.draw_arc(c + Vector2(-7, 0) * u, 6.5 * u, 0.0, TAU, 14, c1, 3.0, true)
			ci.draw_arc(c + Vector2(7, 0) * u, 6.5 * u, 0.0, TAU, 14, c1, 3.0, true)
			ci.draw_circle(c + Vector2(-7, 0) * u, 5.0 * u, Color(c2, 0.55))
			ci.draw_circle(c + Vector2(7, 0) * u, 5.0 * u, Color(c2, 0.55))
			ci.draw_line(c + Vector2(-0.5, -1) * u, c + Vector2(0.5, -1) * u, c1, 3.0)
		"worm":
			for k in 5:
				_ell(ci, c + Vector2(-10 + k * 5, sin(k * 1.2) * 5) * u, 5.5 * u, 5.0 * u, c1 if k % 2 == 0 else c2)
			ci.draw_circle(c + Vector2(10, sin(4 * 1.2) * 5 - 1) * u, 1.2 * u, Palette.OUTLINE)
		"compass":
			_ell(ci, c, 14.0 * u, 14.0 * u, c1)
			ci.draw_circle(c, 10.0 * u, Color("f4ecd8"))
			ci.draw_colored_polygon(_p(c, u, [Vector2(0, -9), Vector2(3, 0), Vector2(0, 9), Vector2(-3, 0)]), c2)
			ci.draw_colored_polygon(_p(c, u, [Vector2(0, -9), Vector2(3, 0), Vector2(-3, 0)]), Color("b8402f"))
		"ribbon":
			_o(ci, _p(c, u, [Vector2(-12, -6), Vector2(0, -2), Vector2(12, -6), Vector2(12, 4), Vector2(0, 8), Vector2(-12, 4)]), c1)
			_o(ci, _p(c, u, [Vector2(-4, 6), Vector2(-9, 15), Vector2(-3, 12), Vector2(0, 16), Vector2(0, 6)]), c2, 1.6)
			_o(ci, _p(c, u, [Vector2(4, 6), Vector2(9, 15), Vector2(3, 12), Vector2(0, 16), Vector2(0, 6)]), c2, 1.6)
		"match":
			_o(ci, _p(c, u, [Vector2(-2, -4), Vector2(2, -4), Vector2(2, 15), Vector2(-2, 15)]), c2)
			_o(ci, _p(c, u, [Vector2(0, -17), Vector2(6, -9), Vector2(0, -3), Vector2(-6, -9)]), c1)
		"glove":
			_o(ci, _p(c, u, [Vector2(-8, 14), Vector2(-9, 0), Vector2(-9, -10), Vector2(-5, -10), Vector2(-5, -3), Vector2(-3, -14), Vector2(1, -14), Vector2(1, -4), Vector2(3, -13), Vector2(7, -12), Vector2(5, -2), Vector2(9, -6), Vector2(11, -3), Vector2(7, 6), Vector2(7, 14)]), c1)
			ci.draw_line(c + Vector2(-8, 11) * u, c + Vector2(7, 11) * u, c2, 2.4)
		"hourglass":
			_o(ci, _p(c, u, [Vector2(-9, -15), Vector2(9, -15), Vector2(9, -12), Vector2(1.5, 0), Vector2(9, 12), Vector2(9, 15), Vector2(-9, 15), Vector2(-9, 12), Vector2(-1.5, 0), Vector2(-9, -12)]), Color(c1, 0.8))
			ci.draw_colored_polygon(_p(c, u, [Vector2(-5, 13), Vector2(5, 13), Vector2(0, 5)]), c2)
			ci.draw_colored_polygon(_p(c, u, [Vector2(-2, -9), Vector2(2, -9), Vector2(0, -3)]), c2)
		"monocle":
			ci.draw_arc(c + Vector2(0, -3) * u, 10.0 * u, 0.0, TAU, 20, line, 6.0 * u, true)
			ci.draw_arc(c + Vector2(0, -3) * u, 10.0 * u, 0.0, TAU, 20, c1, 3.6 * u, true)
			ci.draw_circle(c + Vector2(0, -3) * u, 8.0 * u, Color(c2, 0.4))
			ci.draw_polyline(_p(c, u, [Vector2(0, 7), Vector2(3, 12), Vector2(-1, 16)]), c1, 2.0, true)
		"inkwell":
			_o(ci, _p(c, u, [Vector2(-12, 0), Vector2(-8, -8), Vector2(8, -8), Vector2(12, 0), Vector2(12, 13), Vector2(-12, 13)]), c1)
			ci.draw_circle(c + Vector2(0, -6) * u, 3.4 * u, c2)
			_o(ci, _p(c, u, [Vector2(6, -6), Vector2(14, -17), Vector2(12, -7)]), Color("f4f0e6"), 1.6)
		"pen":
			_o(ci, _p(c, u, [Vector2(10, -15), Vector2(15, -10), Vector2(-5, 10), Vector2(-12, 14), Vector2(-9, 7)]), c2)
			_o(ci, _p(c, u, [Vector2(-9, 7), Vector2(-5, 10), Vector2(-12, 14)]), c1, 1.6)
			ci.draw_line(c + Vector2(12, -12) * u, c + Vector2(-6, 7) * u, c1, 1.8)
		"bookmark":
			_o(ci, _p(c, u, [Vector2(-6, -17), Vector2(6, -17), Vector2(6, 15), Vector2(0, 8), Vector2(-6, 15)]), c1)
			ci.draw_polygon(_star(c + Vector2(0, -6) * u, 4.4 * u, 1.8 * u), PackedColorArray([c2]))
		"bench":
			_o(ci, _p(c, u, [Vector2(-15, -4), Vector2(15, -4), Vector2(15, 2), Vector2(-15, 2)]), c1)
			_o(ci, _p(c, u, [Vector2(-12, 2), Vector2(-8, 2), Vector2(-9, 14), Vector2(-13, 14)]), c2, 1.6)
			_o(ci, _p(c, u, [Vector2(12, 2), Vector2(8, 2), Vector2(9, 14), Vector2(13, 14)]), c2, 1.6)
			_o(ci, _p(c, u, [Vector2(-8, -12), Vector2(-2, -12), Vector2(-2, -4), Vector2(-8, -4)]), c2, 1.6)
			ci.draw_line(c + Vector2(4, -14) * u, c + Vector2(10, -5) * u, line, 3.0)
		"spiral":
			var pts := PackedVector2Array()
			for k in 40:
				var t := k / 39.0
				var a := t * TAU * 2.2
				pts.append(c + Vector2(cos(a), sin(a)) * (1.5 + t * 14.0) * u)
			ci.draw_polyline(pts, line, 5.0 * u, true)
			ci.draw_polyline(pts, c1, 3.0 * u, true)
			ci.draw_circle(c, 2.4 * u, c2)
		_:
			ci.draw_circle(c, 10.0 * u, c1)
