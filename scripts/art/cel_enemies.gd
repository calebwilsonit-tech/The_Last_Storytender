class_name CelEnemies
extends RefCounted
## Ink Cel enemies. The Errors split into two families that the line colour tells apart at a glance:
##  - the REDACTED (Mite, Dangler, Censor, Ellipsis): near-black bodies with a pale lavender outline and white
##    eyes, like the batch-3 reference sheet;
##  - the TYPOS (Bare, Slug): soft coloured bodies with the normal near-black outline.
## Proofreading one (proof 0..1) warms it up and swaps its outline to near-black, so you can see the fix land.
## Figures face right and are mirrored by ctx.face.

const K := preload("res://scripts/art/cel_kit.gd")
const PALE := Color("e4dcf7")
const VOID := Color("1c1427")
const VIOLET := Color("6a4fa0")

static func build(r: K.Rec, kind: String, ctx: Dictionary) -> void:
	match kind:
		"bare": _bare(r, ctx)
		"mite": _mite(r, ctx)
		"slug": _slug(r, ctx)
		"dangler": _dangler(r, ctx)
		"censor": _censor(r, ctx)
		"ellipsis": _ellipsis(r, ctx)

static func _out_for(ctx: Dictionary) -> Color:
	var p: float = ctx.get("proof", 0.0)
	if ctx.get("friendly", false):
		p = 1.0
	return PALE.lerp(Color("14111a"), p)

