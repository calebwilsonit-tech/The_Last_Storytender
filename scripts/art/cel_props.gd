class_name CelProps
extends RefCounted
## Ink Cel props: the world's furniture drawn by the same rules as the people. A heavy near-black
## contour around the whole object, flat colour, one cel shadow along the edges away from the light
## (upper left), a thin rim light, and chunky simple shapes. Wooden things share one brown, stone
## things share one grey, and anything magical glows cyan or gold.

const K := preload("res://scripts/art/cel_kit.gd")

const WOOD := Color("93633d")
const WOOD_D := Color("5e3d28")
const WALL := Color("e8d6ae")
const WALL_B := Color("dfbf8c")
const ROOF_A := Color("a4493e")
const ROOF_B := Color("5f7b8f")
const STONE := Color("8f95a4")
const STONE_D := Color("636b7e")
const IRON := Color("5d6373")
const LEAF := Color("6a9a50")
const LEAF_D := Color("4c7d42")
const GOLD := Color("e6b94a")
const PAGE := Color("f4e8c8")
const GRAPHITE := Color("3b3e4d")

static func kinds() -> Array:
	return ["prop_tree", "prop_house", "prop_forge", "prop_crystal", "prop_sign", "prop_sword", "prop_shard", "prop_anvil", "prop_portal",
		"prop_book", "prop_chair", "prop_table", "prop_oven", "prop_rift", "prop_post", "prop_gate", "prop_chest",
		"prop_dummy", "prop_block", "prop_plate", "prop_echoplate"]

static func build(r: K.Rec, kind: String, ctx: Dictionary) -> void:
	match kind:
		"prop_tree": _tree(r, ctx)
		"prop_house": _house(r, ctx, false)
		"prop_forge": _house(r, ctx, true)
		"prop_crystal": _crystal(r, ctx)
		"prop_sign": _sign(r, ctx)
		"prop_sword": _sword(r, ctx)
		"prop_shard": _shard(r, ctx)
		"prop_anvil": _anvil(r, ctx)
		"prop_portal": _portal(r, ctx)
		"prop_book": _book(r, ctx)
		"prop_chair": _chair(r, ctx)
		"prop_table": _table(r, ctx)
		"prop_oven": _oven(r, ctx)
		"prop_rift": _rift(r, ctx)
		"prop_post": _post(r, ctx)
		"prop_gate": _gate(r, ctx)
		"prop_chest": _chest(r, ctx)
		"prop_dummy": _dummy(r, ctx)
		"prop_block": _block(r, ctx)
		"prop_plate": _plate(r, ctx, false)
		"prop_echoplate": _plate(r, ctx, true)

static func _rng(seed_v: float, i: int) -> float:
	return fposmod(sin((seed_v + i * 3.17) * 12.9898) * 43758.5453, 1.0)

static func _blob(c: Vector2, rx: float, ry: float, n: int, jit: float, seed_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + (_rng(seed_v, i) - 0.5) * jit
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts

static func _glow_disc(r: K.Rec, c: Vector2, rad: float, col: Color, layers := 3) -> void:
	r.glow(func(ci):
		for k in layers:
			ci.draw_circle(c, rad * (1.0 - k * 0.3), col))

# --- Tree ---------------------------------------------------------------------------------------
static func _tree(r: K.Rec, ctx: Dictionary) -> void:
	var v: int = ctx.get("variant", 0) % 3
	var sd: float = ctx.get("seed", 0.0)
	var sway: float = ctx.get("sway", 0.0)
	var big := 24.0 + v * 3.0
	# roots and trunk
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-9, 1), Vector2(-5, -8), Vector2(-4.2, -36), Vector2(4.2, -36), Vector2(5, -8), Vector2(9, 1)]), 1), WOOD, 0.5, true)
	r.op(func(ci):
		ci.draw_line(Vector2(-1.5, -4), Vector2(-1.8, -26), Color(WOOD_D, 0.8), 1.1)
		ci.draw_line(Vector2(2.2, -10), Vector2(1.8, -30), Color(WOOD_D, 0.8), 1.0))
	# canopy: a cluster of lumpy lobes, back lobes darker so the front one reads as the lit mass
	var c := Vector2(sway, -54.0)
	var lobes := [
		[Vector2(-13, 4), 0.74, 0.62, LEAF_D, 0.1], [Vector2(13, 3), 0.74, 0.62, LEAF_D, 0.2],
		[Vector2(0, -10), 0.8, 0.7, LEAF, 0.3], [Vector2(-3, 6), 0.7, 0.55, LEAF, 0.4]]
	for i in lobes.size():
		var lb: Array = lobes[i]
		r.depth = 0.1 + i * 0.05
		var pts := _blob(c + (lb[0] as Vector2), big * float(lb[1]), big * float(lb[2]), 16, 0.16, sd + i * 7.0)
		r.piece(K.soft(pts, 1), lb[3], 0.6, true)
	# leaf notches and a few light flecks
	r.depth = 0.5
	r.op(func(ci):
		for i in 7:
			var p := c + Vector2(-16.0 + _rng(sd, i) * 32.0, -10.0 + _rng(sd, i + 9) * 24.0)
			var lean := -1.0 if i % 2 == 0 else 1.0
			ci.draw_line(p, p + Vector2(4.0 * lean, -2.2), Color(K.OUT, 0.4), 1.1)
		for i in 4:
			var q := c + Vector2(-14.0 + _rng(sd, i + 20) * 20.0, -14.0 + _rng(sd, i + 30) * 10.0)
			ci.draw_circle(q, 1.5, Color(LEAF.lightened(0.35), 0.8)))

# --- House and forge ---------------------------------------------------------------------------
static func _house(r: K.Rec, ctx: Dictionary, forge: bool) -> void:
	var rest: float = ctx.get("restored", 1.0)
	var flame: float = ctx.get("flame", rest)
	var v: int = ctx.get("variant", 0)
	var t: float = ctx.get("t", 0.0)
	var g := func(col: Color) -> Color:
		return Palette.ghostify(col, rest).lerp(Color("c9ccd6"), (1.0 - rest) * 0.45)
	r.out = GRAPHITE.lerp(K.OUT, rest)
	var d := Iso.diamond(Vector2.ZERO, 1.84)    # N, E, S, W
	var h := 56.0
	var up := Vector2(0, -h)
	var wall_c := WALL if v % 2 == 0 else WALL_B
	var roof_c := ROOF_A if v % 2 == 0 else ROOF_B
	if forge:
		wall_c = Color("cdb995")
		roof_c = Color("6b5a52")
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	r.depth = 0.0
	r.piece(left, g.call(wall_c), 0.12, true)
	r.piece(right, (g.call(wall_c) as Color).darkened(0.2), 0.12, false)
	# a timber frame: corner posts and a sill line
	var post_c: Color = g.call(WOOD_D)
	r.depth = 0.05
	for x in [d[3].x, d[2].x, d[1].x]:
		r.piece(K.rrect(x - 2.4, -h, x + 2.4, 0.0, 0.6), post_c, 0.2, false, 0.0, false)
	r.piece(PackedVector2Array([d[3] + up, d[2] + up, d[2] + up + Vector2(0, 4), d[3] + up + Vector2(0, 4)]), post_c, 0.2, false, 0.0, false)
	r.piece(PackedVector2Array([d[2] + up, d[1] + up, d[1] + up + Vector2(0, 4), d[2] + up + Vector2(0, 4)]), post_c.darkened(0.15), 0.2, false, 0.0, false)
	# windows on the left wall
	r.depth = 0.1
	for u in [0.25, 0.62]:
		var win := DrawKit.face_quad(left, u, 0.4, u + 0.15, 0.78)
		r.piece(win, g.call(Color("f6dc8e")) if rest > 0.0 else g.call(wall_c), 0.3, true)
		var a := DrawKit.face(left, u + 0.075, 0.4)
		var b := DrawKit.face(left, u + 0.075, 0.78)
		var a2 := DrawKit.face(left, u, 0.59)
		var b2 := DrawKit.face(left, u + 0.15, 0.59)
		r.op(func(ci):
			ci.draw_line(a, b, Color(r.out, 0.9), 1.1)
			ci.draw_line(a2, b2, Color(r.out, 0.9), 1.1))
	# door (or the forge mouth) on the right wall
	var door := DrawKit.face_quad(right, 0.3, 0.0, 0.62, 0.68)
	r.depth = 0.1
	if forge:
		r.piece(door, g.call(Color("2b1c14")), 0.0, false)
	else:
		r.piece(door, g.call(WOOD), 0.35, true)
		var kn := DrawKit.face(door, 0.82, 0.4)
		r.op(func(ci): ci.draw_circle(kn, 1.6, Color(r.out, 0.95)))
	# roof: two faces meeting at a ridge, slightly overhanging
	var apex := Vector2(0, -h - 44.0)
	var rl := PackedVector2Array([d[3] + up + Vector2(-9, 5), d[2] + up + Vector2(0, 11), apex])
	var rr := PackedVector2Array([d[2] + up + Vector2(0, 11), d[1] + up + Vector2(9, 5), apex])
	r.depth = 0.3
	r.piece(rl, g.call(roof_c), 0.3, true)
	r.piece(rr, (g.call(roof_c) as Color).darkened(0.24), 0.3, false)
	r.op(func(ci):
		for i in range(1, 5):
			var tt := i / 5.0
			ci.draw_line(rl[0].lerp(apex, tt), rl[1].lerp(apex, tt), Color(r.out, 0.38), 1.0, true)
			ci.draw_line(rr[0].lerp(apex, tt), rr[1].lerp(apex, tt), Color(r.out, 0.38), 1.0, true))
	# chimney
	r.depth = 0.25
	var cp := Vector2(22, -h - 30)
	r.piece(PackedVector2Array([cp, cp + Vector2(12, 6), cp + Vector2(12, -16), cp + Vector2(0, -22)]), g.call(Color("9c6b55")), 0.4, true)
	if forge and flame > 0.02 and rest >= 0.99:
		var sp := cp + Vector2(6, -22)
		r.op(func(ci):
			for i in 3:
				var ph := fmod(t * 0.4 + i * 0.33, 1.0)
				ci.draw_circle(sp + Vector2(sin(t + i) * 4.0, -ph * 26.0), 3.0 + ph * 5.0, Color(0.85, 0.85, 0.9, 0.35 * (1.0 - ph))))
	if forge:
		_forge_fire(r, DrawKit.face(door, 0.5, 0.0), flame, t)
	# [REDACTED]: a black censor bar over the doorway until the page is restored
	if rest < 1.0:
		r.depth = 0.9
		var bar := DrawKit.face_quad(left, 0.12, 0.3, 0.88, 0.5) if forge else DrawKit.face_quad(right, 0.18, 0.28, 0.78, 0.5)
		r.piece(bar, Color(K.OUT, 1.0 - rest), 0.0, false, 0.0, false)

