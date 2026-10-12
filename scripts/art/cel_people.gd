class_name CelPeople
extends RefCounted
## The Ink Cel human rig: the same three-dimensional paper doll as the Storytender, parameterised so
## Garrick, Pip, Maud, villagers and the Empty Table guests all share one construction (same outline,
## same shading, same face logic, same turn-to-any-angle projection). A spec dictionary says what makes
## each person themselves; this file never contains a person's name in the drawing code.

const K := preload("res://scripts/art/cel_kit.gd")

static func spec(kind: String) -> Dictionary:
	match kind:
		"garrick":
			return {
				"k": 1.0, "skin": Color("c8a98f"), "hair": Color("b9b5ad"), "hair_style": "fringe", "beard": Color("8f8c88"),
				"brow": 0.4, "mouth": -0.1, "eye_r": 1.2, "head_r": 12.6, "head_ry": 12.8, "torso_w": 11.0, "torso_d": 7.2,
				"shirt": Color("5d6272"), "sleeve": Color("5d6272"), "pants": Color("403b45"), "boots": Color("3b2b21"),
				"apron": Color("6b4a34"), "bracer": Color("8c919c"), "belly": 0.15, "held": "hammer", "cheeks": false,
			}
		"pip":
			return {
				"k": 0.82, "skin": Color("ebbd96"), "hair": Color("7c4c2a"), "hair_style": "tuft", "beard": Color(0, 0, 0, 0),
				"brow": 0.55, "mouth": 0.35, "eye_r": 1.5, "head_r": 13.4, "head_ry": 13.0, "torso_w": 8.8, "torso_d": 6.0,
				"shirt": Color("6f9fcf"), "sleeve": Color("6f9fcf"), "pants": Color("8b7a58"), "boots": Color("5a3f2b"),
				"apron": Color(0, 0, 0, 0), "bracer": Color(0, 0, 0, 0), "belly": 0.0, "held": "book", "cheeks": true,
			}
		"maud":
			return {
				"k": 1.0, "skin": Color("e2b592"), "hair": Color("c9c5bd"), "hair_style": "none", "beard": Color(0, 0, 0, 0),
				"brow": 0.3, "mouth": 0.3, "eye_r": 1.3, "head_r": 12.2, "head_ry": 12.4, "torso_w": 11.6, "torso_d": 7.6,
				"shirt": Color("efe4cf"), "sleeve": Color("efe4cf"), "pants": Color("5b4a44"), "boots": Color("4a3a30"),
				"apron": Color("fbf6e8"), "bracer": Color(0, 0, 0, 0), "belly": 0.35, "held": "loaf", "cheeks": true, "hat": "chef",
			}
		"young_garrick":
			var y := spec("garrick")
			y["skin"] = Color("d6b094"); y["hair"] = Color("4a3426"); y["hair_style"] = "tuft"; y["beard"] = Color(0, 0, 0, 0)
			y["mouth"] = 0.15; y["brow"] = 0.7; y["belly"] = 0.0; y["torso_w"] = 11.6
			return y
		"wren":
			return {
				"k": 0.9, "skin": Color("e6bf9c"), "hair": Color("3a2b30"), "hair_style": "tuft", "beard": Color(0, 0, 0, 0),
				"brow": 0.3, "mouth": 0.1, "eye_r": 1.4, "head_r": 12.4, "head_ry": 12.6, "torso_w": 10.0, "torso_d": 6.8,
				"shirt": Color("8a5e7a"), "sleeve": Color("8a5e7a"), "pants": Color("5a4a5e"), "boots": Color("4a3a30"),
				"apron": Color("b98ca8"), "bracer": Color(0, 0, 0, 0), "belly": 0.1, "held": "lantern", "cheeks": true,
			}
	return {}

