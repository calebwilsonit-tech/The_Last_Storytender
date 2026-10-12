extends ArtStyle
## INK CEL: the look of the reference sheets in docs/art_reference. Chunky, slightly top-heavy proportions,
## one heavy near-black silhouette outline with thin inner lines, muted cel colours with one shadow tone
## and a thin rim light from the upper left, solemn faces (a pool of shadow with two pale glints).
##
## Figures are small PAPER DOLLS IN THREE DIMENSIONS: every part has a lateral and a forward offset from
## the body's centre, and the whole doll is turned to any facing angle (front, three-quarter, side, back
## and everything between) by projecting those offsets. Parts are painted far to near, so the same
## model walks, turns and looks right from all eight directions, including straight at the camera.

const K := preload("res://scripts/art/cel_kit.gd")

const HOOD := Color("7b6048")
const HOOD_IN := Color("1b1620")
const TUNIC := Color("a08564")
const CLOAK := Color("57432f")
const PANTS := Color("52607e")
const BOOT := Color("5d4129")
const SKIN := Color("e3bc98")
const PACK := Color("87623f")
const SCROLL := Color("dccb9f")
const BELT := Color("4a3424")
const IRON := Color("3a3f4a")
const GLASS := Color("6fe3ff")

func _init() -> void:
	id = "cel"
	title = "Ink Cel"
	blurb = "Chunky cel-shaded characters with heavy ink outlines, from the reference sheets."

func kinds() -> Array:
	return ["storytender", "garrick", "pip", "maud", "young_garrick", "wren", "guest", "bare", "mite", "slug", "dangler", "censor", "ellipsis", "critic", "spoiler", "cold_shoulder", "scissor_man"]

func draw_character(ci: CanvasItem, kind: String, ctx: Dictionary) -> bool:
	match kind:
		"storytender":
			_storytender(ci, ctx)
			return true
		"garrick", "pip", "maud", "young_garrick", "wren", "guest":
			_person(ci, kind, ctx)
			return true
		"bare", "mite", "slug", "dangler", "censor", "ellipsis":
			_enemy(ci, kind, ctx)
			return true
		"critic", "spoiler", "cold_shoulder", "scissor_man":
			_boss(ci, kind, ctx)
			return true
	return false

func draw_prop(ci: CanvasItem, kind: String, ctx: Dictionary) -> bool:
	if not CelProps.kinds().has(kind):
		return false
	_z = float(ctx.get("scale", 1.0))
	_origin = ctx.get("origin", Vector2.ZERO)
	_mirror = 1.0
	var r := K.Rec.new()
	r.inner = 1.1
	r.outer = 2.0
	CelProps.build(r, kind, ctx)
	_flush(ci, r)
	return true

func _boss(ci: CanvasItem, kind: String, ctx: Dictionary) -> void:
	_z = float(ctx.get("scale", 1.0))
	_origin = ctx.get("origin", Vector2.ZERO)
	_mirror = 1.0
	var r := K.Rec.new()
	r.inner = 1.1
	r.outer = 2.2
	CelBosses.build(r, kind, ctx)
	_flush(ci, r)

func _enemy(ci: CanvasItem, kind: String, ctx: Dictionary) -> void:
	_z = float(ctx.get("scale", 1.0))
	_origin = ctx.get("origin", Vector2.ZERO)
	_mirror = float(ctx.get("face", 1.0))
	var r := K.Rec.new()
	r.inner = 1.0
	r.outer = 1.9
	CelEnemies.build(r, kind, ctx)
	_flush(ci, r)
	_mirror = 1.0

