class_name Prop
extends StaticBody2D
## Procedurally inked scenery. Objects with `ghost = true` begin as graphite
## pencil sketches and fill with color as the restoration wave reaches them.

enum Kind { TREE, HOUSE, FORGE, CRYSTAL, SIGN, SWORD, SHARD, ANVIL, PORTAL, FIGURE, PICKUP, BOOK, CHAIR, TABLE, OVEN, RIFT, POST, GATE, CHEST }

var kind: Kind = Kind.TREE
var ghost := false
var variant := 0
var item_id := ""         # for PICKUP props
var occupied := false      # CHAIR: a guest is seated
var warmth := 0.0          # TABLE: 0 cold .. 1 warm
var table_len := 5         # TABLE length in cells
var done := false          # a spent memory shard
var lift := 0.0            # elevation of the cell it stands on, in px
var _t := 0.0
var _seed := 0.0
var _stale := false        # a graphics setting changed: redraw once even if static
var baking := false        # painting a tree into TreeBake's texture
var bake_seed := 0.0

func _ready() -> void:
	if baking:
		_seed = bake_seed
		return                  # a picture-maker: no collision, no animation
	_seed = position.x * 0.013 + position.y * 0.007
	_t = _seed * 3.0
	if kind == Kind.TREE:
		TreeBake.ensure(self)
	Settings.quality_changed.connect(func(): _stale = true; _drawn_once = false)
	var poly := CollisionPolygon2D.new()
	match kind:
		Kind.TREE:
			# wide enough that the gap between two neighbouring trees is narrower than the Storytender
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.76)
		Kind.SIGN:
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.45)
		Kind.HOUSE, Kind.FORGE:
			poly.polygon = Iso.diamond(Vector2.ZERO, 1.8)
		Kind.ANVIL, Kind.FIGURE:
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.55)
		Kind.OVEN:
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.95)
		Kind.CHEST:
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.5)
		Kind.TABLE:
			var h := table_len * 0.5 - 0.1
			poly.polygon = PackedVector2Array([Iso.to_screen(Vector2(-h, -0.42)), Iso.to_screen(Vector2(h, -0.42)), Iso.to_screen(Vector2(h, 0.42)), Iso.to_screen(Vector2(-h, 0.42))])
		_:
			poly = null
	if poly:
		add_child(poly)

func _process(delta: float) -> void:
	if baking:
		return
	_t += delta
	# Props far from the camera keep whatever they last drew, and trees sway at half rate.
	var cam := get_viewport().get_camera_2d()
	if cam:
		var d := global_position - cam.get_screen_center_position()
		if absf(d.x) > 620.0 or absf(d.y) > 440.0:
			return
	if _stale:
		_stale = false
		queue_redraw()
		return
	if kind == Kind.TREE:
		if not Settings.gfx_on("sway"):
			if _drawn_once:
				return        # a still tree draws once and keeps it
			_drawn_once = true
		else:
			_skip = not _skip
			if _skip:
				return
	if kind != Kind.TREE:
		_gate.hz = 3.0 if STILL_KINDS.has(kind) and not occupied else RedrawGate.HZ
		if not _gate.ok(delta, self):
			return
	queue_redraw()

const STILL_KINDS := [Kind.SIGN, Kind.CHAIR, Kind.GATE]
var _gate := RedrawGate.new()
var _skip := false
var _drawn_once := false

func _restoration() -> float:
	return GameState.restored_at(global_position) if ghost else 1.0

# Fill color that fades from graphite to full color. alpha follows r.
func _fill(c: Color, r: float) -> Color:
	var f := Palette.ghostify(c, r)
	f.a = r
	return f

func _draw() -> void:
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	var r := _restoration()
	if _draw_art(r):
		return
	match kind:
		Kind.TREE: _draw_tree()
		Kind.HOUSE: _draw_house(r, false)
		Kind.FORGE: _draw_house(r, true, 0.0 if variant == 99 else -1.0)
		Kind.CRYSTAL: _draw_crystal()
		Kind.SIGN: _draw_sign()
		Kind.SWORD: _draw_sword()
		Kind.SHARD: _draw_shard()
		Kind.ANVIL: _draw_anvil()
		Kind.PORTAL: _draw_portal()
		Kind.FIGURE: _draw_figure()
		Kind.PICKUP: _draw_pickup()
		Kind.BOOK: _draw_book()
		Kind.CHAIR: _draw_chair()
		Kind.TABLE: _draw_table()
		Kind.OVEN: _draw_oven()
		Kind.RIFT: _draw_rift()
		Kind.POST: _draw_post()
		Kind.GATE: _draw_gate()
		Kind.CHEST: _draw_chest()

const ART_KEYS := {Kind.TREE: "prop_tree", Kind.HOUSE: "prop_house", Kind.FORGE: "prop_forge", Kind.CRYSTAL: "prop_crystal", Kind.SIGN: "prop_sign",
	Kind.SWORD: "prop_sword", Kind.SHARD: "prop_shard", Kind.ANVIL: "prop_anvil", Kind.PORTAL: "prop_portal", Kind.BOOK: "prop_book",
	Kind.CHAIR: "prop_chair", Kind.TABLE: "prop_table", Kind.OVEN: "prop_oven", Kind.RIFT: "prop_rift", Kind.POST: "prop_post",
	Kind.GATE: "prop_gate", Kind.CHEST: "prop_chest"}
