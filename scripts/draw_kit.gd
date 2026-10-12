class_name DrawKit
extends RefCounted
## Hand-drawn line helpers. Every stroke wobbles a little so shapes read as
## pen on paper instead of vector geometry. Call from inside a node's _draw().

static func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)

static func wobble(a: Vector2, b: Vector2, seed_v: float, amp: float = 1.2, step: float = 14.0) -> PackedVector2Array:
	var n := maxi(int(a.distance_to(b) / step), 1)
	var out := PackedVector2Array()
	var perp := (b - a).orthogonal().normalized()
	for i in n + 1:
		var o := 0.0
		if i > 0 and i < n:
			o = (_h(seed_v + i * 1.7) - 0.5) * 2.0 * amp
		out.append(a.lerp(b, float(i) / n) + perp * o)
	return out

static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0, seed_v: float = 0.0, amp: float = 1.2) -> void:
	if color.a <= 0.01:
		return
	ci.draw_polyline(wobble(a, b, seed_v, amp), color, width, true)

static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float = 2.0, seed_v: float = 0.0, amp: float = 1.0) -> void:
	for i in pts.size():
		line(ci, pts[i], pts[(i + 1) % pts.size()], color, width, seed_v + i * 3.1, amp)

## Filled polygon (convex) with a wobbly outline.
static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, edge: Color, width: float = 2.0, seed_v: float = 0.0) -> void:
	if fill.a > 0.01:
		ci.draw_colored_polygon(pts, fill)
	outline(ci, pts, edge, width, seed_v)

## Parallel hatch strokes across a quad (pts: a, b, c, d going around).
static func hatch(ci: CanvasItem, q: PackedVector2Array, count: int, color: Color, width: float = 1.0) -> void:
	if color.a <= 0.01:
		return
	for i in range(1, count):
		var t := float(i) / count
		ci.draw_line(q[0].lerp(q[3], t), q[1].lerp(q[2], t), color, width, true)

## Point on a quad face: u across (a->b), v up (a->d).
static func face(q: PackedVector2Array, u: float, v: float) -> Vector2:
	return q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v)

static func face_quad(q: PackedVector2Array, u0: float, v0: float, u1: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([face(q, u0, v0), face(q, u1, v0), face(q, u1, v1), face(q, u0, v1)])

static func ellipse(center: Vector2, rx: float, ry: float, n: int = 20, jitter: float = 0.0, seed_v: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + (_h(seed_v + i) - 0.5) * jitter
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts
