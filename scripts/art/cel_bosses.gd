class_name CelBosses
extends RefCounted
## Ink Cel bosses. Same rules as everyone else (heavy outer contour, one cel shadow, rim light) at a larger
## scale. Each boss keeps the silhouette that already tells you what it is: the Critic is a red ink spirit
## with quill claws, the Spoiler a floating book with exclamation-mark eyes, the Cold Shoulder a hunched
## ice figure that turns its shoulder to you, the Scissor-Man half a coloured man and half a sketch.

const K := preload("res://scripts/art/cel_kit.gd")

static func build(r: K.Rec, kind: String, ctx: Dictionary) -> void:
	r.alpha = float(ctx.get("fade", 1.0))
	match kind:
		"critic": _critic(r, ctx)
		"spoiler": _spoiler(r, ctx)
		"cold_shoulder": _cold(r, ctx)
		"scissor_man": _scissor(r, ctx)

static func _blob(c: Vector2, rx: float, ry: float, n: int, jit: float, seed_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + (fposmod(sin((seed_v + i) * 12.9898) * 43758.5453, 1.0) - 0.5) * jit
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts

# ---------------------------------------------------------------------------------------------------
static func _critic(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var layers: int = ctx.get("layers", 3)
	var tele: float = ctx.get("tele", 0.0)
	var rest: bool = ctx.get("state", "") == "rest"
	var boil := floorf(t * 8.0)
	var RED := Color("b32d28").lerp(Color("d96a52"), 0.18 if rest else 0.0)
	var DARK := Color("3d0a10")
	var INKB := Color("14111a")
	r.out = INKB
	var fl := flash * 2.0
	# drips under the body
	r.depth = 0.0
	for i in 5:
		var x := -22.0 + i * 11.0
		var l := 8.0 + fmod(float(i) * 7.3 + t * 12.0, 14.0)
		r.piece(K.limb(Vector2(x, -12), Vector2(x, -12 + l), 6.0, 4.0), RED, 0.2, false, fl, true, 1)
	# arms with quill claws
	r.depth = 0.2
	for sgn in [-1.0, 1.0]:
		var wob := sin(t * 2.2 + sgn) * 4.0
		var sh := Vector2(sgn * 26.0, -70.0)
		var elbow := Vector2(sgn * 56.0, -52.0 + wob)
		var hand := Vector2(sgn * 48.0, -22.0 + wob * 1.4)
		r.piece(K.limb(sh, elbow, 10.0, 8.0), RED.darkened(0.12), 0.3, true, fl, true, 1)
		r.piece(K.limb(elbow, hand, 8.0, 6.4), RED.darkened(0.06), 0.3, true, fl, true, 1)
		for k in 3:
			var tip := hand + Vector2(sgn * (6.0 + k * 5.0), 14.0 + k * 3.0)
			r.piece(PackedVector2Array([hand + Vector2(-2.4, 0), hand + Vector2(3.4, 0), tip]), Color("2a0c10"), 0.0, false, 0.0, true, 0)
	# the body: a tall tear of red ink with a hollow of dark where its face lives
	r.depth = 0.5
	r.piece(K.soft(_blob(Vector2(0, -52), 30.0, 46.0, 22, 0.2, boil), 1), RED, 0.35, true, fl)
	r.piece(K.soft(_blob(Vector2(-4, -50), 17.0, 30.0, 18, 0.28, boil + 5.0), 1), DARK, 0.0, false)
	# ink plates peel away as memories are held up
	r.depth = 0.7
	for i in layers:
		var a0 := t * (0.6 + i * 0.25) + i * TAU / 3.0
		var rad := 55.0 + i * 7.0
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for k in 9:
			var a := a0 + 1.7 * k / 8.0
			outer.append(Vector2(0, -52) + Vector2(cos(a) * (rad + 4.0), sin(a) * (rad + 4.0) * 0.86))
		for k in range(8, -1, -1):
			var a2 := a0 + 1.7 * k / 8.0
			inner.append(Vector2(0, -52) + Vector2(cos(a2) * (rad - 4.0), sin(a2) * (rad - 4.0) * 0.86))
		outer.append_array(inner)
		r.piece(outer, RED.lightened(0.12), 0.3, true, fl, true, 0)
	# face: two white slits and a jagged mouth that opens when it is about to shout
	r.depth = 0.9
	var open := 3.0 + (4.0 if tele > 0.0 else 0.0)
	r.op(func(ci):
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, -80), Vector2(-4, -76), Vector2(-5, -72.5), Vector2(-17, -77)]), Color.WHITE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(16, -80), Vector2(4, -76), Vector2(5, -72.5), Vector2(17, -77)]), Color.WHITE)
		var mouth := PackedVector2Array()
		for i in 9:
			mouth.append(Vector2(-14.0 + i * 3.5, -62.0 + (open if i % 2 == 0 else -open * 0.3)))
		ci.draw_polyline(mouth, Color.WHITE, 2.2, true))