const ART_SHADOW := {Kind.TREE: 20.0, Kind.HOUSE: 54.0, Kind.FORGE: 54.0, Kind.CRYSTAL: 9.0, Kind.SIGN: 10.0, Kind.SHARD: 11.0, Kind.ANVIL: 24.0,
	Kind.PORTAL: 22.0, Kind.BOOK: 30.0, Kind.CHAIR: 14.0, Kind.OVEN: 34.0, Kind.RIFT: 20.0, Kind.POST: 14.0, Kind.GATE: 30.0, Kind.CHEST: 20.0}

## Lets the active art style draw this prop. Returns false to fall back to the original drawing.
func _draw_art(r: float) -> bool:
	var art := Skins.art()
	if art == null or not ART_KEYS.has(kind):
		return false
	var key: String = ART_KEYS[kind]
	var ctx := {"t": _t, "variant": variant, "seed": bake_seed if baking else _seed, "restored": r, "occupied": occupied, "warmth": warmth,
		"table_len": table_len, "done": done, "flame": 0.0 if variant == 99 else r, "origin": Vector2(0, -lift), "scale": 1.0}
	if kind == Kind.TREE:
		if not baking:
			_shadow(20.0)
			var tex := TreeBake.texture(variant % 3, int(absf(_seed) * 10.0) % TreeBake.BUCKETS)
			if tex != null:
				var lean := sin(_t * 1.1) * 0.03 if Settings.gfx_on("sway") else 0.0
				draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(lean, 1), Vector2(0, -lift)))
				draw_texture_rect(tex, Rect2(-TreeBake.BASE, Vector2(TreeBake.SIZE)), false)
				return true
		ctx["origin"] = Vector2.ZERO if baking else Vector2(0, -lift)
	elif kind != Kind.SWORD:
		_shadow(float(table_len) * 24.0 if kind == Kind.TABLE else float(ART_SHADOW.get(kind, 14.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ok := FigureBake.draw_prop(art, self, key, ctx)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	return ok

func _shadow(rx: float) -> void:
	if not Settings.gfx_on("shadows"):
		return
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, rx, Color(0.15, 0.1, 0.05, 0.18))
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)

# --- Tree ---------------------------------------------------------------------
func _draw_tree() -> void:
	if not baking:
		_shadow(20.0)
		var tex := TreeBake.texture(variant % 3, int(absf(_seed) * 10.0) % TreeBake.BUCKETS)
		if tex != null:
			# one picture instead of ~70 drawing commands; sway is a slight lean of the picture
			var lean := sin(_t * 1.1) * 0.03 if Settings.gfx_on("sway") else 0.0
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(lean, 1), Vector2(0, -lift)))
			draw_texture_rect(tex, Rect2(-TreeBake.BASE, Vector2(TreeBake.SIZE)), false)
			return
	var sway := 0.0 if baking else sin(_t * 1.1) * 1.6
	var trunk := PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(3.5, -34), Vector2(-3.5, -34)])
	DrawKit.shape(self, trunk, Palette.WOOD, Palette.INK_BROWN, 2.0, _seed)
	DrawKit.hatch(self, PackedVector2Array([trunk[0], trunk[1], trunk[2], trunk[3]]), 4, Color(Palette.INK_BROWN, 0.5))
	var big := 25.0 + (variant % 3) * 3.0
	var c := Vector2(sway, -52)
	# Three overlapping lobes read as a hand-drawn cloud of leaves.
	for lobe in [Vector2(-12, 5), Vector2(12, 4), Vector2(0, -9)]:
		var pts := DrawKit.ellipse(c + lobe, big * 0.72, big * 0.62, 16, 0.18, _seed + lobe.x)
		DrawKit.shape(self, pts, Palette.LEAF.darkened(0.1 if lobe.y > 0.0 else 0.0), Palette.INK_BROWN, 2.0, _seed + lobe.y)
	for i in 6:
		var p := c + Vector2(-14 + i * 5.5, -4 + (i % 2) * 9)
		draw_arc(p, 4.0, PI * 0.1, PI * 0.9, 6, Palette.GRASS_DARK, 1.5, true)