static func _forge_fire(r: K.Rec, base: Vector2, fr: float, t: float) -> void:
	var col := Palette.FROZEN.lerp(Palette.FLAME, fr)
	var n := 15
	var pts := PackedVector2Array([base + Vector2(-16, 0)])
	for i in n:
		var u := float(i) / (n - 1)
		var tongues := 0.55 + 0.45 * absf(sin(u * PI * 3.0))
		var tip := 34.0 * sin(PI * u) * tongues
		tip *= 1.0 + 0.28 * sin(t * 9.0 + i * 1.9) * fr
		pts.append(base + Vector2(lerpf(-16.0, 16.0, u), -maxf(tip, 0.5)))
	pts.append(base + Vector2(16, 0))
	r.depth = 0.2
	r.piece(pts, col, 0.0, false, 0.0, true)
	r.piece(K.soft(PackedVector2Array([base + Vector2(-8, 0), base + Vector2(0, -16.0 * (0.5 + 0.5 * fr)), base + Vector2(8, 0)]), 1), col.lightened(0.4), 0.0, false, 0.0, false)
	if fr < 1.0:
		r.op(func(ci):
			for i in 4:
				var p := base + Vector2(-9 + i * 6, -16 - (i % 2) * 10)
				ci.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color(1, 1, 1, (1.0 - fr) * 0.9), 1.3)
				ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color(1, 1, 1, (1.0 - fr) * 0.9), 1.3))
	else:
		_glow_disc(r, base + Vector2(0, -14), 44.0, Color(Palette.FLAME, 0.07 + 0.03 * sin(t * 7.0)), 1)

# --- Crystal / shard -------------------------------------------------------------------------
static func _crystal(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var c := Vector2(0, -22 + sin(t * 2.2) * 3.0)
	_glow_disc(r, c, 26.0, Color(GOLD, 0.08), 2)
	r.depth = 0.0
	r.piece(PackedVector2Array([c + Vector2(0, -13), c + Vector2(9, -2), c + Vector2(5, 11), c + Vector2(-5, 11), c + Vector2(-9, -2)]), GOLD, 0.5, true)
	r.depth = 0.1
	r.piece(PackedVector2Array([c + Vector2(0, -13), c + Vector2(-3, -1), c + Vector2(-9, -2)]), GOLD.lightened(0.35), 0.0, false, 0.0, false)
	r.op(func(ci): ci.draw_line(c + Vector2(0, -11), c + Vector2(0, 10), Color(K.OUT, 0.35), 1.0))

static func _shard(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	if ctx.get("done", false):
		var ring := PackedVector2Array()
		for i in 21:
			ring.append(Vector2(cos(TAU * i / 20.0) * 12.0, sin(TAU * i / 20.0) * 6.0))
		r.op(func(ci): ci.draw_polyline(ring, Color(Palette.CYAN, 0.35), 2.0, true))
		return
	var c := Vector2(0, -34 + sin(t * 2.0) * 4.0)
	_glow_disc(r, c, 40.0, Color(Palette.CYAN, 0.075))
	var w := 8.0 + 3.0 * sin(t * 1.6)
	r.depth = 0.0
	r.piece(PackedVector2Array([c + Vector2(0, -18), c + Vector2(w, -5), c + Vector2(w * 0.7, 10), c + Vector2(0, 18), c + Vector2(-w * 0.7, 10), c + Vector2(-w, -5)]), Palette.CYAN, 0.5, true)
	r.depth = 0.1
	r.piece(PackedVector2Array([c + Vector2(0, -15), c + Vector2(-w * 0.9, -5), c + Vector2(-w * 0.2, 3), c + Vector2(w * 0.4, -5)]), Color(1, 1, 1, 0.6), 0.0, false, 0.0, false)
	r.op(func(ci):
		for i in 4:
			var ph := fmod(t * 0.45 + i * 0.27, 1.0)
			ci.draw_circle(Vector2(-12 + i * 8, -20 - ph * 44.0), 1.6, Color(Palette.CYAN, (1.0 - ph) * 0.9)))

# --- Sign, post, chair, chest -------------------------------------------------------------
static func _sign(r: K.Rec, ctx: Dictionary) -> void:
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-3.4, 1), Vector2(3.4, 1), Vector2(3, -40), Vector2(-3, -40)]), 1), WOOD, 0.5, true)
	r.depth = 0.1
	r.piece(PackedVector2Array([Vector2(-19, -46), Vector2(16, -46), Vector2(23, -37), Vector2(16, -28), Vector2(-19, -28)]), WOOD.lightened(0.14), 0.4, true, 0.0, true, 1)
	r.op(func(ci):
		for i in 3:
			ci.draw_line(Vector2(-13, -41 + i * 4.2), Vector2(10 - i * 3, -41 + i * 4.2), Color(WOOD_D, 0.8), 1.1)
		ci.draw_circle(Vector2(-15, -33), 0.9, Color(K.OUT, 0.8)))

