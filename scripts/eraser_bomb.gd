class_name EraserBomb
extends Node2D
## Thrown Eraser Crumbs: arc through the air, fizz for a moment, then rub out
## every Error in a small radius (hurt() on anything "hittable").

signal exploded(pos: Vector2)

const FLY := 0.5
const FUSE := 0.45
const RADIUS := 85.0

var start := Vector2.ZERO
var goal := Vector2.ZERO
var elev := 0.0
var _t := 0.0
var _phase := "fly"
var _bits: Array[Vector2] = []

func _ready() -> void:
	position = start
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start.x * 7.0 + start.y)
	for i in 14:
		_bits.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.0))

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"fly":
			var p := clampf(_t / FLY, 0.0, 1.0)
			position = start.lerp(goal, p)
			if p >= 1.0:
				_phase = "fuse"
				_t = 0.0
		"fuse":
			if _t >= FUSE:
				_phase = "burst"
				_t = 0.0
				_explode()
		"burst":
			if _t > 0.6:
				queue_free()
				return
	queue_redraw()

func _explode() -> void:
	for e in get_tree().get_nodes_in_group("hittables"):
		if not is_instance_valid(e):
			continue
		var d: Vector2 = e.position - position
		var dg := Vector2(d.x, d.y * 2.0)
		var rad: float = e.get("hit_r") if e.get("hit_r") != null else 16.0
		if dg.length() < RADIUS + rad:
			e.hurt(5.0, dg.normalized() if dg.length() > 1.0 else Vector2.RIGHT)
	exploded.emit(position)

func _draw() -> void:
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if _phase == "fly":
		var p := clampf(_t / FLY, 0.0, 1.0)
		ItemIcon.draw_item(self, "eraser_crumbs", Vector2(0, -sin(PI * p) * 46.0 - 10.0), 34.0)
	elif _phase == "fuse":
		var blink := int(_t * 18.0) % 2 == 0
		ItemIcon.draw_item(self, "eraser_crumbs", Vector2(0, -8), 34.0)
		if blink:
			draw_circle(Vector2(0, -12), 18.0, Color(1, 1, 1, 0.35))
	else:
		var p := _t / 0.6
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, RADIUS * p, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - p)), 6.0, true)
		draw_circle(Vector2.ZERO, RADIUS * p, Color(1, 0.95, 0.9, 0.22 * (1.0 - p)))
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
		# Paper scraps and eraser dust flung outward.
		for b in _bits:
			var q := b * RADIUS * p * Vector2(1, 0.5) + Vector2(0, -sin(PI * p) * 26.0)
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color(0.95, 0.65, 0.72, 1.0 - p))