## The Empty Table's guests: anonymous townsfolk, told apart by a hat, a scarf or a bonnet.
static func guest_spec(variant: int) -> Dictionary:
	var v := variant % 3
	var sp := {
		"k": 0.95, "skin": [Color("e2b592"), Color("c99d7c"), Color("efc7a2")][v], "hair": [Color("5a4636"), Color("2f2a33"), Color("a68a62")][v],
		"hair_style": ["none", "tuft", "none"][v], "beard": Color(0, 0, 0, 0),
		"brow": 0.3, "mouth": 0.2, "eye_r": 1.3, "head_r": 12.0, "head_ry": 12.2, "torso_w": 10.0 + v, "torso_d": 6.8,
		"shirt": [Color("7d6a52"), Color("6b7f6a"), Color("8a6a7a")][v], "sleeve": [Color("7d6a52"), Color("6b7f6a"), Color("8a6a7a")][v],
		"pants": Color("4a4048"), "boots": Color("3b2b21"), "apron": Color(0, 0, 0, 0), "bracer": Color(0, 0, 0, 0), "belly": 0.1, "held": "", "cheeks": true,
		"hat": ["bowler", "", "bonnet"][v], "scarf": [Color(0, 0, 0, 0), Color("b5483c"), Color(0, 0, 0, 0)][v],
	}
	return sp

