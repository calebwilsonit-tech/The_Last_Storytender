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
	var f := Palette.ghostify(c, r)
	f.a = r
	return f

func _draw() -> void:
	var r := restoration()
	var pen := Palette.PENCIL.lerp(Palette.INK, r)
	var s := 0.78 if kind == Kind.CHILD else 1.0
	var breathe := sin(_t * 2.0) * 1.2
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 16.0 * s, Color(0.15, 0.1, 0.05, 0.2))
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
	draw_arc(head_c + Vector2(look * 0.5, 5.5 if kind != Kind.BLACKSMITH else 8.0), 4.5, 0.4, PI - 0.4, 8, pen, 1.6 + 0.0 * smile, true)
	if tearful:
		var drip := fmod(_t * 0.5, 1.0)
		draw_circle(head_c + Vector2(6.5, 4.0 + drip * 14.0), 2.3 - drip, Color(Palette.TEAR, 0.95 * (1.0 - drip * 0.6)))
		draw_line(head_c + Vector2(6.5, 2.0), head_c + Vector2(6.5, 4.0 + drip * 14.0), Color(Palette.TEAR, 0.5), 1.4)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)

	# Lorem ipsum: placeholder words drift up off the head until they're written in.
	if r < 0.98:
		var font := ThemeDB.fallback_font
		var idx := int(_t * 0.9 + _seed * 10.0) % Story.LOREM.size()
		var rise := fmod(_t * 0.9 + _seed * 10.0, 1.0)
		var a := (1.0 - r) * (1.0 - rise) * 0.9
		draw_string(font, Vector2(-22, -82 - rise * 14.0), Story.LOREM[idx], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(Palette.PENCIL.darkened(0.2), a))
