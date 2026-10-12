class_name Npc
extends StaticBody2D
## Archetypes who are fading. Before restoration they are graphite
## placeholders mumbling Lorem ipsum; after, they are people again.

enum Kind { BLACKSMITH, CHILD, BAKER }

var kind: Kind = Kind.BLACKSMITH
var display_name := "Lorem Ipsum"
var named := false          # name revealed (Garrick remembers himself mid-scene)
var lift := 0.0             # elevation of the cell it stands on, in px
var tearful := false        # a single ink-blue tear for the emotional beat
var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	_seed = position.x * 0.01 + position.y * 0.017
	_t = _seed * 5.0
	var poly := CollisionPolygon2D.new()
	poly.polygon = Iso.diamond(Vector2.ZERO, 0.4)
	add_child(poly)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func restoration() -> float:
	return GameState.restored_at(global_position)

func _fill(c: Color, r: float) -> Color:
	# Missing: desaturated toward static gray. Restored: the full cel color.
	return Palette.ghostify(c, r).lerp(Palette.STATIC_GRAY, (1.0 - r) * 0.35)

func _in_body(p: Vector2) -> bool:
	var t := (p - Vector2(0, -26)) / Vector2(15, 16)
	var h := (p - Vector2(0, -50)) / Vector2(12, 12)
	return t.length() < 1.0 or h.length() < 1.0 or (absf(p.x) < 9.0 and p.y > -12.0 and p.y < 0.0)