static func _post(r: K.Rec, ctx: Dictionary) -> void:
	var lit: bool = ctx.get("variant", 0) == 1
	var t: float = ctx.get("t", 0.0)
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-4.6, 1), Vector2(4.6, 1), Vector2(3.2, -60), Vector2(-3.2, -60)]), 1), WOOD, 0.5, true)
	r.depth = 0.05
	r.piece(K.limb(Vector2(0, -57), Vector2(14, -57), 3.6, 3.6), WOOD_D, 0.3, true)
	var lamp := Vector2(14, -44)
	r.piece(K.rrect(lamp.x - 0.7, -57, lamp.x + 0.7, lamp.y - 6, 0.3), K.OUT, 0.0, false, 0.0, false)
	if lit and Settings.gfx_on("glow"):
		var gl := 0.5 + 0.5 * sin(t * 2.6)
		_glow_disc(r, lamp, 32.0 + gl * 3.0, Color(Palette.CYAN, 0.1), 2)
	r.depth = 0.2
	r.piece(K.rrect(lamp.x - 6.4, lamp.y - 8, lamp.x + 6.4, lamp.y + 8, 2.0), Color("e6f7fb") if lit else Color("8a8f99"), 0.4 if not lit else 0.0, true)
	r.piece(PackedVector2Array([Vector2(lamp.x - 7.4, lamp.y - 8), Vector2(lamp.x + 7.4, lamp.y - 8), Vector2(lamp.x, lamp.y - 14)]), IRON, 0.3, true)
	if lit:
		r.op(func(ci): ci.draw_circle(lamp, 3.6, Color(1, 1, 1, 0.95)))

static func _chair(r: K.Rec, ctx: Dictionary) -> void:
	var occ: bool = ctx.get("occupied", false)
	var wood := WOOD.lerp(GOLD, 0.25 if occ else 0.0)
	r.depth = 0.0
	for lx in [-9.0, 9.0]:
		r.piece(K.rrect(lx - 1.6, -5, lx + 1.6, 3, 0.4), WOOD_D, 0.2, false)
	r.depth = 0.1
	r.piece(K.soft(PackedVector2Array([Vector2(-12, -15), Vector2(12, -15), Vector2(10, -4), Vector2(-10, -4)]), 1), wood, 0.45, true)
	r.depth = 0.05
	r.piece(K.soft(PackedVector2Array([Vector2(-10.5, -14), Vector2(10.5, -14), Vector2(9.5, -36), Vector2(-9.5, -36)]), 1), wood.darkened(0.12), 0.45, true)
	if occ:
		_glow_disc(r, Vector2(0, -22), 26.0, Color(GOLD, 0.10), 1)

static func _chest(r: K.Rec, ctx: Dictionary) -> void:
	var opened: bool = ctx.get("variant", 0) == 1
	var t: float = ctx.get("t", 0.0)
	var wood := Color("a9743f")
	var dark := Color("6e4824")
	var band := Color("cdb67c")
	r.depth = 0.0
	if not opened and Settings.gfx_on("glow"):
		_glow_disc(r, Vector2(0, -20), 22.0 + sin(t * 3.0) * 2.0, Color(GOLD, 0.07), 1)
	if opened:
		r.piece(K.soft(PackedVector2Array([Vector2(-17, -17), Vector2(17, -17), Vector2(14, -35), Vector2(-14, -35)]), 1), dark, 0.4, true)
	r.depth = 0.1
	r.piece(K.soft(PackedVector2Array([Vector2(-18, 1), Vector2(18, 1), Vector2(18, -17), Vector2(-18, -17)]), 1), wood, 0.5, true)
	for bx in [-9.0, 9.0]:
		r.depth = 0.12
		r.piece(K.rrect(bx - 2.6, -17, bx + 2.6, 1, 0.6), band, 0.3, true)
	r.depth = 0.2
	if opened:
		r.piece(PackedVector2Array([Vector2(-15, -19), Vector2(15, -19), Vector2(15, -16), Vector2(-15, -16)]), Color(1.0, 0.92, 0.55), 0.0, false, 0.0, false)
	else:
		r.piece(K.soft(PackedVector2Array([Vector2(-19, -17), Vector2(19, -17), Vector2(16, -28), Vector2(-16, -28)]), 1), wood.lightened(0.08), 0.5, true)
		r.piece(K.rrect(-3.4, -24, 3.4, -14, 1.0), GOLD, 0.4, true)

