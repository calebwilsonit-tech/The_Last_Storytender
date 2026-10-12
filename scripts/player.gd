class_name Player
extends CharacterBody2D
## The Storytender: a sentient doodle. 8-directional movement, "ink" health.
## Damage bleeds ink instead of blood; at zero ink the sketch crumples.

signal ink_changed(current: float, maximum: float)
signal crumpled

@export var speed := 220.0
@export var accel := 1400.0
@export var friction := 1800.0
@export var max_ink := 100.0

var ink := 100.0
var is_crumpled := false
var _t := 0.0
var _splats: Array[Dictionary] = []  # {pos, radius, age}

func _ready() -> void:
	ink = max_ink
	ink_changed.emit(ink, max_ink)

func _physics_process(delta: float) -> void:
	if is_crumpled:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	if Input.is_action_just_pressed("debug_damage"):
		take_damage(12.0)
	if Input.is_action_just_pressed("debug_heal"):
		restore_ink(100.0)

func _process(delta: float) -> void:
	_t += delta
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s): return s.age < 6.0)
	queue_redraw()

func take_damage(amount: float) -> void:
	if is_crumpled:
		return
	ink = maxf(ink - amount, 0.0)
	# Ink splatter: more drops the harder the hit.
	for i in int(amount / 3.0) + 2:
		var a := randf() * TAU
		_splats.append({
			"pos": Vector2.from_angle(a) * randf_range(8.0, 34.0),
			"radius": randf_range(2.0, 6.0),
			"age": 0.0,
		})
	ink_changed.emit(ink, max_ink)
	if ink <= 0.0:
		is_crumpled = true
		crumpled.emit()

func restore_ink(amount: float) -> void:
	ink = minf(ink + amount, max_ink)
	is_crumpled = false
	ink_changed.emit(ink, max_ink)

func _draw() -> void:
	var inkc := Color(0.08, 0.07, 0.12)
	# Splats left behind by damage (drawn first, fade out).
	for s in _splats:
		var fade: float = 1.0 - float(s.age) / 6.0
		draw_circle(s.pos, s.radius, Color(inkc, 0.8 * fade))
	if is_crumpled:
		_draw_crumpled(inkc)
		return
	# Hand-drawn doodle: wobbly outline, two eyes, a little flame-tail.
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * i / n
		var r := 16.0 + sin(a * 3.0 + _t * 3.0) * 1.2 + sin(a * 7.0 - _t * 2.0) * 0.6
		pts.append(Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, Color(0.96, 0.92, 0.80))
	pts.append(pts[0])
	draw_polyline(pts, inkc, 2.5, true)
	draw_circle(Vector2(-5, -3), 2.2, inkc)
	draw_circle(Vector2(5, -3), 2.2, inkc)
	draw_arc(Vector2(0, 3), 5.0, 0.2, PI - 0.2, 8, inkc, 1.8, true)

func _draw_crumpled(inkc: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		pts.append(Vector2.from_angle(a) * rng.randf_range(8.0, 15.0))
	draw_colored_polygon(pts, Color(0.88, 0.82, 0.68))
	pts.append(pts[0])
	draw_polyline(pts, inkc, 2.0, true)
	for i in 4:
		draw_line(Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
			Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)), Color(inkc, 0.6), 1.2)