## Builds one person into the recorder. `ctx` carries t, dir, restored (0..1), moving, phase, tearful.
static func build(r: K.Rec, sp: Dictionary, phi: float, t: float, ctx: Dictionary) -> void:
	var c := cos(phi)
	var s := sin(phi)
	var ac := absf(c)
	var as_ := absf(s)
	var rest: float = ctx.get("restored", 1.0)
	var mem: bool = ctx.get("memory", false)
	var g := func(col: Color) -> Color:
		if mem:
			# a remembered person: the same cel colours, washed through cyan light
			return col.lerp(Color(0.55, 0.85, 0.98), 0.42)
		return Palette.ghostify(col, rest).lerp(Palette.STATIC_GRAY, (1.0 - rest) * 0.35)
	var pen: Color = Palette.STATIC_GRAY.lightened(0.35).lerp(Palette.OUTLINE, rest)
	if mem:
		pen = Color("3a8fb5")
		r.alpha = 0.78 + 0.1 * sin(t * 3.0)
		if Settings.gfx_on("glow"):
			r.glow(func(ci):
				for k in 3:
					ci.draw_circle(Vector2(0, -26), 30.0 + k * 8.0, Color(Palette.CYAN, 0.05)))
	r.out = pen
	var px := func(xl: float, zl: float) -> float: return xl * c + zl * s
	var dp := func(xl: float, zl: float) -> float: return zl * c - xl * s
	var moving: bool = ctx.get("moving", false)
	var ph: float = ctx.get("phase", 0.0)
	var breathe := sin(t * 2.0) * 0.9
	var by := (-absf(sin(ph)) * 1.6 if moving else 0.0)
	var Wt: float = sp["torso_w"]
	var Dt: float = sp["torso_d"]
	var skin: Color = g.call(sp["skin"])
	# ---- legs
	for side in [-1.0, 1.0]:
		var sw := sin(ph + (0.0 if side > 0.0 else PI))
		var zl_f: float = sw * 4.0 if moving else 0.0
		var lift := maxf(0.0, -sw) * 2.4 if moving else 0.0
		var xl: float = side * 4.0
		r.depth = dp.call(xl, zl_f) - 0.05
		var hip := Vector2(px.call(xl, 0.0), -20.0 + by * 0.5)
		var ankle := Vector2(px.call(xl, zl_f), -7.0 - lift + zl_f * c * 0.35)
		r.piece(K.limb(hip, ankle, 8.4, 7.4), g.call(sp["pants"]) if side > 0 else (g.call(sp["pants"]) as Color).darkened(0.1), 0.45, true, 0.0, true, 1)
		var bw := 3.9 + 0.5 * ac
		var toe := 6.6 * s
		var left := ankle.x - bw + minf(0.0, toe)
		var right := ankle.x + bw + maxf(0.0, toe)
		r.piece(PackedVector2Array([
			Vector2(ankle.x - bw, ankle.y - 4.0), Vector2(ankle.x + bw, ankle.y - 4.0), Vector2(right, ankle.y + 1.6),
			Vector2(right, ankle.y + 6.6 + 1.2 * c), Vector2(left, ankle.y + 6.6 + 1.2 * c), Vector2(left, ankle.y + 2.0)]),
			g.call(sp["boots"]) if side > 0 else (g.call(sp["boots"]) as Color).darkened(0.1), 0.4, true, 0.0, true, 1)
	# ---- torso
	r.depth = 0.0
	var tw := sqrt(pow(Wt * c, 2) + pow(Dt * s, 2)) + 0.9
	var bulge: float = sp.get("belly", 0.0)
	var bw2 := tw * (1.0 + 0.1 * bulge)
	var top_y := -35.5 + breathe * 0.3
	r.piece(PackedVector2Array([
		Vector2(-tw * 0.7, top_y), Vector2(tw * 0.7, top_y), Vector2(tw * 0.98, -32), Vector2(bw2 * 1.05, -26), Vector2(bw2 * 1.02, -18.5),
		Vector2(-bw2 * 1.02, -18.5), Vector2(-bw2 * 1.05, -26), Vector2(-tw * 0.98, -32)]), g.call(sp["shirt"]), 0.3, true, 0.0, true, 1)
	# apron (front half only)
	var apron: Color = sp["apron"]
	if apron.a > 0.01 and c > -0.1:
		var ax: float = px.call(0.0, Dt)
		var aw := (Wt - 1.6) * (0.35 + 0.65 * ac)
		r.depth = 0.12
		r.piece(PackedVector2Array([
			Vector2(ax - aw * 0.78, -34.5), Vector2(ax + aw * 0.78, -34.5), Vector2(ax + aw, -28), Vector2(ax + aw * 1.05, -13.5), Vector2(ax - aw * 1.05, -13.5), Vector2(ax - aw, -28)]),
			g.call(apron), 0.26, true, 0.0, true, 1)
		r.op(func(ci): ci.draw_line(Vector2(ax - aw * 0.78, -34.5), Vector2(ax + aw * 0.78, -34.5), Color(pen, 0.6), 1.0))
		r.depth = 0.0
	var scarf: Color = sp.get("scarf", Color(0, 0, 0, 0))
	if scarf.a > 0.01:
		r.depth = 0.1
		r.piece(K.rrect(-tw * 0.82, -37.0, tw * 0.82, -32.4, 1.6), g.call(scarf), 0.4, true)
		r.piece(K.rrect(tw * 0.2, -34.0, tw * 0.62, -24.0, 1.2), g.call(scarf).darkened(0.08), 0.4, true)
		r.depth = 0.0
	# belt
	r.piece(K.rrect(-tw * 1.04, -22.4, tw * 1.04, -19.6, 1.0), (g.call(sp["pants"]) as Color).darkened(0.25), 0.3, false)
	# ---- arms
	var held: String = sp.get("held", "")
	_arms(r, sp, g, px, dp, c, s, Wt, Dt, t, breathe, held, pen)
	# ---- head
	_head(r, sp, g, px, dp, c, s, t, breathe, skin, pen, ctx)
	if mem:
		# the recording is slightly worn: scanline gaps
		r.depth = 5.0
		r.op(func(ci):
			for i in 9:
				var y := -52.0 + i * 6.0
				ci.draw_line(Vector2(-16, y), Vector2(16, y), Color(0.04, 0.06, 0.12, 0.18), 1.0))