# ---------------------------------------------------------------------------------------------------
static func _spoiler(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var flap := sin(t * 2.6)
	var COVER := Color("2a1a4a")
	var GOLD := Color("ffd24a")
	var PAGE := Color("f3e7c9")
	var PAGE_SH := Color("e4d3a8")
	r.out = Color("14111a")
	var fl := flash * 2.0
	if Settings.gfx_on("glow"):
		r.glow(func(ci):
			for a in 3:
				var ang := t * 1.8 + a * TAU / 3.0
				ci.draw_arc(Vector2(0, -12), 84.0 + a * 6.0, ang, ang + 1.0, 10, Color(Palette.GLITCH, 0.55), 2.4, true))
	# the cover
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-68, 15), Vector2(68, 15), Vector2(62, -42), Vector2(-62, -42)]), 1), COVER, 0.35, true, fl)
	r.op(func(ci):
		ci.draw_polyline(PackedVector2Array([Vector2(-60, 9), Vector2(60, 9), Vector2(56, -36), Vector2(-56, -36), Vector2(-60, 9)]), Color(GOLD, 0.65), 1.4, true))
	# the two flapping pages, hinged at the spine
	r.depth = 0.2
	for side in [-1.0, 1.0]:
		var f: float = flap * side * -1.0 if side > 0.0 else flap
		var tip := Vector2(side * 58.0, -28.0 - f * 18.0)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(side * 4.0, -34.0), tip + Vector2(0, -34.0), tip + Vector2(side * 4.0, 6.0)])
		r.piece(pts, (PAGE if side < 0.0 else PAGE_SH), 0.25, true, fl, true, 1)
		r.op(func(ci):
			for i in 5:
				var tt := 0.15 + i * 0.16
				var a: Vector2 = pts[0].lerp(pts[3], tt).lerp(pts[1].lerp(pts[2], tt), 0.15)
				var b: Vector2 = pts[0].lerp(pts[3], tt).lerp(pts[1].lerp(pts[2], tt), 0.85)
				var cut := fmod(floor(t * 6.0) * 0.37 + i * 0.21, 1.0)
				ci.draw_line(a, a.lerp(b, cut), Color(Palette.SPOILER_INK, 0.55), 1.6)
				ci.draw_line(a.lerp(b, minf(cut + 0.12, 1.0)), b, Color(Palette.SPOILER_INK, 0.55), 1.6))
	r.piece(K.rrect(-3.0, -42.0, 3.0, 12.0, 2.0), Color("14101f"), 0.0, false)
	# the torn-out last page, flapping loose beside it
	r.depth = 0.3
	r.piece(PackedVector2Array([Vector2(70, -4), Vector2(96, -16 + flap * 6.0), Vector2(100, 14), Vector2(92, 22), Vector2(86, 12), Vector2(78, 26), Vector2(72, 14)]), PAGE, 0.3, true, fl, true, 0)
	r.op(func(ci): ci.draw_string(ThemeDB.get_default_theme().default_font, Vector2(80, 6), "END", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Palette.CRITIC_RED))
	# eyes: gold exclamation marks, because it cannot stop telling you things
	r.depth = 0.6
	for ex in [-22.0, 22.0]:
		var wob := sin(t * 5.0 + ex) * 1.5
		r.piece(K.soft(K.rrect(ex - 3.4, -36 + wob, ex + 3.4, -19 + wob, 2.6), 1), GOLD, 0.35, true, fl, true, 0)
		r.piece(K.ell(Vector2(ex, -11 + wob), 3.8, 3.8, 10), GOLD, 0.35, false)