# --- House / forge ------------------------------------------------------------
func _draw_house(r: float, forge: bool, flame_r: float = -1.0) -> void:
	if flame_r < 0.0:
		flame_r = r
	# Unrestored houses are drawn in dark graphite (not pale gray) so they stay readable against
	# the page and against cliffs that overlap them.
	var pen := Color("3b3e4d").lerp(Palette.INK, r)
	var pw := 2.5 - 0.4 * r
	_shadow(54.0)
	var d := Iso.diamond(Vector2.ZERO, 1.84)  # N, E, S, W
	var h := 56.0
	var up := Vector2(0, -h)
	var wall_c := Palette.WALL if variant % 2 == 0 else Color("e4cba0")
	var roof_c := Palette.ROOF if variant % 2 == 0 else Palette.ROOF_ALT
	if forge:
		wall_c = Color("cdb995")
		roof_c = Color("6b5a52")
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	DrawKit.shape(self, left, _fill(wall_c.darkened(0.08), r), pen, pw, _seed)
	DrawKit.shape(self, right, _fill(wall_c.darkened(0.28), r), pen, pw, _seed + 5.0)
	DrawKit.hatch(self, right, 7, Color(Palette.INK_BROWN, 0.12 * r + 0.18 * (1.0 - r)))
	# Windows on the left wall.
	for u in [0.25, 0.65]:
		var win := DrawKit.face_quad(left, u, 0.42, u + 0.14, 0.78)
		DrawKit.shape(self, win, _fill(Color("f6dc8e") if r > 0.0 else wall_c, r), pen, 1.6, _seed + u * 10.0)
		DrawKit.line(self, DrawKit.face(left, u + 0.07, 0.42), DrawKit.face(left, u + 0.07, 0.78), pen, 1.2)
	# Door (or open forge mouth) on the right wall.
	var door := DrawKit.face_quad(right, 0.3, 0.0, 0.62, 0.66)
	if forge:
		DrawKit.shape(self, door, _fill(Color("2b1c14"), r), pen, 2.0, _seed + 9.0)
	else:
		DrawKit.shape(self, door, _fill(Palette.WOOD, r), pen, 2.0, _seed + 9.0)
		draw_circle(DrawKit.face(door, 0.82, 0.4), 1.8, pen)
	# Roof: two visible faces meeting at a ridge point.
	var apex := Vector2(0, -h - 44.0)
	var rl := PackedVector2Array([d[3] + up + Vector2(-8, 4), d[2] + up + Vector2(0, 10), apex])
	var rr := PackedVector2Array([d[2] + up + Vector2(0, 10), d[1] + up + Vector2(8, 4), apex])
	DrawKit.shape(self, rl, _fill(roof_c, r), pen, pw, _seed + 2.0)
	DrawKit.shape(self, rr, _fill(roof_c.darkened(0.25), r), pen, pw, _seed + 3.0)
	for i in range(1, 5):
		var t := i / 5.0
		draw_line(rl[0].lerp(apex, t), rl[1].lerp(apex, t), Color(pen, 0.45), 1.0, true)
		draw_line(rr[0].lerp(apex, t), rr[1].lerp(apex, t), Color(pen, 0.45), 1.0, true)
	# Chimney.
	var cp := Vector2(22, -h - 30)
	var chim := PackedVector2Array([cp, cp + Vector2(12, 6), cp + Vector2(12, -16), cp + Vector2(0, -22)])
	DrawKit.shape(self, chim, _fill(Color("9c6b55"), r), pen, 1.8, _seed + 4.0)
	# Smoke curls up from a home that has its ink back (and from the forge once the flame is lit).
	var puff := (r if not forge else flame_r)
	if puff > 0.5 and Settings.gfx_on("ambient"):
		for i in 4:
			var ph := fmod(_t * 0.32 + i * 0.25 + _seed * 0.1, 1.0)
			var sp := cp + Vector2(6.0 + sin(_t * 0.9 + i * 1.7) * 4.0 * ph + ph * 10.0, -22.0 - ph * 40.0)
			draw_circle(sp, 3.0 + ph * 6.0, Color(0.9, 0.9, 0.93, 0.5 * (1.0 - ph) * puff))
	if forge:
		_draw_forge_fire(DrawKit.face(door, 0.5, 0.0), flame_r)
	# [REDACTED]: a black censor bar over the doorway until the page is restored.
	if r < 1.0 and not forge:
		var bar := DrawKit.face_quad(right, 0.18, 0.28, 0.78, 0.5)
		DrawKit.shape(self, bar, Color(Palette.INK, 1.0 - r), Color(0, 0, 0, 0), 1.0)
	if r < 1.0 and forge:
		var bar2 := DrawKit.face_quad(left, 0.12, 0.3, 0.88, 0.5)
		DrawKit.shape(self, bar2, Color(Palette.INK, 1.0 - r), Color(0, 0, 0, 0), 1.0)

func _draw_forge_fire(base: Vector2, r: float) -> void:
	# Frozen mid-lick until restored, then it flickers back to life.
	var col := Palette.FROZEN.lerp(Palette.FLAME, r)
	col.a = 0.9
	# Three tongues of flame; the flicker term is multiplied by r, so it is
	# perfectly still while frozen.
	var n := 15
	var pts := PackedVector2Array([base + Vector2(-16, 0)])
	for i in n:
		var t := float(i) / (n - 1)
		var tongues := 0.55 + 0.45 * absf(sin(t * PI * 3.0))
		var tip := 34.0 * sin(PI * t) * tongues
		tip *= 1.0 + 0.28 * sin(_t * 9.0 + i * 1.9) * r
		pts.append(base + Vector2(lerpf(-16.0, 16.0, t), -tip))
	pts.append(base + Vector2(16, 0))
	draw_colored_polygon(pts, col)
	DrawKit.outline(self, pts, Color(Palette.INK, 0.8), 1.4, _seed + 7.0, 0.6)
	if r < 1.0:
		# Little ice-white glints where the heat is stopped in time.
		for i in 4:
			var p := base + Vector2(-9 + i * 6, -16 - (i % 2) * 10)
			draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color(1, 1, 1, (1.0 - r) * 0.9), 1.4)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color(1, 1, 1, (1.0 - r) * 0.9), 1.4)
	else:
		draw_circle(base + Vector2(0, -14), 44.0, Color(Palette.FLAME, 0.07 + 0.03 * sin(_t * 7.0)))

# --- Mnemosynth crystal ---------------------------------------------------------
func _draw_crystal() -> void:
	_shadow(9.0)
	var bob := sin(_t * 2.2) * 3.0
	var c := Vector2(0, -22 + bob)
	if Settings.gfx_on("glow"):
		for rad in [26.0, 18.0]:
			draw_circle(c, rad, Color(Palette.GOLD, 0.07))
	var pts := PackedVector2Array([c + Vector2(0, -12), c + Vector2(8, -2), c + Vector2(5, 10), c + Vector2(-5, 10), c + Vector2(-8, -2)])
	DrawKit.shape(self, pts, Color(Palette.GOLD, 0.95), Palette.INK_BROWN, 1.8, _seed)
	draw_line(c + Vector2(-2, -8), c + Vector2(-3, 2), Color(1, 1, 1, 0.7), 1.6)
	draw_line(c + Vector2(0, -12), c + Vector2(0, 10), Color(Palette.INK_BROWN, 0.3), 1.0)