func _person(ci: CanvasItem, kind: String, ctx: Dictionary) -> void:
	var sp: Dictionary = CelPeople.guest_spec(int(ctx.get("variant", 0))) if kind == "guest" else CelPeople.spec(kind)
	_z = float(ctx.get("scale", 1.0)) * float(sp.get("k", 1.0))
	_origin = ctx.get("origin", Vector2.ZERO)
	var r := K.Rec.new()
	r.inner = 1.0
	r.outer = 1.9
	CelPeople.build(r, sp, _phi(ctx), float(ctx.get("t", 0.0)), ctx)
	_flush(ci, r)

# --- transform plumbing ---------------------------------------------------------------------------
var _z := 1.0
var _origin := Vector2.ZERO
var _mirror := 1.0            # -1 draws a right-facing figure facing left

func _apply(ci: CanvasItem, xf: Dictionary) -> void:
	var pv: Vector2 = xf["pivot"]
	var sx: float = xf.get("sx", 1.0)
	ci.draw_set_transform(_origin + Vector2(pv.x * _mirror, pv.y) * _z, float(xf["rot"]) * _mirror, Vector2(sx * _mirror * _z, _z))

func _flush(ci: CanvasItem, r: K.Rec) -> void:
	r.flush(ci, func(xf): _apply(ci, xf))
	ci.draw_set_transform(_origin, 0.0, Vector2(_z, _z))

# --- facing -----------------------------------------------------------------------------------------
## The turn angle of the doll: 0 = facing the camera, +90 = facing screen right, 180 = facing away.
func _phi(ctx: Dictionary) -> float:
	if ctx.has("dir"):
		var d: Vector2 = ctx["dir"]
		if d.length() > 0.01:
			return atan2(d.x, d.y)
	var fx := 1.0 if ctx.get("facing_right", true) else -1.0
	var fy := -1.0 if ctx.get("facing_back", false) else 1.0
	return atan2(fx * 0.8, fy * 0.6)

# --- the Storytender -------------------------------------------------------------------------------
func _storytender(ci: CanvasItem, ctx: Dictionary) -> void:
	_z = float(ctx.get("scale", 1.0))
	_origin = ctx.get("origin", Vector2.ZERO)
	var r := K.Rec.new()
	r.inner = 1.0
	r.outer = 1.9
	if ctx.get("crumpled", false):
		_crumpled(r, ctx)
		_flush(ci, r)
		return
	var phi := _phi(ctx)
	var t: float = ctx.get("t", 0.0)
	var moving: bool = ctx.get("moving", false)
	var ph: float = ctx.get("phase", 0.0)
	var sneak: bool = ctx.get("sneaking", false)
	var bob := -absf(sin(ph)) * 2.0 if moving else sin(t * 1.8) * 0.55
	var by := bob + (3.0 if sneak else 0.0)
	_doll(r, phi, t, moving, ph, by, ctx)
	_flush(ci, r)

