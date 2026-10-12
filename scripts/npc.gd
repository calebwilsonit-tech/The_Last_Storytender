class_name Npc
extends StaticBody2D
## Archetypes who are fading. Before restoration they are graphite
## placeholders mumbling Lorem ipsum; after, they are people again.

enum Kind { BLACKSMITH, CHILD, BAKER }

var kind: Kind = Kind.BLACKSMITH
var display_name := "Lorem Ipsum"
var npc_id := ""           # garrick / pip / maud: restored one person at a time
var named := false          # name revealed (Garrick remembers himself mid-scene)
var lift := 0.0             # elevation of the cell it stands on, in px
var tearful := false        # a single ink-blue tear for the emotional beat
var _t := 0.0
var _seed := 0.0
var _gate := RedrawGate.new()

func _ready() -> void:
	_seed = position.x * 0.01 + position.y * 0.017
	_t = _seed * 5.0
	var poly := CollisionPolygon2D.new()
	poly.polygon = Iso.diamond(Vector2.ZERO, 0.4)
	add_child(poly)

func _process(delta: float) -> void:
	_t += delta
	if _gate.ok(delta, self):
		queue_redraw()

func restoration() -> float:
	return GameState.restored_for(npc_id, global_position)

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

	var art := Skins.art()
	var drawn := false
	if art != null:
		var ctx := {"t": _t, "restored": r, "tearful": tearful, "dir": _look_dir(), "origin": Vector2(0, breathe * 0.3 - lift), "scale": 1.0}
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		drawn = FigureBake.draw(art, self, art_key(), ctx)
		draw_set_transform(Vector2(0, breathe * 0.3 - lift), 0.0, Vector2(s, s))
	if not drawn:
		_draw_body_original(r, pen, s, breathe)
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


## The person this NPC is, for art styles: garrick / pip / maud, or a generic kind.
func art_key() -> String:
	if npc_id != "":
		return npc_id
	return {Kind.BLACKSMITH: "garrick", Kind.CHILD: "pip", Kind.BAKER: "maud"}.get(kind, "garrick")

var _face_cur := Vector2(0, 1)

## People turn to look at the Storytender when close, otherwise they face the camera.
func _look_dir() -> Vector2:
	var want := Vector2(0, 1)
	var pl := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if pl != null and pl is Node2D:
		var d: Vector2 = (pl as Node2D).global_position - global_position
		if d.length() < 260.0 and d.length() > 4.0:
			want = d.normalized()
	_face_cur = _face_cur.lerp(want, 0.08).normalized() if _face_cur.lerp(want, 0.08).length() > 0.05 else want
	return _face_cur

## Rotates a point about a pivot (used for the swinging arms and hammer).
func _rot(p: Vector2, pivot: Vector2, ang: float) -> Vector2:
	return pivot + (p - pivot).rotated(ang)