static func _arms(r: K.Rec, sp: Dictionary, g: Callable, px: Callable, dp: Callable, c: float, s: float, Wt: float, Dt: float, t: float, breathe: float, held: String, pen: Color) -> void:
	var sleeve: Color = g.call(sp["sleeve"])
	var skin: Color = g.call(sp["skin"])
	var bracer: Color = sp["bracer"]
	for side in [-1.0, 1.0]:
		var near: bool = side > 0.0
		var sh := Vector2(px.call(side * (Wt - 1.4), 0.0), -33.2)
		var hl := Vector2(side * (Wt + 1.4), 1.5)
		var hy := -22.5 + breathe * 0.3
		var drop := 0.0
		if held == "book":
			hl = Vector2(side * 4.2, Dt + 1.6)
			hy = -27.0
		elif held == "loaf" and near:
			hl = Vector2(Wt + 1.0, 5.6)
			hy = -26.0
		elif held == "hammer" and near:
			hl = Vector2(Wt + 1.2, 3.4)
			hy = -22.0
		var hand := Vector2(px.call(hl.x, hl.y), hy)
		var elbow := sh.lerp(hand, 0.55) + Vector2(side * 0.8 * (1.0 - absf(c) * 0.0), 1.0)
		r.depth = dp.call(hl.x, hl.y) - 0.05
		var arm := sleeve if near else sleeve.darkened(0.12)
		r.piece(K.limb(sh, elbow, 5.8, 5.2), arm, 0.3, true, 0.0, true, 1)
		r.piece(K.limb(elbow, hand, 5.2, 4.8), arm.lightened(0.02), 0.3, true, 0.0, true, 1)
		if bracer.a > 0.01:
			r.piece(K.limb(hand + (elbow - hand).normalized() * 6.0, hand + (elbow - hand).normalized() * 1.5, 6.6, 6.6), g.call(bracer), 0.4, true, 0.0, true, 1)
		r.piece(K.ell(hand + Vector2(0, 1.4), 3.0, 3.0, 10), skin if near else skin.darkened(0.08), 0.35, false)
		if near or held == "book":
			_held_item(r, held, hand, c, s, g, pen)
	r.reset()

static func _held_item(r: K.Rec, held: String, hand: Vector2, c: float, s: float, g: Callable, pen: Color) -> void:
	match held:
		"lantern":
			r.depth += 0.2
			var lp := hand + Vector2(0, 6.0)
			r.glow(func(ci): ci.draw_circle(lp, 13.0, Color(1, 0.9, 0.6, 0.2)))
			r.piece(K.rrect(lp.x - 3.0, lp.y - 4.0, lp.x + 3.0, lp.y + 4.0, 1.0), Color("ffe9a8"), 0.2, true)
		"hammer":
			var flip := 1.0 if s >= -0.05 else -1.0
			r.at(hand + Vector2(0, 1.0), 0.25 * flip, flip)
			r.piece(K.rrect(-1.3, -2.0, 1.3, 15.0, 0.6), g.call(Color("7a5a38")), 0.4, true)
			r.piece(K.rrect(-5.2, 13.0, 5.2, 19.6, 1.2), g.call(Color("9096a2")), 0.4, true)
			r.reset()
		"loaf":
			var flip2 := 1.0 if s >= -0.05 else -1.0
			r.at(hand + Vector2(0, -2.0), 0.0, flip2)
			r.piece(K.ell(Vector2(0, -4.0), 7.4, 4.6, 14), g.call(Color("c8924a")), 0.45, true)
			r.op(func(ci):
				ci.draw_line(Vector2(-3.4, -6.2), Vector2(-1.4, -2.0), Color(pen, 0.55), 1.0)
				ci.draw_line(Vector2(0.4, -7.0), Vector2(2.4, -2.6), Color(pen, 0.55), 1.0)
				ci.draw_line(Vector2(3.8, -6.2), Vector2(5.4, -2.8), Color(pen, 0.55), 1.0))
			r.reset()
		"book":
			if c > -0.25:
				var bx: float = hand.x
				r.depth += 0.2
				r.piece(PackedVector2Array([Vector2(bx - 7.0, -32.0), Vector2(bx + 7.0, -32.0), Vector2(bx + 7.0, -22.5), Vector2(bx - 7.0, -22.5)]), g.call(Color("9c4a3c")), 0.4, true, 0.0, true, 1)
				r.op(func(ci):
					ci.draw_line(Vector2(bx - 5.4, -31.0), Vector2(bx - 5.4, -23.5), Color(g.call(Color("f0e6cc")), 0.9), 1.4)
					ci.draw_line(Vector2(bx + 7.0, -31.0), Vector2(bx + 7.0, -23.5), Color(g.call(Color("f0e6cc")), 0.9), 1.6))