# --- Sword, anvil ------------------------------------------------------------------------------
static func _sword(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var pulse := 0.75 + 0.25 * sin(t * 2.4)
	_glow_disc(r, Vector2(0, -6), 34.0, Color(GOLD, 0.06 * pulse))
	var off := Vector2(0, -4 + sin(t * 1.6) * 2.0)
	var a := Vector2(-22, 6) + off
	var b := Vector2(26, -14) + off
	var dir := (b - a).normalized()
	var perp := dir.orthogonal()
	r.depth = 0.0
	r.piece(PackedVector2Array([a + perp * 3.4, b, a - perp * 3.4]), Color(0.86, 0.9, 0.95), 0.5, true)
	r.piece(K.limb(a, a - dir * 11.0, 4.6, 4.6), WOOD, 0.4, true)
	r.depth = 0.1
	var gc := a + dir * 4.0
	r.piece(K.limb(gc + perp * 9.0, gc - perp * 9.0, 3.6, 3.6), Color("b99a4a"), 0.4, true)
	r.op(func(ci):
		for i in 5:
			var ph := fmod(t * 0.5 + i * 0.37, 1.0)
			ci.draw_circle(Vector2(-16 + i * 9, -8 - ph * 34.0), 1.8, Color(GOLD, (1.0 - ph) * 0.9)))

static func _anvil(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-13, 1), Vector2(13, 1), Vector2(9, -11), Vector2(-9, -11)]), 1), IRON.darkened(0.2), 0.5, true)
	r.piece(PackedVector2Array([Vector2(-7, -10), Vector2(7, -10), Vector2(5, -21), Vector2(-5, -21)]), IRON.darkened(0.1), 0.4, true)
	r.depth = 0.1
	r.piece(K.soft(PackedVector2Array([Vector2(-24, -20), Vector2(17, -20), Vector2(25, -27), Vector2(-14, -30), Vector2(-25, -26)]), 1), IRON, 0.5, true)
	r.op(func(ci): ci.draw_line(Vector2(-16, -25), Vector2(12, -26), Color(1, 1, 1, 0.4), 1.8))
	# the hammer, frozen mid-strike
	var hc := Vector2(2, -66 + sin(t * 0.9) * 0.8)
	r.depth = 0.2
	r.piece(K.limb(hc + Vector2(-16, 18), hc + Vector2(12, -10), 4.8, 4.8), WOOD, 0.4, true)
	r.piece(PackedVector2Array([hc + Vector2(6, -22), hc + Vector2(27, -6), hc + Vector2(18, 5), hc + Vector2(-3, -12)]), Color("8e95a6"), 0.5, true, 0.0, true, 1)
	r.op(func(ci):
		for i in 16:
			var a := TAU * i / 16.0
			var rr := 14.0 + fmod(i * 7.3, 26.0)
			var p := Vector2(cos(a) * rr * 1.2, -34 - fmod(i * 11.0, 46.0) - sin(a) * rr * 0.25)
			var tw := 0.6 + 0.4 * sin(t * 2.0 + i)
			ci.draw_circle(p, 4.5, Color(Palette.CYAN, 0.10 * tw))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(2, 0), p + Vector2(0, 3), p + Vector2(-2, 0)]), Color("ffb347", 0.95)))

