class_name CelKit
extends RefCounted
## Drawing helpers for the Ink Cel style: flat colour, a single cel shadow, a thin rim light on the
## lit edge, and a heavy near-black outline of one fixed weight. Light always comes from the upper left.

const OUT := Color("14111a")
const LIGHT := Vector2(-0.55, -0.83)     # direction TOWARD the light
const W := 1.8                           # outline weight at figure scale

static func shade_of(c: Color) -> Color:
	return Color(c.r * 0.66, c.g * 0.63, c.b * 0.72, c.a)

static func lit_of(c: Color) -> Color:
	return Color(minf(c.r * 1.22 + 0.04, 1.0), minf(c.g * 1.2 + 0.04, 1.0), minf(c.b * 1.16 + 0.03, 1.0), c.a)

static func centroid(pts: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / maxf(pts.size(), 1.0)

static func radius_of(pts: PackedVector2Array, c: Vector2) -> float:
	var r := 1.0
	for p in pts:
		r = maxf(r, p.distance_to(c))
	return r

## A filled, outlined shape with one cel shadow on the side away from the light and a rim light on the lit edges.
static func piece(ci: CanvasItem, pts: PackedVector2Array, fill: Color, shade := 0.42, rim := true, w := W, flash := 0.0) -> void:
	var base := fill.lerp(Color.WHITE, flash)
	ci.draw_colored_polygon(pts, base)
	var c := centroid(pts)
	var r := radius_of(pts, c)
	if shade > 0.0:
		var n := -LIGHT
		var t := n.orthogonal()
		var off := r * (0.5 - shade) * 1.0
		var big := 400.0
		var half := PackedVector2Array([
			c + n * off + t * big, c + n * off - t * big,
			c + n * (off + big) - t * big, c + n * (off + big) + t * big])
		var parts := Geometry2D.intersect_polygons(pts, half)
		var sc := shade_of(base)
		for pr in parts:
			ci.draw_colored_polygon(pr, sc)
	if rim:
		_rim(ci, pts, lit_of(base))
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, OUT, w, true)

## Thin highlight just inside the edges that face the light.
static func _rim(ci: CanvasItem, pts: PackedVector2Array, col: Color, inset_w := W) -> void:
	var n := pts.size()
	var area := 0.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var sgn := 1.0 if area > 0.0 else -1.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var e := b - a
		if e.length() < 2.5:
			continue
		var out_n := Vector2(e.y, -e.x).normalized() * sgn      # outward normal
		var lit := out_n.dot(LIGHT)
		if lit > 0.45:
			var inset := -out_n * (inset_w * 0.5 + 1.0)
			ci.draw_line(a + inset + e.normalized() * 1.5, b + inset - e.normalized() * 1.5, Color(col, 0.9), 1.3, true)

static func ell(c: Vector2, rx: float, ry: float, n := 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

## A rounded rectangle-ish polygon (corner radius r), good for limbs and packs.
static func rrect(x0: float, y0: float, x1: float, y1: float, r := 2.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0 + r, y0), Vector2(x1 - r, y0), Vector2(x1, y0 + r), Vector2(x1, y1 - r),
		Vector2(x1 - r, y1), Vector2(x0 + r, y1), Vector2(x0, y1 - r), Vector2(x0, y0 + r)])

