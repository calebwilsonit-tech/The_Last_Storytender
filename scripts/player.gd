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
var lantern_power := 1.0   # glow strength; brighter inside memories
var speed_mult := 1.0      # debuffs (The Critic's words) slow the Storytender
var _walk := 0.0
var _invuln := 0.0
var _facing_right := true
var _facing_back := false
var elev := 0.0            # visual elevation in px; physics stays on the ground plane

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
	var target := Vector2(dir.x, dir.y * 0.5) * speed * speed_mult
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
	_invuln = maxf(_invuln - delta, 0.0)
	if velocity.length() > 20.0:
		_walk += velocity.length() * delta * 0.075
		if absf(velocity.x) > 12.0:
			_facing_right = velocity.x > 0.0
		if velocity.y < -6.0:
			_facing_back = true
		elif velocity.y > 6.0:
			_facing_back = false
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s): return s.age < 6.0)
	if absf(velocity.x) > 8.0:
		_look = lerpf(_look, signf(velocity.x), 1.0 - exp(-10.0 * delta))
	queue_redraw()

func take_damage(amount: float, lethal: bool = true) -> void:
	if is_crumpled or (_invuln > 0.0 and lethal):
		return
	if lethal:
		_invuln = 0.9
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
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	for sp in _splats:
		var fade: float = 1.0 - float(sp.age) / 6.0
		draw_circle(sp.pos, sp.radius, Color(inkc, 0.8 * fade))
	var flick := 0.85 + 0.15 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
	# Lantern light pooled on the ground around the Storytender.
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	for k in 5:
		draw_circle(Vector2(0, 0), 92.0 - k * 15.0, Color(Palette.CYAN, (0.022 + 0.006 * k) * flick * lantern_power))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.30))
	if is_crumpled:
		draw_set_transform(Vector2(0, -8 - elev), 0.0, Vector2.ONE)
		_draw_crumpled(inkc)
		return

	var moving := velocity.length() > 20.0
	var ph := _walk
	var bob := -absf(sin(ph)) * 2.6 if moving else sin(_t * 1.8) * 0.7
	var fx := 1.0 if _facing_right else -1.0
	draw_set_transform(Vector2(0, bob - elev), 0.0, Vector2(fx * 0.8, 0.8))
	if _invuln > 0.0 and int(_t * 20.0) % 2 == 0:
		return   # blink while briefly invulnerable
	if _facing_back:
		_draw_back(ph, moving, flick)
	else:
		_draw_front(ph, moving, flick)

func _poly(pts: PackedVector2Array, fill: Color, w: float = 2.4) -> void:
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Palette.OUTLINE, w, true)

func _legs(ph: float, moving: bool) -> void:
	var a := sin(ph) * 4.0 if moving else 0.0
	var lift_a := maxf(0.0, sin(ph)) * 3.0 if moving else 0.0
	var lift_b := maxf(0.0, -sin(ph)) * 3.0 if moving else 0.0
	# Back leg first so the front leg overlaps it.
	_poly(PackedVector2Array([Vector2(1 - a * 0.4, -19), Vector2(7 - a * 0.4, -19), Vector2(8 - a, -7 - lift_b), Vector2(2 - a, -7 - lift_b)]), Palette.TROUSERS)
	_poly(PackedVector2Array([Vector2(1 - a, -8 - lift_b), Vector2(9 - a, -8 - lift_b), Vector2(10 - a, -1 - lift_b), Vector2(0 - a, -1 - lift_b)]), Palette.LEATHER)
	_poly(PackedVector2Array([Vector2(-7 + a * 0.4, -19), Vector2(-1 + a * 0.4, -19), Vector2(-2 + a, -7 - lift_a), Vector2(-8 + a, -7 - lift_a)]), Palette.TROUSERS)
	_poly(PackedVector2Array([Vector2(-9 + a, -8 - lift_a), Vector2(-1 + a, -8 - lift_a), Vector2(0 + a, -1 - lift_a), Vector2(-10 + a, -1 - lift_a)]), Palette.LEATHER)