# --- Portal, rift, gate ------------------------------------------------------------------------
static func _portal(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var c := Vector2(0, -36)
	_glow_disc(r, c, 40.0, Color(Palette.CYAN, 0.08))
	r.depth = 0.0
	r.piece(K.rrect(-24, -70, 24, -3, 1.0), Color("141a2c"), 0.0, false, 0.0, false)
	r.op(func(ci):
		ci.draw_circle(c, 24.0, Color(0.04, 0.05, 0.12, 0.92))
		for arm in 5:
			var pts := PackedVector2Array()
			var a0 := arm * TAU / 5.0 + t * 1.6
			for k in 14:
				var rr := 2.0 + k * 1.75
				pts.append(c + Vector2(cos(a0 + rr * 0.14), sin(a0 + rr * 0.14)) * rr)
			ci.draw_polyline(pts, Color(Palette.CYAN if arm % 2 == 0 else Palette.GLITCH, 0.9), 2.4, true))
	r.depth = 0.2
	r.piece(K.soft(PackedVector2Array([Vector2(-28, 1), Vector2(-17, 1), Vector2(-17, -70), Vector2(-28, -70)]), 1), STONE_D, 0.5, true)
	r.piece(K.soft(PackedVector2Array([Vector2(17, 1), Vector2(28, 1), Vector2(28, -70), Vector2(17, -70)]), 1), STONE_D.darkened(0.12), 0.5, true)
	r.piece(K.soft(PackedVector2Array([Vector2(-32, -68), Vector2(32, -68), Vector2(30, -82), Vector2(-30, -82)]), 1), STONE, 0.5, true)
	r.op(func(ci):
		for y in [-20.0, -45.0]:
			ci.draw_line(Vector2(-27, y), Vector2(-18, y), Color(K.OUT, 0.5), 1.0)
			ci.draw_line(Vector2(18, y + 8), Vector2(27, y + 8), Color(K.OUT, 0.5), 1.0))

static func _rift(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	var el := PackedVector2Array()
	var er := PackedVector2Array()
	for k in 9:
		var y := lerpf(0.0, -92.0, k / 8.0)
		var w := 2.5 + sin(k / 8.0 * PI) * (13.0 + pulse * 2.0)
		var jag := (1.8 if k % 2 == 0 else -1.8) * (0.0 if k == 0 or k == 8 else 1.0)
		el.append(Vector2(-w + jag, y))
		er.append(Vector2(w - jag, y))
	var pts := PackedVector2Array()
	pts.append_array(el)
	er.reverse()
	pts.append_array(er)
	_glow_disc(r, Vector2(0, -46), 38.0, Color(1, 1, 1, 0.06 + 0.04 * pulse), 1)
	r.depth = 0.0
	r.piece(pts, Color("f6f3ea"), 0.35, true)
	r.op(func(ci):
		for k in 6:
			var y := -10.0 - k * 14.0
			ci.draw_line(Vector2(-4, y), Vector2(4, y - 6), Color("c0405a", 0.7), 1.5)
		ci.draw_polyline(el, Color("c0405a", 0.6 + 0.3 * pulse), 1.4))

static func _gate(r: K.Rec, ctx: Dictionary) -> void:
	var open_: bool = ctx.get("variant", 0) == 1
	var t: float = ctx.get("t", 0.0)
	r.depth = 0.3
	for sx in [-34.0, 34.0]:
		r.piece(K.soft(PackedVector2Array([Vector2(sx - 8, 1), Vector2(sx + 8, 1), Vector2(sx + 6.5, -98), Vector2(sx - 6.5, -98)]), 1), STONE_D, 0.5, true)
	r.piece(K.soft(PackedVector2Array([Vector2(-46, -96), Vector2(46, -96), Vector2(41, -110), Vector2(-41, -110)]), 1), STONE, 0.5, true)
	r.depth = 0.0
	if open_:
		var pulse := 0.5 + 0.5 * sin(t * 1.6)
		r.piece(K.rrect(-27, -95, 27, 0, 0.5), Color(1, 1, 1, 0.6 + 0.2 * pulse), 0.0, false, 0.0, false)
		r.op(func(ci):
			for k in 6:
				var y := -10.0 - k * 15.0
				ci.draw_line(Vector2(-22, y), Vector2(22, y - 4), Color(Palette.CYAN, 0.4), 1.6))
	else:
		for i in 6:
			var x0 := -27.0 + i * 9.0
			r.piece(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 9, 0), Vector2(x0 + 9, -95), Vector2(x0, -95)]), Color("f1e7cd") if i % 2 == 0 else Color("e0d2ac"), 0.3, false, 0.0, true)
		r.depth = 0.1
		r.piece(K.rrect(-28, -64, 28, -59, 1.0), Color("a8483f"), 0.3, true)
		r.piece(K.rrect(-28, -32, 28, -27, 1.0), Color("a8483f"), 0.3, true)
		r.depth = 0.2
		r.piece(K.ell(Vector2(0, -46), 8.5, 8.5, 14), K.OUT, 0.0, false)

# --- Book, table, oven ---------------------------------------------------------------------------
static func _book(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var glow := 0.5 + 0.5 * sin(t * 2.0)
	_glow_disc(r, Vector2(0, -6), 54.0, Color(Palette.CYAN, 0.06 + 0.03 * glow))
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-39, -12), Vector2(39, -12), Vector2(39, 8), Vector2(0, 17), Vector2(-39, 8)]), 1), Color("5b3a6a"), 0.4, true)
	r.depth = 0.1
	r.piece(PackedVector2Array([Vector2(0, -6), Vector2(-34, -14), Vector2(-34, 4), Vector2(0, 12)]), PAGE, 0.3, true)
	r.piece(PackedVector2Array([Vector2(0, -6), Vector2(34, -14), Vector2(34, 4), Vector2(0, 12)]), PAGE.darkened(0.08), 0.3, false)
	r.depth = 0.2
	r.piece(PackedVector2Array([Vector2(4, -4), Vector2(30, -11), Vector2(30, 1), Vector2(4, 8)]), Color(Palette.CYAN.lightened(0.5), 0.5 + 0.35 * glow), 0.0, false, 0.0, false)
	r.op(func(ci):
		for i in 4:
			ci.draw_line(Vector2(-30 + i * 2, -10 + i * 4), Vector2(-6, -4 + i * 4), Color(WOOD_D, 0.5), 1.2)
		ci.draw_polyline(PackedVector2Array([Vector2(34, -14), Vector2(31, -8), Vector2(35, -3), Vector2(32, 4)]), Color(K.OUT, 0.9), 1.8)
		for i in 4:
			var ph := fmod(t * 0.5 + i * 0.27, 1.0)
			ci.draw_circle(Vector2(8 + i * 6, -8 - ph * 40.0), 1.8, Color(Palette.CYAN, (1.0 - ph) * 0.9)))