func _doll(r: K.Rec, phi: float, t: float, moving: bool, ph: float, by: float, ctx: Dictionary) -> void:
	var c := cos(phi)
	var s := sin(phi)
	var ac := absf(c)
	var as_ := absf(s)
	var sway := sin(t * 2.0) * 0.8 + (sin(ph * 2.0) * 1.2 if moving else 0.0)
	var swing: float = ctx.get("swing", 0.0)
	# projection of a body-local (lateral, forward) offset to screen x, and its depth (near = large)
	var px := func(xl: float, zl: float) -> float: return xl * c + zl * s
	var dp := func(xl: float, zl: float) -> float: return zl * c - xl * s
	# ---- cloak: hangs behind the whole body
	r.depth = dp.call(0.0, -5.5) - 0.2
	var cw := sqrt(pow(9.6 * c, 2) + pow(5.5 * s, 2)) + 1.0
	var cx: float = px.call(0.0, -5.0)
	var hem_w := sqrt(pow(13.0 * c, 2) + pow(6.5 * s, 2)) + 1.2
	r.piece(PackedVector2Array([
		Vector2(cx - cw, -38 + by), Vector2(cx + cw, -38 + by), Vector2(cx + hem_w + sway * 0.3, -22), Vector2(cx + hem_w * 0.9 + sway * 0.6, -11),
		Vector2(cx + hem_w * 0.55 + sway, -6.5), Vector2(cx + hem_w * 0.15 + sway * 0.8, -10.5), Vector2(cx - hem_w * 0.3 + sway, -5.5),
		Vector2(cx - hem_w * 0.65 + sway, -10.5), Vector2(cx - hem_w * 0.95 + sway * 0.6, -6.5), Vector2(cx - hem_w, -23)]), CLOAK, 0.5, true, 0.0, true, 1)
	if ac < 0.55 or c < 0:
		var seam: float = cx
		r.op(func(ci): ci.draw_line(Vector2(seam + sway * 0.3, -36 + by), Vector2(seam + sway * 0.5, -12), Color(K.OUT, 0.55), 1.0))
	# ---- backpack and bedroll
	r.depth = dp.call(0.0, -10.5)
	var pcx: float = px.call(0.0, -10.2)
	var pw := sqrt(pow(6.4 * c, 2) + pow(4.2 * s, 2)) + 0.8
	r.piece(K.rrect(pcx - pw, -37.5 + by, pcx + pw, -21 + by, 4.0), PACK, 0.45, true, 0.0, true, 1)
	if c < 0.2:
		r.piece(K.rrect(pcx - pw * 0.7, -30.5 + by, pcx + pw * 0.7, -24 + by, 2.0), PACK.lightened(0.1), 0.4, false, 0.0, true, 1)
		r.op(func(ci): ci.draw_line(Vector2(pcx - pw, -33 + by), Vector2(pcx + pw, -33 + by), Color(K.OUT, 0.6), 1.0))
	var rl := 7.4 * ac + 3.0 * as_ + 1.0
	r.piece(K.ell(Vector2(pcx, -41 + by), rl, 3.4, 16), SCROLL, 0.5)
	for e in [-1.0, 1.0]:
		var ex: float = px.call(e * 7.0, -10.2)
		if as_ > 0.25 or ac > 0.5:
			r.piece(K.ell(Vector2(ex, -41 + by), 2.5 + 0.7 * as_, 3.4, 10), SCROLL.lightened(0.06), 0.35, false)
	# ---- legs (walk swings them along the facing direction)
	for side in [-1.0, 1.0]:
		var sw := sin(ph + (0.0 if side > 0.0 else PI))
		var zl_f: float = sw * 5.0 if moving else 0.0
		var lift := maxf(0.0, -sw) * 3.0 if moving else 0.0
		var xl: float = side * 3.7
		r.depth = dp.call(xl, zl_f) - 0.05
		var hip := Vector2(px.call(xl, 0.0), -22.0 + by * 0.5)
		var ankle := Vector2(px.call(xl, zl_f), -9.0 - lift + zl_f * c * 0.4)
		r.piece(K.limb(hip, ankle, 7.8, 6.8), PANTS if side > 0 else PANTS.darkened(0.1), 0.45, true, 0.0, true, 1)
		var bw := 3.6 + 0.5 * ac
		var toe := 7.0 * s
		var left := ankle.x - bw + minf(0.0, toe)
		var right := ankle.x + bw + maxf(0.0, toe)
		var boot := PackedVector2Array([
			Vector2(ankle.x - bw, ankle.y - 3.0), Vector2(ankle.x + bw, ankle.y - 3.0), Vector2(right, ankle.y + 2.0),
			Vector2(right, ankle.y + 9.0 + 1.5 * c), Vector2(left, ankle.y + 9.0 + 1.5 * c), Vector2(left, ankle.y + 2.0)])
		r.piece(boot, BOOT if side > 0 else BOOT.darkened(0.1), 0.4, true, 0.0, true, 1)
	# ---- torso
	r.depth = 0.0
	var tw := sqrt(pow(9.8 * c, 2) + pow(6.4 * s, 2)) + 0.9
	var lean := 1.0 if moving else 0.0
	r.piece(PackedVector2Array([
		Vector2(-tw * 0.72 + lean * s, -38.5 + by), Vector2(tw * 0.72 + lean * s, -38.5 + by), Vector2(tw, -31 + by), Vector2(tw * 1.08, -19 + by * 0.5),
		Vector2(-tw * 1.08, -19 + by * 0.5), Vector2(-tw, -31 + by)]), TUNIC, 0.42, true, 0.0, true, 1)
	r.piece(K.rrect(-tw * 1.08, -25 + by * 0.6, tw * 1.08, -21 + by * 0.5, 1.2), BELT, 0.3, false)
	if c > -0.15:
		var bx: float = px.call(0.0, 6.4)
		r.op(func(ci): ci.draw_rect(Rect2(bx - 1.8, -24.6 + by * 0.6, 3.6, 3.0), Color("c9a24e")))
	r.piece(PackedVector2Array([Vector2(-tw * 0.82, -40.5 + by), Vector2(tw * 0.82, -40.5 + by), Vector2(tw * 0.74, -36.4 + by),
		Vector2(px.call(0.0, 2.0), -33.5 + by), Vector2(-tw * 0.74, -36.4 + by)]), CLOAK.darkened(0.06), 0.4, false, 0.0, true, 1)
	# ---- far arm (character's right): hangs, or holds the weapon
	var f_sh := Vector2(px.call(-8.0, 0.0), -35 + by)
	var f_hand_l := Vector2(-9.4, 0.8)
	var f_y := -25.5 + by
	if swing > 0.0:
		f_hand_l = Vector2(-4.0, 6.0)
		f_y = -31.0 + by
	var f_hand := Vector2(px.call(f_hand_l.x, f_hand_l.y), f_y)
	r.depth = dp.call(f_hand_l.x, f_hand_l.y) - 0.1
	r.piece(K.limb(f_sh, f_hand, 6.0, 5.2), TUNIC.darkened(0.24), 0.45, false, 0.0, true, 1)
	r.piece(K.ell(f_hand, 2.9, 2.9, 10), SKIN.darkened(0.12), 0.35, false)
	_weapon(r, ctx.get("weapon", "stub"), f_hand, swing, s)
	# ---- near arm (character's left) carries the lantern out in front
	var n_sh := Vector2(px.call(8.2, 0.0), -35 + by)
	var n_el := Vector2(px.call(10.6, 3.0), -30.6 + by + sway * 0.3)
	var hx := 10.0 + 4.0 * maxf(0.0, -c)          # from behind the lantern swings out so the light stays visible
	var n_hand := Vector2(px.call(hx, 7.6), -26.4 + by + sway * 0.5)
	r.depth = maxf(dp.call(hx, 7.6), -0.15)
	r.piece(K.limb(n_sh, n_el, 6.6, 6.0), TUNIC, 0.4, true, 0.0, true, 1)
	r.piece(K.limb(n_el, n_hand, 6.0, 5.2), TUNIC.lightened(0.04), 0.4, true, 0.0, true, 1)
	r.piece(K.limb(n_hand + (n_el - n_hand).normalized() * 2.4, n_hand, 5.6, 5.6), BELT, 0.3, false, 0.0, true, 1)
	r.piece(K.ell(n_hand + Vector2(0.0, 1.6), 3.0, 3.0, 10), SKIN, 0.35, false)
	_lantern(r, n_hand + Vector2(0.4, 2.6), t_of(ctx), moving, ph, ctx)
	# ---- head: hood, the pool of shadow, two glints
	_head(r, phi, by, t_of(ctx), px, dp)