## A limb drawn as a tapered capsule between two joints.
static func limb(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	pts.append(a + n * wa * 0.5)
	pts.append(b + n * wb * 0.5)
	pts.append(b + d * wb * 0.35)
	pts.append(b - n * wb * 0.5)
	pts.append(a - n * wa * 0.5)
	pts.append(a - d * wa * 0.35)
	return pts

static func mirror_pts(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(-p.x, p.y))
	return out


## Records the parts of one figure so they can be drawn in passes: glow first, then a single thick
## silhouette outline behind everything, then each part with only a thin inner line. That is what
## gives the reference sheets their clean heavy outer contour without muddy double lines.
class Rec extends RefCounted:
	var pre: Array = []        # drawn first (glow, ground effects)
	var parts: Array = []      # {pts, fill, shade, rim, xf}
	var ops: Array = []        # {fn, xf}  extra strokes drawn in order with the parts
	var order: Array = []      # sequence of ["part", i] / ["op", i]
	var xf := {"pivot": Vector2.ZERO, "rot": 0.0, "sx": 1.0}
	var inner := 1.1
	var outer := 2.2
	var depth := 0.0           # painter's order: smaller = further from the camera
	var out := Color("14111a")   # outline colour (ghostly graphite for people who are still missing)

	func at(pivot: Vector2, rot: float, sx := 1.0) -> void:
		xf = {"pivot": pivot, "rot": rot, "sx": sx}

	func reset() -> void:
		xf = {"pivot": Vector2.ZERO, "rot": 0.0, "sx": 1.0}

	func piece(pts: PackedVector2Array, fill: Color, shade := 0.42, rim := true, flash := 0.0, outline := true, soft_corners := 0) -> void:
		if soft_corners > 0:
			pts = CelKit.soft(pts, soft_corners)
		if Geometry2D.triangulate_polygon(pts).is_empty():
			if OS.get_environment("ART_DEBUG") != "":
				print("bad polygon ", fill, " ", pts)
			return
		parts.append({"pts": pts, "fill": fill, "shade": shade, "rim": rim, "flash": flash, "xf": xf, "outline": outline})
		order.append(["part", parts.size() - 1, depth, order.size()])

	func op(fn: Callable) -> void:
		ops.append({"fn": fn, "xf": xf})
		order.append(["op", ops.size() - 1, depth, order.size()])

	func glow(fn: Callable) -> void:
		pre.append({"fn": fn, "xf": xf})

	func flush(ci: CanvasItem, apply_xf: Callable) -> void:
		for g in pre:
			apply_xf.call(g["xf"])
			(g["fn"] as Callable).call(ci)
		# silhouette backing
		for p in parts:
			if not p["outline"]:
				continue
			apply_xf.call(p["xf"])
			for bp in Geometry2D.offset_polygon(p["pts"], outer, Geometry2D.JOIN_ROUND):
				ci.draw_colored_polygon(bp, out)
		order.sort_custom(func(a, b): return a[2] < b[2] or (a[2] == b[2] and a[3] < b[3]))
		for o in order:
			if o[0] == "part":
				var p: Dictionary = parts[o[1]]
				apply_xf.call(p["xf"])
				var pts: PackedVector2Array = p["pts"]
				var base: Color = (p["fill"] as Color).lerp(Color.WHITE, p["flash"])
				ci.draw_colored_polygon(pts, base)
				var shade: float = p["shade"]
				if shade > 0.0:
					# cel shadow: a crescent along the edges that face away from the light
					var c := CelKit.centroid(pts)
					var rr := CelKit.radius_of(pts, c)
					var thick := clampf(rr * shade * 0.6, 1.2, 7.0)
					var lifted := PackedVector2Array()
					for q in pts:
						lifted.append(q + CelKit.LIGHT * thick)
					for pr in Geometry2D.clip_polygons(pts, lifted):
						if not Geometry2D.is_polygon_clockwise(pr) or true:
							ci.draw_colored_polygon(pr, CelKit.shade_of(base))
				if p["rim"]:
					CelKit._rim(ci, pts, CelKit.lit_of(base), inner)
				if p["outline"]:
					var loop := pts.duplicate()
					loop.append(pts[0])
					ci.draw_polyline(loop, Color(out, 0.9), inner, true)
			else:
				var op: Dictionary = ops[o[1]]
				apply_xf.call(op["xf"])
				(op["fn"] as Callable).call(ci)


## Chaikin corner cutting: turns a blocky polygon into a soft, rounded one with the same silhouette.
static func soft(pts: PackedVector2Array, iterations := 2, keep := 0.25) -> PackedVector2Array:
	var cur := pts
	for _i in iterations:
		var nxt := PackedVector2Array()
		var n := cur.size()
		for i in n:
			var a := cur[i]
			var b := cur[(i + 1) % n]
			nxt.append(a.lerp(b, keep))
			nxt.append(a.lerp(b, 1.0 - keep))
		cur = nxt
	return cur