static func _table(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var n: int = ctx.get("table_len", 5)
	var w := clampf(float(ctx.get("warmth", 0.0)), 0.0, 1.0)
	var h := n * 0.5
	var lf := 26.0
	var cloth := Color("7d8aa3").lerp(Color("e2b560"), w)
	var wood := Color("5a4a44").lerp(WOOD, w)
	var tl := Iso.to_screen(Vector2(-h, -0.45)) + Vector2(0, -lf)
	var tr := Iso.to_screen(Vector2(h, -0.45)) + Vector2(0, -lf)
	var br := Iso.to_screen(Vector2(h, 0.45)) + Vector2(0, -lf)
	var bl := Iso.to_screen(Vector2(-h, 0.45)) + Vector2(0, -lf)
	r.depth = 0.0
	for lx in [-h + 0.3, h - 0.3]:
		for ly in [-0.35, 0.35]:
			var f := Iso.to_screen(Vector2(lx, ly))
			r.piece(K.rrect(f.x - 2.6, f.y - lf, f.x + 2.6, f.y, 0.8), wood.darkened(0.2), 0.3, false)
	r.depth = 0.1
	r.piece(PackedVector2Array([bl, br, br + Vector2(0, 9), bl + Vector2(0, 9)]), wood.darkened(0.12), 0.2, false)
	r.piece(PackedVector2Array([br, tr, tr + Vector2(0, 9), br + Vector2(0, 9)]), wood.darkened(0.3), 0.2, false)
	r.depth = 0.2
	r.piece(PackedVector2Array([tl, tr, br, bl]), cloth, 0.2, true)
	r.depth = 0.3
	r.op(func(ci):
		for i in range(n):
			var cx := -h + 0.5 + i
			for ly in [-0.2, 0.2]:
				var pc := Iso.to_screen(Vector2(cx, ly)) + Vector2(0, -lf - 1)
				var plate := DrawKit.ellipse(pc, 9.0, 4.5, 14)
				ci.draw_colored_polygon(plate, Color("e8e4dc").lerp(Color("f6ead0"), w))
				ci.draw_polyline(plate + PackedVector2Array([plate[0]]), Color(K.OUT, 0.7), 1.0)
				if w > 0.4:
					ci.draw_colored_polygon(DrawKit.ellipse(pc + Vector2(0, -2), 5.0, 3.0, 10), Color("c9893f", w))
		if w > 0.15:
			for cx in [-h + 0.8, 0.0, h - 0.8]:
				var cp := Iso.to_screen(Vector2(cx, 0.0)) + Vector2(0, -lf)
				ci.draw_circle(cp + Vector2(0, -16), 24.0, Color(GOLD, 0.10 * w))
				ci.draw_rect(Rect2(cp + Vector2(-2, -13), Vector2(4, 13)), Color("f4ecd6"))
				ci.draw_rect(Rect2(cp + Vector2(-2, -13), Vector2(4, 13)), Color(K.OUT, 0.9), false, 1.0)
				ci.draw_circle(cp + Vector2(0, -16), 3.6 + sin(t * 9.0 + cx) * 0.7, Color("ffd24a", w))
		else:
			for i in 6:
				var fp := tl.lerp(tr, 0.1 + i * 0.16) + Vector2(0, 4 + (i % 2) * 6)
				ci.draw_line(fp, fp + Vector2(3, 6), Color(0.85, 0.95, 1.0, 0.7), 1.6))

static func _oven(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var d := Iso.diamond(Vector2.ZERO, 1.7)
	var h := 46.0
	var up := Vector2(0, -h)
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	r.depth = 0.2
	r.piece(PackedVector2Array([Vector2(-6, -h - 6), Vector2(6, -h - 6), Vector2(6, -h - 36), Vector2(-6, -h - 36)]), STONE_D.darkened(0.1), 0.4, true)
	r.depth = 0.0
	r.piece(left, STONE.darkened(0.04), 0.14, true)
	r.piece(right, STONE.darkened(0.26), 0.14, false)
	r.piece(PackedVector2Array([d[3] + up, d[2] + up, d[1] + up, d[0] + up]), STONE.lightened(0.08), 0.3, true)
	r.depth = 0.1
	var mouth := DrawKit.face_quad(right, 0.25, 0.1, 0.75, 0.62)
	r.piece(mouth, Color("14121a"), 0.0, false)
	var m := (mouth[0] + mouth[2]) * 0.5 + Vector2(0, 8)
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	_glow_disc(r, m, 14.0 + pulse * 4.0, Color(Palette.CYAN, 0.12), 1)
	r.op(func(ci): ci.draw_circle(m, 3.0 + pulse, Color(Palette.CYAN.lightened(0.5), 0.95)))
	r.op(func(ci):
		for i in 6:
			var u := 0.1 + i * 0.16
			ci.draw_line(DrawKit.face(left, u, 0.05), DrawKit.face(left, u, 0.95), Color(K.OUT, 0.25), 1.0))

# --- Puzzle furniture ----------------------------------------------------------------------------
static func _dummy(r: K.Rec, ctx: Dictionary) -> void:
	var rot: float = ctx.get("rot", 0.0)
	r.at(Vector2.ZERO, rot, 1.0)
	var sack := Color("c9ac75")
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-3.4, 1), Vector2(3.4, 1), Vector2(3, -42), Vector2(-3, -42)]), 1), WOOD, 0.5, true)
	r.depth = 0.1
	r.piece(K.soft(K.rrect(-24, -50, 24, -43, 1.6), 1), WOOD.lightened(0.1), 0.4, true)
	r.depth = 0.2
	r.piece(K.soft(_blob(Vector2(0, -32), 15.0, 19.0, 18, 0.08, 3.0), 1), sack, 0.55, true)
	r.op(func(ci):
		for rr in [11.0, 7.0, 3.0]:
			ci.draw_arc(Vector2(0, -32), rr, 0.0, TAU, 20, Color(Palette.CRITIC_RED, 0.9), 2.0, true)
		for i in 6:
			var x := -10.0 + i * 4.0
			ci.draw_line(Vector2(x, -14), Vector2(x + 2, -8), Color(K.OUT, 0.5), 1.1))
	r.depth = 0.3
	r.piece(K.soft(_blob(Vector2(0, -58), 10.0, 10.0, 14, 0.06, 7.0), 1), Color("d6bb85"), 0.55, true)
	r.op(func(ci):
		for sx in [-4.0, 4.0]:
			ci.draw_line(Vector2(sx - 2, -61), Vector2(sx + 2, -57), K.OUT, 1.5)
			ci.draw_line(Vector2(sx - 2, -57), Vector2(sx + 2, -61), K.OUT, 1.5)
		ci.draw_line(Vector2(-4, -53), Vector2(4, -53), K.OUT, 1.5))