# --- Signpost ------------------------------------------------------------------
func _draw_sign() -> void:
	_shadow(10.0)
	DrawKit.shape(self, PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -38), Vector2(-3, -38)]), Palette.WOOD, Palette.INK_BROWN, 1.8, _seed)
	var plank := PackedVector2Array([Vector2(-18, -44), Vector2(16, -44), Vector2(22, -36), Vector2(16, -28), Vector2(-18, -28)])
	DrawKit.shape(self, plank, Palette.WOOD.lightened(0.15), Palette.INK_BROWN, 1.8, _seed + 2.0)
	for i in 3:
		draw_line(Vector2(-12, -39 + i * 4), Vector2(10 - i * 3, -39 + i * 4), Color(Palette.INK_BROWN, 0.5), 1.2)

# --- The First Sword -----------------------------------------------------------
func _draw_sword() -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 2.4)
	for rad in [34.0, 24.0, 15.0]:
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, rad, Color(Palette.GOLD, 0.06 * pulse))
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	var lift := Vector2(0, -4 + sin(_t * 1.6) * 2.0)
	# Blade lying along the iso diagonal, as if half-erased: it dissolves toward the tip.
	var a := Vector2(-22, 6) + lift
	var b := Vector2(26, -14) + lift
	var dir := (b - a).normalized()
	var perp := dir.orthogonal()
	var blade := PackedVector2Array([a + perp * 3.0, b, a - perp * 3.0])
	DrawKit.shape(self, blade, Color(0.86, 0.9, 0.95, 0.95 * pulse), Palette.INK_BROWN, 1.8, _seed)
	var guard_c := a + dir * 4.0
	DrawKit.line(self, guard_c + perp * 9.0, guard_c - perp * 9.0, Palette.INK_BROWN, 3.5, _seed + 1.0, 0.4)
	DrawKit.line(self, a, a - dir * 11.0, Palette.WOOD, 4.0, _seed + 2.0, 0.4)
	# Motes of nostalgia drifting upward.
	for i in 5:
		var ph := fmod(_t * 0.5 + i * 0.37, 1.0)
		var p := Vector2(-16 + i * 9, -8 - ph * 34.0)
		draw_circle(p, 1.8, Color(Palette.GOLD, (1.0 - ph) * 0.9))

# --- Memory shard (a remembered moment, waiting to be held up to the Lantern) -----------
func _draw_shard() -> void:
	_shadow(11.0)
	if done:
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(Palette.CYAN, 0.28), 2.0, true)
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
		return
	var bob := sin(_t * 2.0) * 4.0
	var c := Vector2(0, -34 + bob)
	for rad in [40.0, 28.0, 17.0]:
		draw_circle(c, rad, Color(Palette.CYAN, 0.075))
	var w := 8.0 + 3.0 * sin(_t * 1.6)
	var pts := PackedVector2Array([c + Vector2(0, -17), c + Vector2(w, -5), c + Vector2(w * 0.7, 10), c + Vector2(0, 17), c + Vector2(-w * 0.7, 10), c + Vector2(-w, -5)])
	DrawKit.shape(self, pts, Color(Palette.CYAN, 0.95), Palette.OUTLINE, 2.4, _seed)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15), c + Vector2(w * 0.55, -5), c + Vector2(0, 2)]), Color(1, 1, 1, 0.55))
	# Ground ring pulsing outward, and motes of memory rising.
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	var ring := fmod(_t * 0.6, 1.0)
	draw_arc(Vector2.ZERO, 8.0 + ring * 26.0, 0.0, TAU, 24, Color(Palette.CYAN, (1.0 - ring) * 0.5), 2.0, true)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	for i in 4:
		var ph := fmod(_t * 0.45 + i * 0.27, 1.0)
		draw_circle(Vector2(-12 + i * 8, -20 - ph * 44.0), 1.6, Color(Palette.CYAN, (1.0 - ph) * 0.9))

# --- Frozen anvil: the hammer and sparks hang in the air, mid-strike ---------------------
func _draw_anvil() -> void:
	_shadow(24.0)
	var iron := Color("5a6070")
	var base := PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(9, -10), Vector2(-9, -10)])
	DrawKit.shape(self, base, iron.darkened(0.2), Palette.OUTLINE, 2.4, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(-7, -10), Vector2(7, -10), Vector2(5, -20), Vector2(-5, -20)]), iron.darkened(0.1), Palette.OUTLINE, 2.4, _seed + 1.0)
	var top := PackedVector2Array([Vector2(-22, -20), Vector2(16, -20), Vector2(24, -26), Vector2(-14, -29), Vector2(-24, -25)])
	DrawKit.shape(self, top, iron, Palette.OUTLINE, 2.4, _seed + 2.0)
	draw_line(Vector2(-16, -24), Vector2(12, -25), Color(1, 1, 1, 0.35), 2.0)
	# Hammer frozen above the anvil, slightly wobbling in frost-light.
	var hc := Vector2(2, -66 + sin(_t * 0.9) * 0.8)
	DrawKit.line(self, hc + Vector2(-16, 18), hc + Vector2(12, -10), Palette.WOOD, 4.5, _seed + 3.0, 0.3)
	DrawKit.shape(self, PackedVector2Array([hc + Vector2(6, -22), hc + Vector2(26, -6), hc + Vector2(18, 4), hc + Vector2(-2, -12)]), Color("8e95a6"), Palette.OUTLINE, 2.4, _seed + 4.0)
	# Sparks hanging in the air, each wrapped in a bead of frost.
	for i in 16:
		var a := TAU * i / 16.0 + _seed
		var rr := 14.0 + fmod(i * 7.3, 26.0)
		var p := Vector2(cos(a) * rr * 1.2, -34 - fmod(i * 11.0, 46.0) - sin(a) * rr * 0.25)
		var tw := 0.6 + 0.4 * sin(_t * 2.0 + i)
		draw_circle(p, 4.5, Color(Palette.CYAN, 0.10 * tw))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(2, 0), p + Vector2(0, 3), p + Vector2(-2, 0)]), Color("ffb347", 0.95))

