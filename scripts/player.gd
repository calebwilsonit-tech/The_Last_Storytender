class_name Player
extends CharacterBody2D
## The Storytender: a sentient doodle. 8-directional movement, "ink" health.
## Damage bleeds ink instead of blood; at zero ink the sketch crumples.

signal ink_changed(current: float, maximum: float)
signal crumpled
signal fell

@export var speed := 190.0
@export var accel := 1400.0
@export var friction := 1800.0
@export var max_ink := 100.0

var ink := 100.0
var is_crumpled := false
var is_falling := false
var _t := 0.0
var _splats: Array[Dictionary] = []  # {pos, radius, age}
var _look := 0.0

func _ready() -> void:
	ink = max_ink
	ink_changed.emit(ink, max_ink)

func _physics_process(delta: float) -> void:
	var locked := is_crumpled or is_falling or GameState.in_dialogue
	if locked:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	# WASD are screen directions. The 2:1 isometric plane is squashed
	# vertically, so halve the vertical speed to keep motion visually even.
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := Vector2(dir.x, dir.y * 0.5) * speed
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(target, accel * delta)
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
	if absf(velocity.x) > 8.0:
		_look = lerpf(_look, signf(velocity.x), 1.0 - exp(-10.0 * delta))
	queue_redraw()

func take_damage(amount: float, lethal: bool = true) -> void:
	if is_crumpled:
		return
	ink = maxf(ink - amount, 0.0 if lethal else 1.0)
	for i in int(amount / 3.0) + 2:
		_splats.append({
			"pos": Vector2.from_angle(randf() * TAU) * randf_range(8.0, 34.0) * Vector2(1, 0.5),
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

## Swallowed by a plot hole: shrink into the void, then main.gd respawns us.
func fall() -> void:
	if is_falling:
		return
	is_falling = true
	velocity = Vector2.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.15, 0.15), 0.55).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.55)
	await tw.finished
	fell.emit()

func respawn_at(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	scale = Vector2.ONE
	modulate.a = 1.0
	is_falling = false

func _draw() -> void:
	var inkc := Palette.INK
	for s in _splats:
		var fade: float = 1.0 - float(s.age) / 6.0
		draw_circle(s.pos, s.radius, Color(inkc, 0.8 * fade))
	# Contact shadow on the page.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.22))
	var moving := velocity.length() > 20.0
	var bob := -absf(sin(_t * 11.0)) * 3.0 if moving else sin(_t * 2.0) * 0.8
	draw_set_transform(Vector2(0, -20 + bob), 0.0, Vector2.ONE)
	if is_crumpled:
		draw_set_transform(Vector2(0, -8), 0.0, Vector2.ONE)
		_draw_crumpled(inkc)
		return
	# Hand-drawn doodle: wobbly outline, two eyes that look where you walk.
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * i / n
		var r := 16.0 + sin(a * 3.0 + _t * 3.0) * 1.2 + sin(a * 7.0 - _t * 2.0) * 0.6
		pts.append(Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, Palette.PAPER_LIGHT)
	pts.append(pts[0])
	draw_polyline(pts, inkc, 2.5, true)
	var ex := _look * 2.5
	draw_circle(Vector2(-5 + ex, -3), 2.2, inkc)
	draw_circle(Vector2(5 + ex, -3), 2.2, inkc)
	draw_arc(Vector2(ex * 0.6, 3), 5.0, 0.2, PI - 0.2, 8, inkc, 1.8, true)
	# A single pencil-line scribble antenna: the marginalia's one flourish.
	draw_polyline(PackedVector2Array([Vector2(-2, -16), Vector2(-5, -24), Vector2(1, -28), Vector2(-1, -34)]), inkc, 2.0, true)

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
