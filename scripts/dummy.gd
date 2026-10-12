class_name Dummy
extends StaticBody2D
## Garrick's training dummy: a sack of straw on a post. It never hits back.

signal struck

var hit_r := 20.0
var elev := 0.0
var _wobble := 0.0
var _t := 0.0
var _splats: Array[Dictionary] = []

func _ready() -> void:
	var poly := CollisionPolygon2D.new()
	poly.polygon = Iso.diamond(Vector2.ZERO, 0.45)
	add_child(poly)
	add_to_group("hittables")

func hurt(_dmg: float, dir_ground: Vector2) -> void:
	_wobble = 1.0
	for i in 5:
		_splats.append({"pos": Vector2.from_angle(randf() * TAU) * randf_range(6.0, 20.0) + Vector2(0, -34), "r": randf_range(1.6, 3.4), "age": 0.0})
	struck.emit()

var _gate := RedrawGate.new()

func _process(delta: float) -> void:
	_t += delta
	_wobble = maxf(_wobble - delta * 1.6, 0.0)
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s): return s.age < 1.2)
	if _wobble > 0.0 or not _splats.is_empty() or _gate.ok(delta, self):
		queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.25))
	var rot := sin(_t * 22.0) * _wobble * 0.16
	var art := Skins.art()
	if art != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if art.draw_prop(self, "prop_dummy", {"t": _t, "rot": rot, "origin": Vector2(0, -elev), "scale": 1.0}):
			draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
			for s in _splats:
				draw_circle(s.pos, s.r * (1.0 - float(s.age) / 1.2), Color(Palette.INK, 0.85 * (1.0 - float(s.age) / 1.2)))
			return
	draw_set_transform(Vector2(0, -elev), rot, Vector2.ONE)
	var wood := Palette.WOOD
	draw_rect(Rect2(-3, -40, 6, 40), wood)
	draw_rect(Rect2(-3, -40, 6, 40), Palette.OUTLINE, false, 2.4)
	# Crossbar arms.
	draw_rect(Rect2(-22, -48, 44, 5), wood.lightened(0.1))
	draw_rect(Rect2(-22, -48, 44, 5), Palette.OUTLINE, false, 2.4)
	# Straw-stuffed sack torso with a painted target.
	var sack := DrawKit.ellipse(Vector2(0, -32), 15.0, 19.0, 18, 0.08, 3.0)
	draw_colored_polygon(sack, Color("c9ac75"))
	var loop := sack.duplicate()
	loop.append(sack[0])
	draw_polyline(loop, Palette.OUTLINE, 2.6, true)
	for r in [11.0, 7.0, 3.0]:
		draw_arc(Vector2(0, -32), r, 0.0, TAU, 20, Color(Palette.CRITIC_RED, 0.8), 2.0, true)
	for i in 6:
		var x := -10.0 + i * 4.0
		draw_line(Vector2(x, -14), Vector2(x + 2, -8), Color("e0c98c"), 1.6)
	# Head: a smaller sack with stitched X eyes.
	var head := DrawKit.ellipse(Vector2(0, -58), 10.0, 10.0, 14, 0.06, 7.0)
	draw_colored_polygon(head, Color("d6bb85"))
	var hl := head.duplicate()
	hl.append(head[0])
	draw_polyline(hl, Palette.OUTLINE, 2.4, true)
	for sx in [-4.0, 4.0]:
		draw_line(Vector2(sx - 2, -61), Vector2(sx + 2, -57), Palette.OUTLINE, 1.6)
		draw_line(Vector2(sx - 2, -57), Vector2(sx + 2, -61), Palette.OUTLINE, 1.6)
	draw_line(Vector2(-4, -53), Vector2(4, -53), Palette.OUTLINE, 1.6)
	for s in _splats:
		draw_circle(s.pos, s.r * (1.0 - float(s.age) / 1.2), Color(Palette.INK, 0.85 * (1.0 - float(s.age) / 1.2)))