func t_of(ctx: Dictionary) -> float:
	return float(ctx.get("t", 0.0))

func _head(r: K.Rec, phi: float, by: float, t: float, px: Callable, dp: Callable) -> void:
	var c := cos(phi)
	var s := sin(phi)
	var hb := by * 0.9
	r.depth = 0.6
	var hw := sqrt(pow(12.6 * c, 2) + pow(13.6 * s, 2)) + 0.4
	var tip_x: float = px.call(-1.2, -6.5)
	var hood := PackedVector2Array([
		Vector2(-hw * 0.78, -36.5 + hb), Vector2(-hw, -44 + hb), Vector2(-hw * 0.96, -53 + hb), Vector2(-hw * 0.6 + tip_x * 0.4, -60 + hb),
		Vector2(tip_x, -64.5 + hb), Vector2(hw * 0.2 + tip_x * 0.3, -62 + hb), Vector2(hw * 0.72, -55.5 + hb), Vector2(hw, -46 + hb),
		Vector2(hw * 0.82, -37.5 + hb), Vector2(hw * 0.2, -35 + hb), Vector2(-hw * 0.4, -35 + hb)])
	r.piece(hood, HOOD, 0.4, true, 0.0, true, 2)
	if c > 0.0:
		# the opening faces the camera side of the hood
		var ox: float = px.call(0.0, 7.2)
		var ow := 8.0 * c + 1.0
		r.piece(K.ell(Vector2(ox, -46.2 + hb), ow, 10.4, 18), HOOD_IN, 0.0, false)
		var pulse := 0.8 + 0.2 * sin(t * 1.7)
		var sep := 3.5 * c
		var eyes: Array = []
		if c > 0.25:
			eyes = [-1.0, 1.0]
		else:
			eyes = [1.0] if s > 0.0 else [-1.0]
		for e in eyes:
			var ex: float = ox + (e * sep if c > 0.25 else 0.0) + (0.0 if c > 0.25 else (1.4 * signf(s)))
			var gx := ex
			r.op(func(ci):
				ci.draw_circle(Vector2(gx, -46.4 + hb), 3.2, Color(GLASS, 0.18 * pulse))
				ci.draw_colored_polygon(K.ell(Vector2(gx, -46.4 + hb), 1.35, 1.9, 10), Color("c8f6ff", pulse)))
	else:
		# from behind: the hood is closed, with a seam and a soft fold
		r.op(func(ci):
			ci.draw_line(Vector2(tip_x, -63.5 + hb), Vector2(px.call(0.0, -6.0) * 0.3, -37.5 + hb), Color(K.OUT, 0.55), 1.0)
			ci.draw_arc(Vector2(px.call(0.0, -3.0), -49 + hb), 9.0 * absf(c) + 1.0, 0.6, PI - 0.6, 10, K.shade_of(HOOD), 1.2, true))

