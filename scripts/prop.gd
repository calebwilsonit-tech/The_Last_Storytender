class_name Prop
extends StaticBody2D
## Procedurally inked scenery. Objects with `ghost = true` begin as graphite
## pencil sketches and fill with color as the restoration wave reaches them.

enum Kind { TREE, HOUSE, FORGE, CRYSTAL, SIGN, SWORD }

var kind: Kind = Kind.TREE
var ghost := false
var variant := 0
var lift := 0.0            # elevation of the cell it stands on, in px
var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	_seed = position.x * 0.013 + position.y * 0.007
	_t = _seed * 3.0
	var poly := CollisionPolygon2D.new()
	match kind:
		Kind.TREE, Kind.SIGN:
			poly.polygon = Iso.diamond(Vector2.ZERO, 0.45)
		Kind.HOUSE, Kind.FORGE:
			poly.polygon = Iso.diamond(Vector2.ZERO, 1.8)
		_:
			poly = null
	if poly:
		add_child(poly)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

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
	match kind:
		Kind.TREE: _draw_tree()
		Kind.HOUSE: _draw_house(r, false)
		Kind.FORGE: _draw_house(r, true)
		Kind.CRYSTAL: _draw_crystal()
		Kind.SIGN: _draw_sign()
		Kind.SWORD: _draw_sword()

func _shadow(rx: float) -> void:
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, rx, Color(0.15, 0.1, 0.05, 0.18))
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)

# --- Tree ---------------------------------------------------------------------
func _draw_tree() -> void:
	_shadow(20.0)
	var sway := sin(_t * 1.1) * 1.6
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
func _draw_house(r: float, forge: bool) -> void:
	var pen := Palette.PENCIL.lerp(Palette.INK, r)
	var pw := 2.0
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
	if forge:
		_draw_forge_fire(DrawKit.face(door, 0.5, 0.0), r)
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