func _lantern(at: Vector2, flick: float) -> void:
	# Hanging lantern: chain, iron frame, glowing cyan core, soft halo.
	for k in 4:
		draw_circle(at + Vector2(0, 7), 26.0 - k * 5.0, Color(Palette.CYAN, 0.045 * flick * lantern_power))
	draw_line(at + Vector2(0, -5), at + Vector2(0, 0), Palette.OUTLINE, 2.0)
	_poly(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(3, 0), at + Vector2(5, 3), at + Vector2(-5, 3)]), Color("3a3f4a"), 2.0)
	_poly(PackedVector2Array([at + Vector2(-5, 3), at + Vector2(5, 3), at + Vector2(5, 13), at + Vector2(-5, 13)]), Color(Palette.CYAN, 0.95), 2.2)
	draw_line(at + Vector2(-5, 3), at + Vector2(5, 13), Color("3a3f4a"), 1.4)
	draw_line(at + Vector2(5, 3), at + Vector2(-5, 13), Color("3a3f4a"), 1.4)
	_poly(PackedVector2Array([at + Vector2(-6, 13), at + Vector2(6, 13), at + Vector2(5, 16), at + Vector2(-5, 16)]), Color("3a3f4a"), 2.0)

func _draw_front(ph: float, moving: bool, flick: float) -> void:
	var sway := sin(_t * 2.0) * 1.0
	var wave := sin(_t * 3.2) * 1.5 + (sin(ph * 2.0) * 1.5 if moving else 0.0)
	# Cloak hanging behind, ragged hem that flutters.
	_poly(PackedVector2Array([Vector2(-11, -42), Vector2(11, -42), Vector2(15 + wave, -9), Vector2(10, -4 + wave * 0.4), Vector2(3, -9), Vector2(-4, -3), Vector2(-10, -9), Vector2(-15 - wave, -8)]), Palette.CLOAK_DARK)
	# Backpack and scroll peeking over the far shoulder.
	_poly(PackedVector2Array([Vector2(-17, -45), Vector2(-9, -47), Vector2(-8, -24), Vector2(-17, -22)]), Color("7a5232"))
	_poly(PackedVector2Array([Vector2(-20, -53), Vector2(-8, -55), Vector2(-8, -47), Vector2(-20, -45)]), Color("d8c28f"), 2.2)
	draw_arc(Vector2(-20, -49), 3.4, 0.0, TAU * 0.85, 10, Palette.OUTLINE, 1.6)
	_legs(ph, moving)
	# Tunic with belt.
	_poly(PackedVector2Array([Vector2(-10, -43), Vector2(10, -43), Vector2(12, -18), Vector2(-12, -18)]), Palette.TUNIC)
	draw_polyline(PackedVector2Array([Vector2(-9, -41), Vector2(-10, -20)]), Color(1, 1, 1, 0.12), 3.0)
	draw_rect(Rect2(-12, -26, 24, 4), Palette.CLOAK_DARK)
	draw_rect(Rect2(-12, -26, 24, 4), Palette.OUTLINE, false, 2.0)
	draw_rect(Rect2(-2, -26, 4, 4), Color("c9a24e"))
	# Far arm hangs; near arm lifts the lantern.
	_poly(PackedVector2Array([Vector2(-12, -41), Vector2(-7, -41), Vector2(-9 - sway * 0.3, -24), Vector2(-14, -25)]), Palette.TUNIC.darkened(0.12), 2.6)
	draw_circle(Vector2(-11.5, -22), 3.0, Color("c8a888"))
	var hand := Vector2(15 + sway * 0.5, -30 + (sin(ph) * 2.0 if moving else 0.0))
	_poly(PackedVector2Array([Vector2(8, -41), Vector2(13, -40), hand + Vector2(3, 0), hand + Vector2(-3, 1)]), Palette.TUNIC.darkened(0.05), 2.6)
	draw_circle(hand, 3.2, Color("c8a888"))
	_lantern(hand + Vector2(0, 5), flick)
	# Scarf and hood: the face is a pool of shadow with two pale glints.
	_poly(PackedVector2Array([Vector2(-9, -45), Vector2(9, -45), Vector2(7, -39), Vector2(-7, -39)]), Palette.CLOAK_DARK, 2.6)
	var hood := PackedVector2Array([Vector2(-14, -45), Vector2(-17, -56), Vector2(-12, -68), Vector2(-3, -74), Vector2(4, -76), Vector2(9, -71), Vector2(15, -64), Vector2(17, -53), Vector2(14, -45)])
	_poly(hood, Palette.CLOAK)
	_poly(PackedVector2Array([Vector2(-10, -48), Vector2(-11, -57), Vector2(-6, -65), Vector2(5, -65), Vector2(10, -57), Vector2(10, -49), Vector2(0, -45)]), Color("0a0a10"), 2.0)
	var glint := 0.7 + 0.3 * sin(_t * 1.7)
	draw_circle(Vector2(-4 + _look * 1.2, -55), 1.9, Color(Palette.CYAN, glint))
	draw_circle(Vector2(4 + _look * 1.2, -55), 1.9, Color(Palette.CYAN, glint))
	draw_polyline(PackedVector2Array([Vector2(-13, -50), Vector2(-14, -60), Vector2(-9, -68)]), Color(1, 1, 1, 0.16), 2.6)