func _weapon(r: K.Rec, weapon: String, at: Vector2, swing: float, s: float) -> void:
	var flip := 1.0 if s >= -0.05 else -1.0
	var ang := (-1.9 + (1.0 - swing) * 3.2) * flip if swing > 0.0 else -2.2 * flip
	r.at(at, ang, flip)
	match weapon:
		"sword":
			r.piece(PackedVector2Array([Vector2(0, -1.5), Vector2(17, -1.9), Vector2(21, 0.2), Vector2(17, 1.9), Vector2(0, 1.5)]), Color("c9cfd8"), 0.4)
			r.piece(K.rrect(-1.6, -4.6, 1.6, 4.6, 0.8), Color("8a6a40"), 0.3, false)
		"quill":
			r.piece(PackedVector2Array([Vector2(0, -0.8), Vector2(10, -4.6), Vector2(21, -2.6), Vector2(14, 2.6), Vector2(6, 1.6)]), Color("f1e6c8"), 0.4)
			r.op(func(ci): ci.draw_line(Vector2(-3, 0), Vector2(19, -0.4), K.OUT, 1.6))
			r.op(func(ci): ci.draw_circle(Vector2(-4.0, 0.0), 1.3, GLASS))
		_:
			r.piece(PackedVector2Array([Vector2(0, -2.0), Vector2(11, -2.0), Vector2(15.0, 0.0), Vector2(11, 2.0), Vector2(0, 2.0)]), Color("e3b84a"), 0.4)
			r.piece(PackedVector2Array([Vector2(-3.4, -2.0), Vector2(0, -2.0), Vector2(0, 2.0), Vector2(-3.4, 2.0)]), Color("e49aa5"), 0.3, false)
			r.op(func(ci): ci.draw_colored_polygon(PackedVector2Array([Vector2(12.6, -0.9), Vector2(14.9, 0.0), Vector2(12.6, 0.9)]), K.OUT))
	r.reset()