# --- Memory portal (entrance / exit) --------------------------------------------------------
func _draw_portal() -> void:
	_shadow(22.0)
	var stone := Color("5a6478")
	# Stone frame.
	DrawKit.shape(self, PackedVector2Array([Vector2(-26, 0), Vector2(-18, 0), Vector2(-18, -70), Vector2(-26, -70)]), stone, Palette.OUTLINE, 2.4, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(18, 0), Vector2(26, 0), Vector2(26, -70), Vector2(18, -70)]), stone.darkened(0.15), Palette.OUTLINE, 2.4, _seed + 1.0)
	DrawKit.shape(self, PackedVector2Array([Vector2(-30, -70), Vector2(30, -70), Vector2(30, -80), Vector2(-30, -80)]), stone.lightened(0.05), Palette.OUTLINE, 2.4, _seed + 2.0)
	var c := Vector2(0, -36)
	for rad in [38.0, 28.0, 18.0]:
		draw_circle(c, rad, Color(Palette.CYAN, 0.08))
	draw_circle(c, 24.0, Color(0.04, 0.05, 0.12, 0.92))
	for arm in 5:
		var pts := PackedVector2Array()
		var a0 := arm * TAU / 5.0 + _t * 1.6
		for k in 14:
			var rr := 2.0 + k * 1.75
			var a := a0 + rr * 0.14
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_polyline(pts, Color(Palette.CYAN if arm % 2 == 0 else Palette.GLITCH, 0.9), 2.6, true)

# --- Frozen figures of the remembered past (young Garrick, Wren) ---------------------------
func _draw_figure() -> void:
	_shadow(12.0)
	var art := Skins.art()
	if art != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var key: String = ["young_garrick", "wren", "pip", "maud"][clampi(variant, 0, 3)]
		if FigureBake.draw(art, self, key, {"t": _t, "memory": true, "restored": 1.0, "dir": Vector2(0.25, 1.0), "origin": Vector2(0, -lift), "scale": 1.0}):
			draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
			return
	var shimmer := 0.55 + 0.12 * sin(_t * 3.0)
	var fill := Color(0.45, 0.8, 0.95, shimmer)
	var edge := Color(Palette.CYAN, 0.95)
	var s := 1.0 if variant == 0 else 0.62
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(s, s))
	for k in 3:
		draw_colored_polygon(DrawKit.ellipse(Vector2(0, -34), 24.0 + k * 6.0, 42.0 + k * 7.0, 20), Color(Palette.CYAN, 0.05))
	# Legs, body, head.
	DrawKit.shape(self, PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(7, -16), Vector2(-7, -16)]), fill, edge, 2.2, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(-11, -16), Vector2(11, -16), Vector2(9, -42), Vector2(-9, -42)]), fill, edge, 2.2, _seed + 1.0)
	draw_circle(Vector2(0, -52), 10.0, fill)
	draw_arc(Vector2(0, -52), 10.0, 0.0, TAU, 20, edge, 2.2, true)
	if variant == 3:
		# Maud, remembered: seated at the head of the table, hands folded in her lap.
		DrawKit.shape(self, PackedVector2Array([Vector2(-15, -4), Vector2(15, -4), Vector2(13, -34), Vector2(-13, -34)]), Color(fill, shimmer * 0.9), edge, 2.2, _seed + 2.0)
		draw_circle(Vector2(0, -44), 3.0, edge)
		DrawKit.shape(self, PackedVector2Array([Vector2(-9, -20), Vector2(9, -20), Vector2(8, -12), Vector2(-8, -12)]), Color(fill, 0.5), edge, 1.8, _seed + 3.0)
	elif variant == 2:
		# Pip: hunched on the page, hands pressed over his eyes, the book in his lap.
		DrawKit.shape(self, PackedVector2Array([Vector2(-14, -8), Vector2(14, -8), Vector2(16, 4), Vector2(-16, 4)]), Color(fill, shimmer * 0.8), edge, 2.2, _seed + 2.0)
		DrawKit.line(self, Vector2(-9, -34), Vector2(-5, -52), edge, 4.0, _seed + 3.0, 0.3)
		DrawKit.line(self, Vector2(9, -34), Vector2(5, -52), edge, 4.0, _seed + 4.0, 0.3)
	elif variant == 0:
		# Young Garrick: arm raised, hammer overhead, forever about to strike.
		DrawKit.line(self, Vector2(8, -38), Vector2(18, -62), edge, 4.0, _seed + 2.0, 0.3)
		DrawKit.shape(self, PackedVector2Array([Vector2(12, -72), Vector2(30, -64), Vector2(26, -56), Vector2(8, -64)]), fill, edge, 2.2, _seed + 3.0)
	else:
		# Wren: wrapped in a blanket, holding a tiny lantern against the dark.
		DrawKit.shape(self, PackedVector2Array([Vector2(-13, -40), Vector2(13, -40), Vector2(15, -6), Vector2(-15, -6)]), Color(fill, shimmer * 0.7), edge, 2.2, _seed + 2.0)
		draw_circle(Vector2(12, -30), 3.5, Color(1, 0.9, 0.6, 0.95))
		draw_circle(Vector2(12, -30), 10.0, Color(1, 0.9, 0.6, 0.18))
	# Scanline gaps: the memory is a recording, and it is slightly worn.
	for i in 9:
		var y := -62.0 + i * 7.0
		draw_line(Vector2(-18, y), Vector2(18, y), Color(0.04, 0.06, 0.12, 0.25), 1.0)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)