func _draw() -> void:
	var r := restoration()
	var pen := Palette.STATIC_GRAY.lightened(0.35).lerp(Palette.OUTLINE, r)
	var s := 0.78 if kind == Kind.CHILD else 1.0
	var breathe := sin(_t * 2.0) * 1.2
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 16.0 * s, Color(0.15, 0.1, 0.05, 0.2))
	if r > 0.02:
		# Restored: a soft cyan glow haloing the whole figure (as in the character sheets).
		draw_set_transform(Vector2(0, -lift - 30.0 * s), 0.0, Vector2(s, s))
		var pulse := 0.85 + 0.15 * sin(_t * 1.6)
		for k in 4:
			draw_colored_polygon(DrawKit.ellipse(Vector2.ZERO, 22.0 + k * 7.0, 36.0 + k * 8.0, 24), Color(Palette.CYAN, (0.17 - k * 0.035) * r * pulse))
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	draw_set_transform(Vector2(0, breathe * 0.3 - lift), 0.0, Vector2(s, s))

	var shirt := Palette.RUST
	var skin := Color("e9b58f")
	match kind:
		Kind.CHILD:
			shirt = Color("6f9fcf")
		Kind.BAKER:
			shirt = Color("f0e6d2")
	# Legs
	DrawKit.shape(self, PackedVector2Array([Vector2(-9, 0), Vector2(-2, 0), Vector2(-3, -12), Vector2(-9, -12)]), _fill(Color("4a3a30"), r), pen, 1.6, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(2, 0), Vector2(9, 0), Vector2(9, -12), Vector2(3, -12)]), _fill(Color("4a3a30"), r), pen, 1.6, _seed + 1.0)
	# Torso
	var torso := DrawKit.ellipse(Vector2(0, -26 + breathe * 0.4), 15.0, 16.0, 18, 0.06, _seed)
	DrawKit.shape(self, torso, _fill(shirt, r), pen, 2.0, _seed + 2.0)
	if kind == Kind.BLACKSMITH or kind == Kind.BAKER:
		var apron := PackedVector2Array([Vector2(-10, -28), Vector2(10, -28), Vector2(12, -9), Vector2(-12, -9)])
		DrawKit.shape(self, apron, _fill(Color("6b4a33") if kind == Kind.BLACKSMITH else Color("fffaf0"), r), pen, 1.6, _seed + 3.0)
	# Head
	var head_c := Vector2(0, -50 + breathe * 0.6)
	var hr := 12.0 if kind != Kind.CHILD else 13.5
	DrawKit.shape(self, DrawKit.ellipse(head_c, hr, hr, 18, 0.05, _seed + 4.0), _fill(skin, r), pen, 2.0, _seed + 4.0)
	match kind:
		Kind.BLACKSMITH:
			# Gray beard and brow: an old hero.
			var beard := PackedVector2Array([head_c + Vector2(-10, 2), head_c + Vector2(10, 2), head_c + Vector2(6, 18), head_c + Vector2(0, 21), head_c + Vector2(-6, 18)])
			DrawKit.shape(self, beard, _fill(Color("c9c5bd"), r), pen, 1.6, _seed + 5.0)
			DrawKit.line(self, head_c + Vector2(-9, -6), head_c + Vector2(-2, -4), pen, 2.6, _seed + 6.0, 0.3)
			DrawKit.line(self, head_c + Vector2(2, -4), head_c + Vector2(9, -6), pen, 2.6, _seed + 7.0, 0.3)
			# Hammer in hand
			DrawKit.line(self, Vector2(14, -30), Vector2(26, -44), _fill(Palette.WOOD, maxf(r, 0.0)).lerp(pen, 1.0 - r), 3.0, _seed + 8.0, 0.3)
			DrawKit.shape(self, PackedVector2Array([Vector2(20, -50), Vector2(33, -42), Vector2(30, -37), Vector2(17, -45)]), _fill(Color("8e8e96"), r), pen, 1.6, _seed + 9.0)
		Kind.BAKER:
			# Tall chef's hat.
			var hat := PackedVector2Array([head_c + Vector2(-10, -8), head_c + Vector2(10, -8), head_c + Vector2(12, -26), head_c + Vector2(0, -32), head_c + Vector2(-12, -26)])
			DrawKit.shape(self, hat, _fill(Color("fffaf0"), r), pen, 1.8, _seed + 5.0)
		Kind.CHILD:
			# Messy tuft of hair.
			for i in 4:
				DrawKit.line(self, head_c + Vector2(-6 + i * 4, -hr + 1), head_c + Vector2(-9 + i * 6, -hr - 8), pen, 2.0, _seed + i, 0.4)
	# Face
	var look := sin(_t * 0.7) * 1.2
	draw_circle(head_c + Vector2(-4.5 + look, -1), 1.8, pen)
	draw_circle(head_c + Vector2(4.5 + look, -1), 1.8, pen)
	var smile := 0.2 + 0.7 * r
	# Solemn by default: a level mouth for the adults, a small smile only for the child.
	var my := 5.5 if kind != Kind.BLACKSMITH else 8.5
	if kind == Kind.CHILD:
		draw_arc(head_c + Vector2(look * 0.5, my - 1.0), 3.5, 0.5, PI - 0.5, 8, pen, 1.8, true)
	else:
		draw_line(head_c + Vector2(look * 0.5 - 3.0, my), head_c + Vector2(look * 0.5 + 3.0, my + 0.5 * smile - 0.3), pen, 1.8)
	if tearful:
		var drip := fmod(_t * 0.5, 1.0)
		draw_circle(head_c + Vector2(6.5, 4.0 + drip * 14.0), 2.3 - drip, Color(Palette.TEAR, 0.95 * (1.0 - drip * 0.6)))
		draw_line(head_c + Vector2(6.5, 2.0), head_c + Vector2(6.5, 4.0 + drip * 14.0), Color(Palette.TEAR, 0.5), 1.4)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)

	# Missing: television-static speckle across the silhouette, purple glitch tears,
	# and a swirl of corruption circling the figure.
	if r < 0.98:
		draw_set_transform(Vector2(0, breathe * 0.3 - lift), 0.0, Vector2(s, s))
		var m := 1.0 - r
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 9.0) * 7919 + int(_seed * 1000.0)
		for i in 90:
			var p := Vector2(rng.randf_range(-17.0, 17.0), rng.randf_range(-64.0, 0.0))
			if not _in_body(p):
				continue
			var v := rng.randf()
			var col := Color.WHITE if v > 0.5 else (Palette.GLITCH if v > 0.38 else Color.BLACK)
			draw_rect(Rect2(p, Vector2(2.2, 2.2)), Color(col, m * 0.85))
		for j in 2:
			if rng.randf() > 0.45:
				var y := rng.randf_range(-60.0, -4.0)
				draw_rect(Rect2(-18.0 + rng.randf_range(-6.0, 6.0), y, rng.randf_range(10.0, 26.0), 2.0), Color(Palette.GLITCH, m * 0.9))
		for a in 3:
			var ang := _t * 1.4 + a * TAU / 3.0
			draw_arc(Vector2(0, -30), 26.0 + a * 4.0, ang, ang + 1.3, 10, Color(Palette.GLITCH, m * 0.55), 2.0, true)

	# Lorem ipsum: placeholder words drift up off the head until they're written in.
	if r < 0.98:
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
		var font := ThemeDB.fallback_font
		var idx := int(_t * 0.9 + _seed * 10.0) % Story.LOREM.size()
		var rise := fmod(_t * 0.9 + _seed * 10.0, 1.0)
		var a := (1.0 - r) * (1.0 - rise) * 0.9
		draw_string(font, Vector2(-22, -82 - rise * 14.0), Story.LOREM[idx], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(Palette.PENCIL.darkened(0.2), a))