func _lantern(r: K.Rec, hand: Vector2, t: float, moving: bool, ph: float, ctx: Dictionary) -> void:
	var flick: float = ctx.get("flick", 1.0)
	var on: bool = ctx.get("lantern_on", false)
	var swing_a := sin(t * 1.9) * 0.05 + (sin(ph) * 0.14 if moving else 0.0)
	r.at(hand, swing_a)
	var glow := 0.55 + 0.45 * flick if on else 0.72 * flick
	if Settings.gfx_on("glow"):
		r.glow(func(ci):
			for k in 4:
				ci.draw_circle(Vector2(0, 10), 22.0 - k * 4.5, Color(GLASS, (0.04 + 0.018 * k) * glow)))
	r.op(func(ci): ci.draw_arc(Vector2(0, -1.0), 2.4, PI, TAU, 8, K.OUT, 1.6, true))
	r.piece(PackedVector2Array([Vector2(-3.4, 0.5), Vector2(3.4, 0.5), Vector2(5.0, 3.4), Vector2(-5.0, 3.4)]), IRON, 0.4, true)
	r.piece(K.rrect(-4.6, 3.4, 4.6, 14.0, 1.0), GLASS.lerp(Color.WHITE, 0.25 * glow), 0.0, false)
	r.op(func(ci):
		ci.draw_colored_polygon(K.ell(Vector2(0, 8.8), 3.2, 4.0, 10), Color(1, 1, 1, 0.55 * glow))
		ci.draw_line(Vector2(-4.6, 3.4), Vector2(4.6, 14.0), IRON, 1.4)
		ci.draw_line(Vector2(4.6, 3.4), Vector2(-4.6, 14.0), IRON, 1.4))
	r.piece(PackedVector2Array([Vector2(-5.4, 14.0), Vector2(5.4, 14.0), Vector2(4.2, 17.0), Vector2(-4.2, 17.0)]), IRON, 0.4, true)
	r.reset()

func _crumpled(r: K.Rec, ctx: Dictionary) -> void:
	var t: float = ctx.get("t", 0.0)
	var wob := sin(t * 1.4) * 0.4
	r.piece(PackedVector2Array([
		Vector2(-13, -5), Vector2(-9, -13 + wob), Vector2(-2, -17), Vector2(6, -14), Vector2(12, -8), Vector2(11, -1), Vector2(3, 1), Vector2(-7, 1)]), Color("e9dcc0"), 0.5)
	r.op(func(ci):
		for f in [
			[Vector2(-9, -13 + wob), Vector2(-2, -7), Vector2(-7, 1)],
			[Vector2(-2, -17), Vector2(3, -8), Vector2(6, -14)],
			[Vector2(3, -8), Vector2(11, -1), Vector2(12, -8)]]:
			ci.draw_polyline(PackedVector2Array(f), Color(K.OUT, 0.5), 1.1, true))
	r.piece(PackedVector2Array([Vector2(-4, -15 + wob), Vector2(-1, -23), Vector2(4, -17), Vector2(2, -13)]), HOOD, 0.4)
	r.op(func(ci): ci.draw_circle(Vector2(5.5, -9), 1.5, Color(Palette.INK, 0.8)))