# ---------------------------------------------------------------------------------------------------
static func _cold(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var face: Vector2 = ctx.get("face", Vector2(1, 0))
	var weak: bool = ctx.get("weak", false)
	var warmed: bool = ctx.get("warmed", false)
	var rest: bool = ctx.get("state", "") == "rest"
	var ICE := Color("cfe9f7") if not rest else Color("e8f6ff")
	var ICE_D := Color("8cc4e4")
	r.out = Color("14202e")
	var fl := flash * 2.0
	var bob := sin(t * 1.6) * 2.5
	var fx := signf(face.x) if absf(face.x) > 0.1 else 1.0
	if Settings.gfx_on("glow"):
		r.glow(func(ci): ci.draw_circle(Vector2(0, -50), 54.0, Color(0.6, 0.85, 1.0, 0.1)))
	# legs and long cold coat, hem pooling on the floor
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(26, -56), Vector2(-26, -56)]), 1), ICE_D, 0.35, true, fl)
	# hunched torso leaning away from you, back toward the camera side opposite `face`
	r.depth = 0.2
	r.piece(K.soft(PackedVector2Array([Vector2(-30, -22), Vector2(30, -22), Vector2(32 * -fx, -74 + bob), Vector2(10 * -fx, -96 + bob), Vector2(-26 * -fx, -80 + bob)]), 2), ICE, 0.4, true, fl)
	# the back: a patch of thinner ice. It glows gold when it can be struck.
	if weak or rest:
		var wc := Vector2(-fx * 18.0, -62 + bob)
		r.glow(func(ci): ci.draw_circle(wc, 15.0 + 3.0 * sin(t * 6.0), Color(Palette.GOLD, 0.7)))
		r.piece(K.ell(wc, 9.0, 11.0, 12), Color(Palette.GOLD, 0.9), 0.0, false)
	# hood and bowed head, sunk between the shoulders
	r.depth = 0.4
	var hc := Vector2(fx * 8.0, -98 + bob)
	r.piece(K.ell(hc, 17.0, 18.0, 20), Color("b9dcef"), 0.4, true, fl)
	r.piece(K.ell(hc + Vector2(fx * 5.0, 2.0), 9.0, 10.0, 14), Color("1a2a3c"), 0.0, false)
	r.op(func(ci):
		ci.draw_circle(hc + Vector2(fx * 8.0, 0), 1.6, Color("dff4ff"))
		ci.draw_circle(hc + Vector2(fx * 2.0, 0), 1.6, Color("dff4ff")))
	# arms folded across the chest, hugging itself
	r.depth = 0.6
	r.piece(K.limb(Vector2(-fx * 22.0, -66 + bob), Vector2(fx * 16.0, -52 + bob), 9.0, 7.0), ICE, 0.4, true, fl)
	# the great shoulder plate of ice, turned toward you
	r.depth = 0.8
	var sc := Vector2(fx * 26.0, -84 + bob)
	r.piece(PackedVector2Array([sc + Vector2(-fx * 16.0, -22), sc + Vector2(fx * 22.0, -26), sc + Vector2(fx * 32.0, 6), sc + Vector2(fx * 4.0, 36), sc + Vector2(-fx * 20.0, 8)]), Color("eaf7ff"), 0.3, true, fl, true, 1)
	r.op(func(ci):
		ci.draw_line(sc + Vector2(-6, -10), sc + Vector2(fx * 14.0, 8), Color(0.5, 0.75, 0.95, 0.9), 1.6)
		ci.draw_line(sc + Vector2(fx * 2.0, -20), sc + Vector2(fx * 8.0, -4), Color(0.5, 0.75, 0.95, 0.7), 1.2))
	if warmed:
		r.op(func(ci):
			for i in 5:
				ci.draw_circle(Vector2(-20 + i * 10, -140 - fmod(t * 30.0 + i * 11.0, 30.0)), 2.6, Color(Palette.CYAN, 0.7)))