func _draw_body_original(r: float, pen: Color, s: float, breathe: float) -> void:
	var shirt := Palette.RUST
	var skin := Color("e9b58f")
	match kind:
		Kind.CHILD:
			shirt = Color("6f9fcf")
		Kind.BAKER:
			shirt = Color("f0e6d2")
	# Missing people only stir; restored people are properly alive.
	var live := 0.35 + 0.65 * r
	var t := _t
	var lean := sin(t * 1.3 + _seed) * 1.1 * live
	var blink := fmod(t * 0.55 + _seed * 3.0, 3.0) < 0.14
	# Legs (the child taps a foot while waiting).
	var tap := maxf(0.0, sin(t * 3.4 + _seed)) * 2.6 * live if kind == Kind.CHILD else 0.0
	var shift := sin(t * 0.8 + _seed) * 0.8 * live
	DrawKit.shape(self, PackedVector2Array([Vector2(-9 + shift, 0), Vector2(-2 + shift, 0), Vector2(-3, -12), Vector2(-9, -12)]), _fill(Color("4a3a30"), r), pen, 1.6, _seed)
	DrawKit.shape(self, PackedVector2Array([Vector2(2, -tap), Vector2(9, -tap), Vector2(9, -12), Vector2(3, -12)]), _fill(Color("4a3a30"), r), pen, 1.6, _seed + 1.0)
	# Torso (breathes, leans a little)
	var torso := DrawKit.ellipse(Vector2(lean * 0.5, -26 + breathe * 0.4), 15.0 + breathe * 0.25, 16.0 + breathe * 0.35, 18, 0.06, _seed)
	DrawKit.shape(self, torso, _fill(shirt, r), pen, 2.0, _seed + 2.0)
	if kind == Kind.BLACKSMITH or kind == Kind.BAKER:
		var apron := PackedVector2Array([Vector2(-10 + lean * 0.4, -28), Vector2(10 + lean * 0.4, -28), Vector2(12, -9), Vector2(-12, -9)])
		DrawKit.shape(self, apron, _fill(Color("6b4a33") if kind == Kind.BLACKSMITH else Color("fffaf0"), r), pen, 1.6, _seed + 3.0)
	# Arms: idle swing; Garrick lifts and taps his hammer, Maud kneads, Pip fidgets.
	var arm_c := _fill(shirt.darkened(0.08), r)
	var hand_c := _fill(skin, r)
	var kn := pow(maxf(0.0, sin(t * 1.15 + _seed)), 3.0) * live          # a slow beat: lift, then tap
	for side: float in [-1.0, 1.0]:
		var sh := Vector2(side * 13.0 + lean * 0.5, -35.0 + breathe * 0.3)
		var a: float = side * 0.16 + sin(t * 1.6 + side * 1.7 + _seed) * 0.07 * live
		var len: float = 22.0
		if kind == Kind.BAKER:
			# elbows out, hands working the dough in front
			a = side * 0.55 - sin(t * 3.0 + side * 1.4) * 0.28 * live
			len = 18.0
		elif kind == Kind.CHILD:
			a += sin(t * 2.4 + side) * 0.12 * live
			len = 18.0
		elif kind == Kind.BLACKSMITH and side > 0.0:
			a = 0.9 - kn * 0.9
		var hand := sh + Vector2(sin(a) * len, cos(a) * len)
		var perp := (hand - sh).orthogonal().normalized() * 3.4
		DrawKit.shape(self, PackedVector2Array([sh + perp, sh - perp, hand - perp * 0.8, hand + perp * 0.8]), arm_c, pen, 1.6, _seed + 20.0 + side)
		draw_circle(hand, 3.4, hand_c)
		draw_arc(hand, 3.4, 0.0, TAU, 10, pen, 1.4, true)
		if kind == Kind.BLACKSMITH and side > 0.0:
			var tilt := -0.9 * kn
			var haft_tip := _rot(hand + Vector2(10, -16), hand, tilt)
			DrawKit.line(self, hand, haft_tip, _fill(Palette.WOOD, maxf(r, 0.0)).lerp(pen, 1.0 - r), 3.0, _seed + 8.0, 0.2)
			var head: PackedVector2Array = PackedVector2Array([hand + Vector2(6, -22), hand + Vector2(19, -14), hand + Vector2(16, -9), hand + Vector2(3, -17)])
			for i in head.size():
				head[i] = _rot(head[i], hand, tilt)
			DrawKit.shape(self, head, _fill(Color("8e8e96"), r), pen, 1.6, _seed + 9.0)
	# Head
	var head_c := Vector2(lean + sin(t * 0.9 + _seed * 2.0) * 0.8 * live, -50 + breathe * 0.6 + (sin(t * 1.6 + _seed) * 0.6 * live))
	var hr := 12.0 if kind != Kind.CHILD else 13.5
	DrawKit.shape(self, DrawKit.ellipse(head_c, hr, hr, 18, 0.05, _seed + 4.0), _fill(skin, r), pen, 2.0, _seed + 4.0)
	match kind:
		Kind.BLACKSMITH:
			# Gray beard and brow: an old hero.
			var beard := PackedVector2Array([head_c + Vector2(-10, 2), head_c + Vector2(10, 2), head_c + Vector2(6, 18 + breathe * 0.3), head_c + Vector2(0, 21 + breathe * 0.5), head_c + Vector2(-6, 18 + breathe * 0.3)])
			DrawKit.shape(self, beard, _fill(Color("c9c5bd"), r), pen, 1.6, _seed + 5.0)
			var brow := -2.0 * kn
			DrawKit.line(self, head_c + Vector2(-9, -6 + brow), head_c + Vector2(-2, -4 + brow), pen, 2.6, _seed + 6.0, 0.3)
			DrawKit.line(self, head_c + Vector2(2, -4 + brow), head_c + Vector2(9, -6 + brow), pen, 2.6, _seed + 7.0, 0.3)
		Kind.BAKER:
			# Tall chef's hat, wobbling a touch as she works.
			var wob := sin(t * 3.0 + _seed) * 1.6 * live
			var hat := PackedVector2Array([head_c + Vector2(-10, -8), head_c + Vector2(10, -8), head_c + Vector2(12 + wob, -26), head_c + Vector2(wob * 1.4, -32), head_c + Vector2(-12 + wob, -26)])
			DrawKit.shape(self, hat, _fill(Color("fffaf0"), r), pen, 1.8, _seed + 5.0)
		Kind.CHILD:
			# Messy tuft of hair that bounces.
			for i in 4:
				var sw := sin(t * 4.0 + i * 1.3 + _seed) * 1.8 * live
				DrawKit.line(self, head_c + Vector2(-6 + i * 4, -hr + 1), head_c + Vector2(-9 + i * 6 + sw, -hr - 8), pen, 2.0, _seed + i, 0.4)
	# Face
	var look := sin(t * 0.7 + _seed) * 1.2 * live
	if blink:
		draw_line(head_c + Vector2(-6.3 + look, -1), head_c + Vector2(-2.7 + look, -1), pen, 1.8)
		draw_line(head_c + Vector2(2.7 + look, -1), head_c + Vector2(6.3 + look, -1), pen, 1.8)
	else:
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
		var drip := fmod(t * 0.5, 1.0)
		draw_circle(head_c + Vector2(6.5, 4.0 + drip * 14.0), 2.3 - drip, Color(Palette.TEAR, 0.95 * (1.0 - drip * 0.6)))
		draw_line(head_c + Vector2(6.5, 2.0), head_c + Vector2(6.5, 4.0 + drip * 14.0), Color(Palette.TEAR, 0.5), 1.4)
	# Maud's flour: a little puff drifts up whenever she works the dough.
	if kind == Kind.BAKER and r > 0.4:
		for i in 3:
			var ph := fmod(t * 0.6 + i * 0.33 + _seed, 1.0)
			draw_circle(Vector2(-6 + i * 6 + sin(t * 2.0 + i) * 3.0, -20 - ph * 26.0), 2.0 + ph * 2.5, Color(1, 0.98, 0.92, 0.45 * (1.0 - ph) * r))