# ----------------------------------------------------------------------------------------------------
static func _bare(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var proof: float = 1.0 if ctx.get("friendly", false) else ctx.get("proof", 0.0)
	var state: String = ctx.get("state", "idle")
	var flash: float = ctx.get("flash", 0.0)
	var skin := Color("c9a89d")
	var fur := Color("8b6340")
	var c := skin.lerp(fur, proof)
	var belly := Color("d8b5aa").lerp(Color("c8a574"), proof)
	var tele := state == "windup"
	var rear := -4.0 if tele else 0.0
	var bob := sin(t * (3.0 if state == "chase" else 1.6)) * 1.3
	r.out = Color("14111a")
	var fl := flash * 4.0
	# legs
	r.depth = 0.0
	r.piece(K.soft(K.rrect(-16, -15 + bob, -6, 0, 3.0), 1), c.darkened(0.14), 0.4, true, fl, true, 1)
	r.piece(K.soft(K.rrect(7, -15 + bob, 19, 0, 3.0), 1), c.darkened(0.1), 0.4, true, fl, true, 1)
	r.depth = 0.2
	# the far arm hangs behind the body
	r.piece(K.limb(Vector2(-10 + rear, -36 + bob), Vector2(-14 + rear, -20 + bob), 8.0, 6.5), c.darkened(0.2), 0.4, false, fl, true, 1)
	# hunched body
	r.depth = 0.4
	r.piece(K.ell(Vector2(-2 + rear, -30 + bob), 25.0, 21.0, 22), c, 0.3, true, fl)
	r.piece(K.ell(Vector2(2 + rear, -26 + bob), 14.0, 14.0, 18), belly, 0.25, false, fl)
	# wrinkles when broken, fur tufts once proofread
	var wr := 1.0 - proof
	r.op(func(ci):
		for i in 5:
			var y := -38.0 + i * 5.0 + bob
			ci.draw_line(Vector2(-18 + rear, y), Vector2(-9 + rear, y + 2), Color(0.45, 0.22, 0.22, 0.55 * wr), 1.2)
		if proof > 0.05:
			for i in 9:
				var a := TAU * i / 9.0
				var p := Vector2(-2 + rear, -30 + bob) + Vector2(cos(a) * 24.5, sin(a) * 20.5)
				var tip := p + Vector2(cos(a), sin(a)) * 5.5 * proof
				ci.draw_line(p, tip, c.darkened(0.3), 2.2))
	# head, ears, snout
	r.depth = 0.6
	var hc := Vector2(17 + rear * 0.4, -44 + bob)
	r.piece(K.ell(hc + Vector2(-6, -11), 4.8, 4.8, 10), c.darkened(0.08), 0.3, true, fl)
	r.piece(K.ell(hc + Vector2(5, -11), 4.8, 4.8, 10), c.darkened(0.08), 0.3, true, fl)
	r.piece(K.ell(hc, 13.5, 12.5, 18), c, 0.3, true, fl)
	r.piece(K.ell(hc + Vector2(9, 4), 8.4, 6.4, 14), belly, 0.25, true, fl)
	r.op(func(ci):
		ci.draw_circle(hc + Vector2(14.5, 2.2), 2.3, Color("14111a"))
		var eye := Color(0.12, 0.06, 0.1).lerp(Palette.CYAN, proof)
		ci.draw_circle(hc + Vector2(1, -2), 2.4, eye)
		ci.draw_circle(hc + Vector2(8, -2), 2.4, eye)
		if proof > 0.4:
			ci.draw_circle(hc + Vector2(1.6, -2.8), 0.8, Color.WHITE)
			ci.draw_circle(hc + Vector2(8.6, -2.8), 0.8, Color.WHITE))
	# the near arm with claws
	r.depth = 0.8
	var ar := hc + Vector2(-4, 10)
	r.piece(K.limb(Vector2(11 + rear, -36 + bob), ar + Vector2(10, 14), 8.4, 7.0), c.darkened(0.06), 0.4, true, fl, true, 1)
	if tele or state == "lunge":
		r.op(func(ci):
			for k in 3:
				ci.draw_line(ar + Vector2(10, 14), ar + Vector2(17 + k * 3, 22 + k * 2), Color("efe3c4"), 2.0))

# ----------------------------------------------------------------------------------------------------
static func _mite(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var seed_v: float = ctx.get("seed", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var hop := absf(sin(t * 9.0 + seed_v)) * 6.0
	var c := Vector2(0, -14 - hop)
	r.out = PALE
	var boil := int(t * 12.0)
	if Settings.gfx_on("glow"):
		r.glow(func(ci): ci.draw_circle(c, 19.0, Color(Palette.GLITCH, 0.22)))
	# six spindly legs
	r.depth = 0.0
	for i in 6:
		var a := TAU * i / 6.0 + t * 3.0
		var base := c + Vector2(cos(a), sin(a) * 0.9) * 10.0
		var tip := c + Vector2(cos(a + 0.35), sin(a + 0.35) * 0.9) * 19.0
		r.piece(K.limb(base, tip, 3.4, 2.2), PALE.darkened(0.12), 0.0, false, 0.0, true, 0)
	r.depth = 0.5
	r.piece(K.ell(c, 12.8, 12.2, 20), VOID.lerp(Color.WHITE, flash * 4.0), 0.0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = boil * 131 + int(seed_v * 100.0)
	var lines: Array = []
	for i in 9:
		var pts := PackedVector2Array()
		var a0 := rng.randf() * TAU
		for k in 7:
			var a := a0 + k * 1.25
			var rr := rng.randf_range(3.0, 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		lines.append(pts)
	r.op(func(ci):
		var n := 0
		for pts in lines:
			ci.draw_polyline(pts, Color(VIOLET, 0.95) if n % 3 != 0 else Color(0.02, 0.01, 0.05, 0.95), 1.5, true)
			n += 1
		for i in 12:
			var a := TAU * i / 12.0 + float(boil) * 0.4
			ci.draw_line(c + Vector2(cos(a), sin(a)) * 11.5, c + Vector2(cos(a + 0.3), sin(a + 0.3)) * 14.5, Color(PALE, 0.7), 1.2)
		ci.draw_circle(c + Vector2(-3.2, -1), 1.9, Color.WHITE)
		ci.draw_circle(c + Vector2(3.2, -1), 1.9, Color.WHITE))

# ----------------------------------------------------------------------------------------------------
static func _slug(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var proof: float = 1.0 if ctx.get("friendly", false) else ctx.get("proof", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var c := Color("8a9d6a").lerp(Color("c9d08a"), proof)
	r.out = Color("14111a")
	var fl := flash * 4.0
	var seg := 4
	r.depth = 0.0
	for i in seg:
		var k := float(seg - 1 - i)
		var wob := sin(t * 3.0 + k) * 2.0
		var rad := 15.0 - i * 1.4
		r.depth = float(i) * 0.1
		r.piece(K.ell(Vector2(-26.0 + i * 15.0, -12.0 + wob), rad, rad * 0.82, 16), c.darkened(0.04 * k), 0.4, true, fl)
	var head := Vector2(36, -14 + sin(t * 4.0))
	r.depth = 0.6
	r.piece(K.ell(head, 11.5, 10.5, 16), c.lightened(0.05), 0.4, true, fl)
	r.op(func(ci):
		for sx in [-4.0, 5.0]:
			var tip := head + Vector2(sx + 2, -22 + sin(t * 5.0 + sx))
			ci.draw_line(head + Vector2(sx, -8), tip, K.OUT, 3.4)
			ci.draw_line(head + Vector2(sx, -8), tip, c.darkened(0.15), 1.6)
			ci.draw_circle(tip + Vector2(0, -1), 4.2, K.OUT)
			ci.draw_circle(tip + Vector2(0, -1), 3.2, Color.WHITE)
			ci.draw_circle(tip + Vector2(1.0, -1), 1.5, K.OUT)
		ci.draw_arc(head + Vector2(3, 3), 3.4, 0.3, PI - 0.3, 8, K.OUT, 1.2, true))
	# the run-on sentence along its back
	r.op(func(ci):
		var font := ThemeDB.get_default_theme().default_font
		var txt := "and then and then and then" if not ctx.get("friendly", false) else "and then. and then."
		ci.draw_string(font, Vector2(-34, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.05, 0.1, 0.05, 0.75)))

# ----------------------------------------------------------------------------------------------------
static func _dangler(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var seed_v: float = ctx.get("seed", 0.0)
	var proof: float = 1.0 if ctx.get("friendly", false) else ctx.get("proof", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var sway := sin(t * 1.7 + seed_v) * 5.0
	var top := Vector2(0, -92)
	var body := Vector2(sway, -38 + sin(t * 2.3) * 3.0)
	var c := Color("2a2438").lerp(Color("5a6f8a"), proof)
	r.out = _out_for(ctx)
	var out := r.out
	r.depth = 0.0
	r.op(func(ci):
		ci.draw_line(top + Vector2(sway * 0.3, 0), body + Vector2(0, -16), Color(out, 0.9), 1.6)
		ci.draw_circle(top + Vector2(sway * 0.3, 0), 2.6, out))
	var fl := flash * 4.0
	r.depth = 0.3
	r.piece(PackedVector2Array([body + Vector2(-5, 12), body + Vector2(7, 12), body + Vector2(4, 28), body + Vector2(-2, 34), body + Vector2(-9, 33)]), c.darkened(0.12), 0.0, false, fl, true, 2)
	r.depth = 0.5
	r.piece(K.ell(body, 15.5, 17.5, 20), c, 0.0, false, fl)
	r.piece(K.soft(PackedVector2Array([body + Vector2(-13, -2), body + Vector2(-6, -15), body + Vector2(5, -17), body + Vector2(-2, -8)]), 1), c.lightened(0.14), 0.0, false, 0.0, false)
	r.op(func(ci):
		for ex in [-5.0, 5.0]:
			ci.draw_circle(body + Vector2(ex, -4), 3.8, Color.WHITE)
			ci.draw_circle(body + Vector2(ex + 1, -4), 1.7, Color("14111a"))
		if float(ctx.get("tele", 0.0)) > 0.0:
			ci.draw_circle(body + Vector2(10, -2), 6.0 + sin(t * 30.0) * 1.5, Color(1.0, 0.45, 0.35, 0.8)))

# ----------------------------------------------------------------------------------------------------
static func _censor(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var bob := sin(t * 2.0) * 1.5
	var robe := Color("2b2b3a")
	r.out = PALE
	var fl := flash * 4.0
	r.depth = 0.0
	# long thin arms with claws, hanging from the shoulders
	for side in [-1.0, 1.0]:
		var sh := Vector2(side * 10.0, -48.0 + bob)
		var hand := Vector2(side * 17.0 + sin(t * 1.4 + side) * 1.5, -22.0 + bob)
		r.piece(K.limb(sh, hand, 5.0, 3.6), robe.lightened(0.05), 0.0, false, fl, true, 1)
		r.op(func(ci):
			for k in 3:
				ci.draw_line(hand, hand + Vector2(side * (2.0 + k * 2.4), 7.0 + k * 1.2), PALE, 1.4))
	r.depth = 0.3
	# the robe
	r.piece(K.soft(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(12, -34), Vector2(11, -52 + bob), Vector2(-11, -52 + bob), Vector2(-12, -34)]), 1), robe, 0.0, false, fl)
	r.op(func(ci):
		ci.draw_line(Vector2(-1, -48 + bob), Vector2(0, -6), Color(VIOLET, 0.5), 1.0))
	# the pale mask of a face, with two dark eyes
	r.depth = 0.6
	r.piece(K.ell(Vector2(0, -62 + bob), 11.0, 12.5, 18), Color("e8e0d0"), 0.0, false, fl)
	r.op(func(ci):
		for ex in [-4.0, 4.0]:
			ci.draw_circle(Vector2(ex, -64 + bob), 1.9, Color("14111a")))

# ----------------------------------------------------------------------------------------------------
static func _ellipsis(r: K.Rec, ctx: Dictionary) -> void:
	if ctx.get("phase", "visible") == "gone":
		return
	var t: float = ctx.get("t", 0.0)
	var flash: float = ctx.get("flash", 0.0)
	var pinned: bool = ctx.get("pinned", false)
	r.out = PALE
	var fl := flash * 4.0
	if Settings.gfx_on("glow"):
		r.glow(func(ci):
			for i in 3:
				ci.draw_circle(Vector2(-18 + i * 18, -14), 15.0, Color(1, 1, 1, 0.08)))
	for i in 3:
		var hop := absf(sin(t * 6.0 + i * 0.9)) * (3.0 if pinned else 9.0)
		var ctr := Vector2(-18 + i * 18, -14 - hop)
		r.depth = float(i) * 0.1
		r.piece(K.ell(ctr, 9.4, 9.0, 16), VOID, 0.0, false, fl)
		r.op(func(ci):
			ci.draw_circle(ctr + Vector2(-2.2, -1), 1.7, Color.WHITE)
			ci.draw_circle(ctr + Vector2(2.2, -1), 1.7, Color.WHITE))