# --- Item pickup: the item itself, bobbing in a soft glow ---------------------------------
func _draw_pickup() -> void:
	_shadow(12.0)
	var bob := sin(_t * 2.2) * 3.0
	for rad in [30.0, 20.0]:
		draw_circle(Vector2(0, -26 + bob), rad, Color(Palette.GOLD, 0.09))
	ItemIcon.draw_item(self, item_id, Vector2(0, -28 + bob), 40.0)
	for i in 3:
		var ph := fmod(_t * 0.5 + i * 0.33, 1.0)
		draw_circle(Vector2(-10 + i * 10, -18 - ph * 30.0), 1.5, Color(Palette.GOLD, (1.0 - ph) * 0.9))

# --- Pip's storybook: the doorway into his memory ---------------------------------------------
func _draw_book() -> void:
	_shadow(30.0)
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	for k in 3:
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 54.0 - k * 14.0, Color(Palette.CYAN, (0.05 + 0.03 * k) * (0.6 + 0.4 * glow)))
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	var L := PackedVector2Array([Vector2(0, -6), Vector2(-34, -14), Vector2(-34, 4), Vector2(0, 12)])
	var R := PackedVector2Array([Vector2(0, -6), Vector2(34, -14), Vector2(34, 4), Vector2(0, 12)])
	DrawKit.shape(self, PackedVector2Array([Vector2(-38, -12), Vector2(38, -12), Vector2(38, 8), Vector2(0, 16), Vector2(-38, 8)]), Color("5b3a6a"), Palette.OUTLINE, 2.6, _seed)
	DrawKit.shape(self, L, Palette.PAGE, Palette.OUTLINE, 2.2, _seed + 1.0)
	DrawKit.shape(self, R, Palette.PAGE_SHADE, Palette.OUTLINE, 2.2, _seed + 2.0)
	for i in 4:
		draw_line(Vector2(-30 + i * 2, -10 + i * 4), Vector2(-6, -4 + i * 4), Color(Palette.INK_BROWN, 0.4), 1.3)
	# The blank right-hand page glows: the way in. A torn stub shows where the last page was.
	draw_colored_polygon(PackedVector2Array([Vector2(4, -4), Vector2(30, -11), Vector2(30, 1), Vector2(4, 8)]), Color(Palette.CYAN.lightened(0.5), 0.35 + 0.35 * glow))
	draw_polyline(PackedVector2Array([Vector2(34, -14), Vector2(31, -8), Vector2(35, -3), Vector2(32, 4)]), Color(Palette.OUTLINE, 0.9), 2.0)
	for i in 4:
		var ph := fmod(_t * 0.5 + i * 0.27, 1.0)
		draw_circle(Vector2(8 + i * 6, -8 - ph * 40.0), 1.8, Color(Palette.CYAN, (1.0 - ph) * 0.9))

# --- Chair (the Empty Table's seats) ---------------------------------------------------------
func _draw_chair() -> void:
	_shadow(14.0)
	var wood := Palette.WOOD.lerp(Palette.GOLD, 0.25 if occupied else 0.0)
	var facing := -1.0 if variant == 0 else 1.0   # north row faces south, south row faces north
	DrawKit.shape(self, PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(9, -4), Vector2(-9, -4)]), wood, Palette.OUTLINE, 2.4, _seed)
	for lx in [-9.0, 9.0]:
		draw_line(Vector2(lx, -4), Vector2(lx, 2), Palette.OUTLINE, 3.0)
	var back_y := -14.0
	DrawKit.shape(self, PackedVector2Array([Vector2(-10, back_y), Vector2(10, back_y), Vector2(9, back_y - 20.0), Vector2(-9, back_y - 20.0)]), wood.darkened(0.12), Palette.OUTLINE, 2.4, _seed + 1.0)
	if occupied:
		draw_circle(Vector2(0, -22), 26.0, Color(Palette.GOLD, 0.10))

# --- The long table: cold and bare until it is filled ---------------------------------------
func _draw_table() -> void:
	_shadow(table_len * 24.0)
	var w := clampf(warmth, 0.0, 1.0)
	var h := table_len * 0.5
	var lift := 26.0
	var cloth := Color("7d8aa3").lerp(Color("e2b560"), w)
	var wood := Color("5a4a44").lerp(Palette.WOOD, w)
	var tl := Iso.to_screen(Vector2(-h, -0.45)) + Vector2(0, -lift)
	var tr := Iso.to_screen(Vector2(h, -0.45)) + Vector2(0, -lift)
	var br := Iso.to_screen(Vector2(h, 0.45)) + Vector2(0, -lift)
	var bl := Iso.to_screen(Vector2(-h, 0.45)) + Vector2(0, -lift)
	# Legs and the near side faces.
	for lx in [-h + 0.3, h - 0.3]:
		for ly in [-0.35, 0.35]:
			var f := Iso.to_screen(Vector2(lx, ly))
			draw_line(f, f + Vector2(0, -lift), Palette.OUTLINE, 5.0)
	var front := PackedVector2Array([bl, br, br + Vector2(0, 8), bl + Vector2(0, 8)])
	var side := PackedVector2Array([br, tr, tr + Vector2(0, 8), br + Vector2(0, 8)])
	draw_colored_polygon(front, wood.darkened(0.15))
	draw_colored_polygon(side, wood.darkened(0.3))
	DrawKit.shape(self, PackedVector2Array([tl, tr, br, bl]), cloth, Palette.OUTLINE, 2.8, _seed)
	# Place settings: bare plates when cold, bread and candles when warm.
	for i in range(table_len):
		var cx := -h + 0.5 + i
		for ly in [-0.2, 0.2]:
			var pc := Iso.to_screen(Vector2(cx, ly)) + Vector2(0, -lift - 1)
			draw_colored_polygon(DrawKit.ellipse(pc, 9.0, 4.5, 14), Color("e8e4dc").lerp(Color("f6ead0"), w))
			if w > 0.4:
				draw_colored_polygon(DrawKit.ellipse(pc + Vector2(0, -2), 5.0, 3.0, 10), Color("c9893f", w))
	if w > 0.15:
		for cx in [-h + 0.8, 0.0, h - 0.8]:
			var cp := Iso.to_screen(Vector2(cx, 0.0)) + Vector2(0, -lift)
			draw_line(cp, cp + Vector2(0, -12), Color("f4ecd6"), 4.0)
			draw_circle(cp + Vector2(0, -16), 4.0 + sin(_t * 9.0 + cx) * 0.8, Color("ffd24a", w))
			draw_circle(cp + Vector2(0, -16), 24.0, Color(Palette.GOLD, 0.10 * w))
	else:
		# Frost creeping along the cloth.
		for i in 6:
			var fp := tl.lerp(tr, 0.1 + i * 0.16) + Vector2(0, 4 + (i % 2) * 6)
			draw_line(fp, fp + Vector2(3, 6), Color(0.85, 0.95, 1.0, 0.6), 1.6)