# ---------------------------------------------------------------------------------------------------
static func _scissor(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var snip: float = ctx.get("snip", 0.0)
	var jam: bool = ctx.get("jam", false)
	var sway := sin(t * 1.6) * 2.0
	var BLUE := Color("2f4a7a")
	var PENCIL := Color("c3c8d6")
	var INKB := Color("14111a")
	var fl := flash * 1.5
	r.out = INKB
	# legs: one inked and filled, one only sketched
	r.depth = 0.0
	r.piece(K.soft(PackedVector2Array([Vector2(-17, 0), Vector2(-4, 0), Vector2(-6, -52), Vector2(-19, -52)]), 1), BLUE, 0.35, true, fl)
	var legR := PackedVector2Array([Vector2(4, 0), Vector2(17, 0), Vector2(19, -52), Vector2(6, -52)])
	r.op(func(ci):
		ci.draw_polyline(PackedVector2Array([legR[0], legR[1], legR[2], legR[3], legR[0]]), PENCIL, 1.8, true)
		for i in 5:
			ci.draw_line(legR[3].lerp(legR[0], 0.1 + i * 0.2), legR[2].lerp(legR[1], 0.1 + i * 0.2), Color(PENCIL, 0.55), 1.0))
	# coat: left half coloured, right half still being drawn
	r.depth = 0.3
	r.piece(K.soft(PackedVector2Array([Vector2(-23, -44), Vector2(0, -44), Vector2(0, -94), Vector2(-27, -94)]), 1), BLUE, 0.35, true, fl)
	r.op(func(ci):
		ci.draw_polyline(PackedVector2Array([Vector2(0, -44), Vector2(23, -44), Vector2(27, -94), Vector2(0, -94)]), PENCIL, 1.8, true)
		for i in 8:
			var y := -48.0 - i * 5.6
			ci.draw_line(Vector2(2, y), Vector2(24 - i * 0.3, y - 3), Color(PENCIL, 0.6), 1.0))
	# a tailor's tape across the chest
	r.depth = 0.5
	var t0 := Vector2(-25, -88)
	var t1 := Vector2(25, -54)
	r.piece(K.limb(t0, t1, 7.0, 7.0), Color("e8c860"), 0.3, true, fl, true, 0)
	r.op(func(ci):
		for i in 10:
			var tp := t0.lerp(t1, i / 9.0)
			ci.draw_line(tp, tp + Vector2(-1.6, -3.6), Color(INKB, 0.75), 1.1))
	# head: a round sketch with two button eyes and a pincushion
	r.depth = 0.7
	var hc := Vector2(sway * 0.5, -110)
	r.piece(K.ell(hc, 15.5, 17.5, 20), Color("e9d7c0"), 0.25, true, fl)
	r.piece(K.ell(hc + Vector2(0, -19), 8.0, 6.0, 12), Palette.CRITIC_RED.lightened(0.1), 0.3, true, fl)
	r.op(func(ci):
		for ex in [-6.0, 6.0]:
			ci.draw_circle(hc + Vector2(ex, -2), 4.4, Color("1a1a24"))
			ci.draw_line(hc + Vector2(ex - 1.8, -3.8), hc + Vector2(ex + 1.8, -0.2), Color.WHITE, 1.0)
			ci.draw_line(hc + Vector2(ex - 1.8, -0.2), hc + Vector2(ex + 1.8, -3.8), Color.WHITE, 1.0)
		ci.draw_line(hc + Vector2(-6, 9), hc + Vector2(6, 9), Color(INKB, 0.85), 1.6)
		for pin in [-4.0, 0.0, 4.0]:
			ci.draw_line(hc + Vector2(pin, -20), hc + Vector2(pin * 1.6, -33), Color("e8e8f0"), 1.5)
			ci.draw_circle(hc + Vector2(pin * 1.6, -33), 1.7, Color("d9a830")))
	# the shears: rabbit-ear blades that close for a snip, and cross and stick when jammed
	r.depth = 0.9
	var open := 1.0 - snip
	var shoulder := Vector2(0, -80)
	var lang := lerpf(-PI * 0.5 - 0.06, -PI * 0.5 - 1.0, open)
	var rang := lerpf(-PI * 0.5 + 0.06, -PI * 0.5 + 1.0, open)
	if jam:
		lang = -PI * 0.5 + 0.18 + sin(t * 30.0) * 0.03
		rang = -PI * 0.5 - 0.18 - sin(t * 30.0) * 0.03
	var steel := Color("c8ced9").lerp(Color.WHITE, flash * 3.0)
	for side in [-1.0, 1.0]:
		var base := shoulder + Vector2(side * 24.0, 0)
		var ang: float = lang if side < 0.0 else rang
		var d := Vector2.from_angle(ang)
		var n := d.orthogonal()
		var tip := base + d * 74.0
		r.piece(PackedVector2Array([base + n * 5.5, base + d * 40.0 + n * 4.0, tip, base + d * 38.0 - n * 3.0, base - n * 5.5]), steel if side < 0.0 else steel.darkened(0.12), 0.3, true, 0.0, true, 0)
		r.piece(K.ell(base - d * 5.0, 6.0, 6.0, 10), Color("3a3f4a"), 0.3, true)