static func _head(r: K.Rec, sp: Dictionary, g: Callable, px: Callable, dp: Callable, c: float, s: float, t: float, breathe: float, skin: Color, pen: Color, ctx: Dictionary) -> void:
	var R: float = sp["head_r"]
	var RY: float = sp["head_ry"]
	var cy := -46.0 + breathe * 0.5
	r.depth = 0.6
	# ears sit on the silhouette sides
	for side in [-1.0, 1.0]:
		r.piece(K.ell(Vector2(px.call(side * (R - 0.3), 0.0), cy + 1.6), 1.7, 2.5, 8), skin.darkened(0.06), 0.2, false)
	r.piece(K.ell(Vector2(0, cy), R, RY, 22), skin, 0.2, true)
	var hair: Color = sp["hair"]
	var style: String = sp.get("hair_style", "none")
	# the face logic: features sit on the front of a sphere, so they swing around as the head turns
	var feat := func(xl: float, yl: float) -> Vector3:
		var zl := sqrt(maxf(R * R - xl * xl, 0.0))
		return Vector3(xl * c + zl * s, yl, zl * c - xl * s)
	# ---- hair / hat / beard pieces (drawn as pieces so they get the outline)
	if style == "fringe":
		for side in [-1.0, 1.0]:
			r.depth = 0.62
			r.piece(K.soft(PackedVector2Array([Vector2(px.call(side * R, 0.0) - 1.8, cy - 3.4), Vector2(px.call(side * R, 0.0) + 1.8, cy - 3.8), Vector2(px.call(side * R, 0.0) + 2.0, cy + 1.2), Vector2(px.call(side * R, 0.0) - 1.8, cy + 2.4)]), 1), g.call(hair), 0.4, false)
		if c < 0.0:
			r.depth = 0.62
			r.piece(K.soft(PackedVector2Array([Vector2(-R * 0.92, cy + 0.5), Vector2(R * 0.92, cy + 0.5), Vector2(R * 0.82, cy + 6.5), Vector2(0, cy + R * 0.78), Vector2(-R * 0.82, cy + 6.5)]), 2), g.call(hair), 0.3, false)
	elif style == "tuft":
		r.depth = 0.62
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			cap.append(Vector2(cos(a) * (R + 0.8), cy + sin(a) * (RY + 0.8) * 0.98))
		if c > 0.0:
			cap.append(Vector2(R * 0.75 * c + 3.0 * s, cy - 6.2))
			cap.append(Vector2(R * 0.35 * c + 5.0 * s, cy - 7.4))
			cap.append(Vector2(-R * 0.35 * c + 5.0 * s, cy - 6.6))
			cap.append(Vector2(-R * 0.75 * c + 3.0 * s, cy - 7.4))
		else:
			cap.append(Vector2(R * 0.9, cy + 6.0))
			cap.append(Vector2(0, cy + 9.0))
			cap.append(Vector2(-R * 0.9, cy + 6.0))
		r.piece(K.soft(cap, 1), g.call(hair), 0.4, true, 0.0, true, 0)
		# messy spikes
		for i in 5:
			var xl: float = -7.0 + i * 3.5
			var zl: float = 3.0 * ((i % 2) * 2 - 1)
			var bx: float = px.call(xl, zl)
			var lean: float = (-1.0 if i % 2 == 0 else 1.0) * 2.2
			r.piece(PackedVector2Array([Vector2(bx - 2.4, cy - RY + 1.0), Vector2(bx + lean, cy - RY - 7.0 - (i % 3)), Vector2(bx + 2.4, cy - RY + 1.0)]), g.call(hair), 0.4, false)
	elif style == "none" and sp.get("hat", "") == "chef":
		pass
	var hat: String = sp.get("hat", "")
	if hat == "chef":
		r.depth = 0.64
		var hc: Color = g.call(Color("f6f1e4"))
		r.piece(K.rrect(-R * 0.95, cy - RY - 3.0, R * 0.95, cy - RY + 5.0, 2.4), hc, 0.4, true, 0.0, true, 1)
		for i in 3:
			var ox: float = (i - 1) * 6.2
			r.piece(K.ell(Vector2(ox, cy - RY - 9.0 - (2.0 if i == 1 else 0.0)), 7.6, 8.0, 14), hc, 0.4, true)
		# grey hair showing under the hat band
		r.depth = 0.615
		r.piece(K.soft(PackedVector2Array([Vector2(-R * 0.98, cy - 1.0), Vector2(-R * 0.8, cy - 8.5), Vector2(R * 0.8, cy - 8.5), Vector2(R * 0.98, cy - 1.0), Vector2(R * 0.8, cy - 4.0), Vector2(-R * 0.8, cy - 4.0)]), 1), g.call(hair), 0.25, false, 0.0, false)
	if hat == "bowler":
		r.depth = 0.64
		var bc2: Color = g.call(Color("4a4048"))
		r.piece(K.soft(K.ell(Vector2(0, cy - RY + 1.0), R * 1.25, 2.6, 16), 1), bc2.darkened(0.1), 0.4, true)
		r.piece(K.soft(PackedVector2Array([Vector2(-R * 0.82, cy - RY + 1.5), Vector2(-R * 0.7, cy - RY - 7.5), Vector2(R * 0.7, cy - RY - 7.5), Vector2(R * 0.82, cy - RY + 1.5)]), 2), bc2, 0.4, true)
	elif hat == "bonnet":
		r.depth = 0.64
		var nc: Color = g.call(Color("f3ecd8"))
		r.piece(K.soft(PackedVector2Array([Vector2(-R * 1.05, cy + 5.0), Vector2(-R * 1.0, cy - 5.0), Vector2(-R * 0.5, cy - RY - 2.0), Vector2(R * 0.5, cy - RY - 2.0), Vector2(R * 1.0, cy - 5.0), Vector2(R * 1.05, cy + 5.0), Vector2(R * 0.7, cy - 2.0), Vector2(-R * 0.7, cy - 2.0)]), 2), nc, 0.35, true)
	var beard: Color = sp.get("beard", Color(0, 0, 0, 0))
	if beard.a > 0.01 and c > -0.3:
		r.depth = 0.63
		var bcx: float = px.call(0.0, R * 0.55)
		var bwid := sqrt(pow(R * 0.92 * c, 2) + pow(R * 0.62 * s, 2)) + 1.4
		var bt := cy + 1.0
		r.piece(K.soft(PackedVector2Array([
			Vector2(bcx - bwid, bt), Vector2(bcx + bwid, bt), Vector2(bcx + bwid * 0.96, bt + 7.0), Vector2(bcx + bwid * 0.62, cy + R * 0.98),
			Vector2(bcx + 1.2, cy + R * 1.22), Vector2(bcx - 1.2, cy + R * 1.22), Vector2(bcx - bwid * 0.62, cy + R * 0.98), Vector2(bcx - bwid * 0.96, bt + 7.0)]), 2), g.call(beard), 0.3, true)
	if beard.a > 0.01 and c > 0.1:
		var bc: float = px.call(0.0, R * 0.6)
		var bwd := sqrt(pow(R * 0.92 * c, 2) + pow(R * 0.62 * s, 2))
		var bcol := Color(K.shade_of(g.call(beard)), 0.9)
		r.depth = 0.68
		r.op(func(ci):
			for i in 4:
				var fx := bc + (i - 1.5) * bwd * 0.42
				ci.draw_line(Vector2(fx, cy + 9.5 + (i % 2) * 1.2), Vector2(fx + 0.4 * (i - 1.5), cy + 13.5 + (i % 2) * 1.6), bcol, 1.0))
	# ---- face
	var ink := pen
	var eyes: Array = [-1.0, 1.0]
	var depth_ok := func(v: Vector3) -> bool: return v.z > 1.2
	var eye_y := cy + 0.2
	var ex_sep := R * 0.34
	var brow_k: float = sp.get("brow", 0.0)
	var eye_r: float = sp.get("eye_r", 1.3)
	var mouth_k: float = sp.get("mouth", 0.0)
	var tear: bool = ctx.get("tearful", false)
	r.depth = 0.7
	for e in eyes:
		var f: Vector3 = feat.call(e * ex_sep, eye_y)
		if depth_ok.call(f):
			var wv := clampf(f.z / R, 0.4, 1.0)
			var fx := f.x
			var fy := f.y
			var sgn: float = e
			r.op(func(ci):
				ci.draw_colored_polygon(K.ell(Vector2(fx, fy), eye_r * wv, eye_r * 1.45, 10), ink)
				# brow: inner end up (worried) or down (stern) by brow_k
				var bx0 := fx - 2.4 * wv
				var bx1 := fx + 2.4 * wv
				var inner_up := brow_k * 1.6
				var y0 := fy - 4.0 - (inner_up if sgn > 0.0 else 0.0)
				var y1 := fy - 4.0 - (0.0 if sgn > 0.0 else inner_up)
				ci.draw_line(Vector2(bx0, y0), Vector2(bx1, y1), Color(g.call(hair if hair.a > 0.01 else Color("5a4a3a")), 1.0).darkened(0.2), 1.5))
	var nose: Vector3 = feat.call(0.0, cy + 3.4)
	if depth_ok.call(nose):
		var nx := nose.x
		var ny := nose.y
		r.op(func(ci):
			ci.draw_line(Vector2(nx + 0.5, ny - 3.6), Vector2(nx - 0.2, ny + 0.6), Color(K.shade_of(skin), 1.0), 1.4)
			ci.draw_line(Vector2(nx - 0.2, ny + 0.6), Vector2(nx + 1.6, ny + 0.9), Color(K.shade_of(skin), 1.0), 1.2))
	var mo: Vector3 = feat.call(0.0, cy + 7.6)
	var mo_l: Vector3 = feat.call(-R * 0.22, cy + 7.6 - mouth_k * 0.6)
	var mo_r: Vector3 = feat.call(R * 0.22, cy + 7.6 - mouth_k * 0.6)
	if depth_ok.call(mo):
		var mc := Vector2(mo.x, mo.y + mouth_k * 0.8)
		var ml := Vector2(mo_l.x, mo_l.y)
		var mr := Vector2(mo_r.x, mo_r.y)
		var has_beard := beard.a > 0.01
		r.op(func(ci): ci.draw_polyline(PackedVector2Array([ml, mc, mr]), Color(pen, 0.9) if not has_beard else Color(g.call(beard), 1.0).darkened(0.55), 1.2, true))
	if sp.get("cheeks", false):
		for e in eyes:
			var cf: Vector3 = feat.call(e * R * 0.58, cy + 5.2)
			if depth_ok.call(cf):
				var cx := cf.x
				var cyy := cf.y
				r.op(func(ci): ci.draw_colored_polygon(K.ell(Vector2(cx, cyy), 2.5, 1.7, 8), Color(0.95, 0.5, 0.45, 0.28 * (ctx.get("restored", 1.0)))))
	if tear:
		var drip := fmod(t * 0.5, 1.0)
		var tf: Vector3 = feat.call(R * 0.45, eye_y + 1.5)
		if depth_ok.call(tf):
			var tx := tf.x
			var ty := tf.y
			r.op(func(ci):
				ci.draw_line(Vector2(tx, ty), Vector2(tx, ty + 3.0 + drip * 10.0), Color(Palette.TEAR, 0.5), 1.1)
				ci.draw_circle(Vector2(tx, ty + 3.0 + drip * 10.0), 1.8 - drip * 0.9, Color(Palette.TEAR, 0.95 * (1.0 - drip * 0.5))))
	r.reset()