# --- Maud's cold oven: the doorway into her memory ---------------------------------------
func _draw_oven() -> void:
	_shadow(34.0)
	var d := Iso.diamond(Vector2.ZERO, 1.7)
	var h := 46.0
	var up := Vector2(0, -h)
	var stone := Color("8a8f9c")
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	DrawKit.shape(self, left, stone.darkened(0.12), Palette.OUTLINE, 2.6, _seed)
	DrawKit.shape(self, right, stone.darkened(0.3), Palette.OUTLINE, 2.6, _seed + 1.0)
	var dome := PackedVector2Array([d[3] + up, d[2] + up, d[1] + up, d[0] + up])
	DrawKit.shape(self, dome, stone.lightened(0.05), Palette.OUTLINE, 2.6, _seed + 2.0)
	# The mouth of the oven: black and cold, with one small light still in the ashes.
	var mouth := DrawKit.face_quad(right, 0.25, 0.1, 0.75, 0.62)
	DrawKit.shape(self, mouth, Color("14121a"), Palette.OUTLINE, 2.4, _seed + 3.0)
	var m := (mouth[0] + mouth[2]) * 0.5 + Vector2(0, 8)
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(m, 14.0 + pulse * 4.0, Color(Palette.CYAN, 0.12))
	draw_circle(m, 3.0 + pulse, Color(Palette.CYAN.lightened(0.5), 0.9))
	# Chimney.
	DrawKit.shape(self, PackedVector2Array([Vector2(-6, -h - 6), Vector2(6, -h - 6), Vector2(6, -h - 34), Vector2(-6, -h - 34)]), stone.darkened(0.2), Palette.OUTLINE, 2.4, _seed + 4.0)

# --- The tear in the page (the way to the Editor) ---------------------------------------------
func _draw_rift() -> void:
	_shadow(20.0)
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var top := Vector2(0, -92)
	var edge_l := PackedVector2Array()
	var edge_r := PackedVector2Array()
	for k in 9:
		var y := lerpf(0.0, -92.0, k / 8.0)
		var w := 2.5 + sin(k / 8.0 * PI) * (13.0 + pulse * 2.0)
		var jag := (1.8 if k % 2 == 0 else -1.8) * (0.0 if k == 0 or k == 8 else 1.0)
		edge_l.append(Vector2(-w + jag, y))
		edge_r.append(Vector2(w - jag, y))
	var pts := PackedVector2Array()
	pts.append_array(edge_l)
	var rr := edge_r.duplicate()
	rr.reverse()
	pts.append_array(rr)
	draw_circle(Vector2(0, -46), 38.0, Color(1, 1, 1, 0.06 + 0.04 * pulse))
	DrawKit.shape(self, pts, Color("f6f3ea"), Palette.OUTLINE, 2.4, _seed)
	for k in 6:
		var y := -10.0 - k * 14.0
		draw_line(Vector2(-4, y), Vector2(4, y - 6), Color("c0405a", 0.7), 1.6)
	draw_polyline(edge_l, Color("c0405a", 0.6 + 0.3 * pulse), 1.4)

# --- A lantern post: a waypoint you light once, then rest at ----------------------------------
func _draw_post() -> void:
	_shadow(14.0)
	var lit := variant == 1
	var wood := Palette.WOOD
	DrawKit.shape(self, PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(3, -58), Vector2(-3, -58)]), wood, Palette.OUTLINE, 2.2, _seed)
	# the arm and the hanging lantern
	draw_line(Vector2(0, -56), Vector2(14, -56), Palette.OUTLINE, 3.0)
	var lamp := Vector2(14, -44)
	draw_line(Vector2(14, -56), lamp + Vector2(0, -8), Palette.OUTLINE, 1.6)
	var glow := 0.5 + 0.5 * sin(_t * 2.6)
	if lit and Settings.gfx_on("glow"):
		draw_circle(lamp, 30.0 + glow * 3.0, Color(Palette.CYAN, 0.10))
		draw_circle(lamp, 18.0, Color(Palette.CYAN, 0.14))
	var body := PackedVector2Array([lamp + Vector2(-6, -8), lamp + Vector2(6, -8), lamp + Vector2(7, 8), lamp + Vector2(-7, 8)])
	DrawKit.shape(self, body, Color("e6f7fb") if lit else Color("8a8f99"), Palette.OUTLINE, 2.0, _seed + 1.0)
	if lit:
		draw_circle(lamp, 4.0, Color(1, 1, 1, 0.95))