func _draw_back(ph: float, moving: bool, flick: float) -> void:
	var wave := sin(_t * 3.2) * 1.5 + (sin(ph * 2.0) * 1.5 if moving else 0.0)
	_legs(ph, moving)
	# Lantern arm swings off to the side, seen from behind.
	var hand := Vector2(16, -28 + (sin(ph) * 2.0 if moving else 0.0))
	_poly(PackedVector2Array([Vector2(9, -42), Vector2(14, -41), hand + Vector2(3, 0), hand + Vector2(-3, 1)]), Palette.TUNIC.darkened(0.15), 2.6)
	_lantern(hand + Vector2(0, 5), flick)
	# Cloak covers the back; backpack and scroll sit on top of it.
	_poly(PackedVector2Array([Vector2(-12, -44), Vector2(12, -44), Vector2(16 + wave, -9), Vector2(8, -4 + wave * 0.4), Vector2(0, -8), Vector2(-8, -3), Vector2(-16 - wave, -9)]), Palette.CLOAK_DARK)
	_poly(PackedVector2Array([Vector2(-10, -46), Vector2(10, -46), Vector2(11, -20), Vector2(-11, -20)]), Color("7a5232"))
	draw_line(Vector2(-10, -34), Vector2(10, -34), Palette.OUTLINE, 2.0)
	_poly(PackedVector2Array([Vector2(-6, -34), Vector2(6, -34), Vector2(6, -26), Vector2(-6, -26)]), Color("6a4528"), 2.2)
	_poly(PackedVector2Array([Vector2(-12, -51), Vector2(12, -51), Vector2(12, -44), Vector2(-12, -44)]), Color("d8c28f"), 2.2)
	draw_arc(Vector2(-12, -47.5), 3.4, 0.0, TAU * 0.85, 10, Palette.OUTLINE, 1.6)
	var hood := PackedVector2Array([Vector2(-14, -45), Vector2(-17, -56), Vector2(-12, -68), Vector2(-3, -74), Vector2(4, -76), Vector2(9, -71), Vector2(15, -64), Vector2(17, -53), Vector2(14, -45)])
	_poly(hood, Palette.CLOAK)
	draw_polyline(PackedVector2Array([Vector2(0, -46), Vector2(1, -58), Vector2(3, -70)]), Color(0, 0, 0, 0.25), 2.0)

func _draw_crumpled(inkc: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		pts.append(Vector2.from_angle(a) * rng.randf_range(9.0, 16.0))
	draw_colored_polygon(pts, Color(0.88, 0.82, 0.68))
	pts.append(pts[0])
	draw_polyline(pts, Palette.OUTLINE, 3.0, true)
	for i in 4:
		draw_line(Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
			Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)), Color(inkc, 0.6), 1.2)
	# The lantern still glows beside the crumpled page.
	draw_circle(Vector2(14, 0), 4.0, Color(Palette.CYAN, 0.9))