static func _block(r: K.Rec, ctx: Dictionary) -> void:
	var tint: Color = ctx.get("tint", Color("b9a07a"))
	var height: float = ctx.get("height", 30.0)
	var d := Iso.diamond(Vector2.ZERO, 0.9)
	var up := Vector2(0, -height)
	var top := PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up])
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	r.depth = 0.0
	r.piece(left, tint.darkened(0.12), 0.1, true)
	r.piece(right, tint.darkened(0.32), 0.1, false)
	r.depth = 0.1
	r.piece(top, tint.lightened(0.12), 0.3, true)
	r.op(func(ci):
		for i in range(1, int(height / 9.0)):
			var o := Vector2(0, -i * 9.0)
			ci.draw_line(d[3] + o, d[2] + o, Color(1, 0.95, 0.8, 0.3), 1.0)
			ci.draw_line(d[2] + o, d[1] + o, Color(1, 0.95, 0.8, 0.16), 1.0))

static func _plate(r: K.Rec, ctx: Dictionary, echo: bool) -> void:
	var pressed: bool = ctx.get("pressed", false)
	var t: float = ctx.get("t", 0.0)
	var d := Iso.diamond(Vector2.ZERO, 0.9)
	var inset := Iso.diamond(Vector2.ZERO, 0.62)
	var base := Color("3a4a5e") if echo else Color("5b5f70")
	var glow := (Palette.CYAN if echo else Palette.GOLD) if pressed else (Color("5f7488") if echo else Color("8a8fa3"))
	if pressed:
		_glow_disc(r, Vector2.ZERO, 30.0 + sin(t * 4.0) * 3.0, Color(glow, 0.12), 1)
	r.depth = 0.0
	r.piece(d, base.darkened(0.15), 0.2, true)
	r.depth = 0.1
	r.piece(inset, glow.darkened(0.05 if pressed else 0.3), 0.0, false)
	r.depth = 0.2
	if echo:
		var col := Color(1, 1, 1, 0.9) if pressed else Color(Palette.PAPER_LIGHT, 0.5)
		r.op(func(ci):
			var ring := func(rad: float, w: float):
				var pts := PackedVector2Array()
				for i in 25:
					pts.append(Vector2(cos(TAU * i / 24.0) * rad, sin(TAU * i / 24.0) * rad * 0.5))
				ci.draw_polyline(pts, col, w, true)
			ring.call(12.0, 2.2)
			ring.call(5.0, 1.8))
	else:
		var col2 := K.OUT if pressed else Color(Palette.PAPER_LIGHT, 0.65)
		r.op(func(ci):
			for dx in [-0.7, 0.7]:
				ci.draw_string(ThemeDB.get_default_theme().default_font, Vector2(-8 + dx, 8), "B", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, col2))