# --- The Margin Gate: a doorway of upright books with a full-stop seal -----------------------------
func _draw_gate() -> void:
	_shadow(30.0)
	var open_ := variant == 1
	var wood := Color("6a4a30")
	var ink := Palette.OUTLINE
	for sx in [-34.0, 34.0]:
		DrawKit.shape(self, PackedVector2Array([Vector2(sx - 7, 0), Vector2(sx + 7, 0), Vector2(sx + 6, -96), Vector2(sx - 6, -96)]), wood, ink, 2.4, _seed + sx)
		for k in 4:
			draw_line(Vector2(sx - 5, -14 - k * 22), Vector2(sx + 5, -14 - k * 22), Color(ink, 0.3), 1.2)
	DrawKit.shape(self, PackedVector2Array([Vector2(-44, -96), Vector2(44, -96), Vector2(40, -108), Vector2(-40, -108)]), wood.lightened(0.08), ink, 2.4, _seed + 2.0)
	var cols := [Color("8e3b32"), Color("2f5d7a"), Color("5b7a3a"), Color("8a6a2f"), Color("5a3a6a"), Color("7a3b2e")]
	if open_:
		var pulse := 0.5 + 0.5 * sin(_t * 1.6)
		draw_rect(Rect2(-27, -94, 54, 94), Color(1, 1, 1, 0.55 + 0.2 * pulse))
		for k in 6:
			var y := -10.0 - k * 15.0
			draw_line(Vector2(-22, y), Vector2(22, y - 4), Color(Palette.CYAN, 0.35), 1.6)
	else:
		for i in 6:
			var x0 := -27.0 + i * 9.0
			var top := -94.0 + (3.0 if i % 3 == 1 else 0.0)
			var q := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 9, 0), Vector2(x0 + 9, top), Vector2(x0, top)])
			DrawKit.shape(self, q, cols[i % cols.size()], ink, 1.8, _seed + i)
			for by in [-18.0, -72.0]:
				draw_line(Vector2(x0 + 1, by), Vector2(x0 + 8, by), Color("e8c86a", 0.85), 1.4)
		draw_line(Vector2(-27, -50), Vector2(27, -50), Color("d9cfa8"), 5.0)
		draw_line(Vector2(-27, -50), Vector2(27, -50), ink, 1.0)
		draw_circle(Vector2(0, -50), 10.0, Color("a8483f"))
		draw_arc(Vector2(0, -50), 10.0, 0.0, TAU, 14, ink, 2.0)
		draw_circle(Vector2(0, -50), 3.5, ink)

# --- A treasure chest: a big leather-bound tome, strapped shut (variant 1 = already opened) ------------
func _draw_chest() -> void:
	_shadow(22.0)
	var opened := variant == 1
	var leather := Color("7a3b2e")
	var worn := Color("93523f")
	var page := Color("f1e7cd")
	var ink := Color("2a1b0f")
	var gilt := Color("d9b45a")
	DrawKit.shape(self, PackedVector2Array([Vector2(-21, 0), Vector2(21, 0), Vector2(21, -7), Vector2(-21, -7)]), leather, ink, 2.4, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(-19, -7), Vector2(19, -7), Vector2(19, -17), Vector2(-19, -17)]), page, ink, 2.0, _seed + 1.0)
	for k in 3:
		draw_line(Vector2(-17, -9.5 - k * 3), Vector2(17, -9.5 - k * 3), Color(ink, 0.22), 1.0)
	if opened:
		var cover := PackedVector2Array([Vector2(-21, -17), Vector2(21, -17), Vector2(17, -38), Vector2(-17, -38)])
		DrawKit.shape(self, cover, leather.darkened(0.15), ink, 2.4, _seed + 2.0)
		draw_rect(Rect2(-13, -34, 26, 2), Color(gilt, 0.7))
		draw_rect(Rect2(-15, -20, 30, 3), Color(1.0, 0.92, 0.55, 0.55))
		for k in 3:
			draw_line(Vector2(-10 + k * 10, -20), Vector2(-12 + k * 12, -30), Color(1.0, 0.92, 0.55, 0.3), 2.0)
	else:
		var cover2 := PackedVector2Array([Vector2(-21, -17), Vector2(21, -17), Vector2(21, -26), Vector2(-21, -26)])
		DrawKit.shape(self, cover2, worn, ink, 2.4, _seed + 2.0)
		draw_rect(Rect2(-21, -26, 6, 9), leather.darkened(0.2))
		draw_rect(Rect2(-21, -26, 42, 9), ink, false, 2.0)
		for cx in [-19.0, 19.0]:
			draw_rect(Rect2(cx - 2, -25, 4, 3), gilt)
		draw_line(Vector2(-12, -23.5), Vector2(12, -23.5), Color(gilt, 0.65), 1.4)
		draw_rect(Rect2(-3.5, -30, 7, 21), Color("5b2b22"))
		draw_rect(Rect2(-3.5, -30, 7, 21), ink, false, 1.6)
		draw_circle(Vector2(0, -21), 3.6, gilt)
		draw_arc(Vector2(0, -21), 3.6, 0.0, TAU, 12, ink, 1.4)
		if Settings.gfx_on("glow"):
			draw_circle(Vector2(0, -20), 22.0 + sin(_t * 3.0) * 2.0, Color(Palette.GOLD, 0.07))
