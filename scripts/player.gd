class_name Player
extends CharacterBody2D
## The Storytender: a sentient doodle. 8-directional movement, "ink" health.
## Damage bleeds ink instead of blood; at zero ink the sketch crumples.

signal ink_changed(current: float, maximum: float)
signal lantern_changed(energy: float, maximum: float)
signal crumpled
signal fell
signal attacked
signal dashed
signal hit_landed
signal style_changed(style: String)

const LANTERN_MAX := 100.0
const LANTERN_DRAIN := 24.0       # per second while shining
const LANTERN_REGEN := 14.0       # per second after a short delay
const BEAM_RANGE := 175.0
const BEAM_HALF := 0.63           # radians (~36 deg)
const REACH := 74.0
const ARC_HALF := 1.2             # radians (~68 deg)

@export var speed := 190.0
@export var accel := 1400.0
@export var friction := 1800.0
@export var max_ink := 100.0

var ink := 100.0
var _regen_emit := 0.0
var is_crumpled := false
var is_falling := false
var floor_ref: IsoFloor
var lantern_energy := LANTERN_MAX
var lantern_on := false
var aim := Vector2.RIGHT            # screen-space direction toward the cursor (or facing)
var aim_ground := Vector2.RIGHT     # same direction in ground metric (y doubled)
var _t := 0.0
var _splats: Array[Dictionary] = []  # {pos, radius, age}
var _look := 0.0
var lantern_power := 1.0   # glow strength; brighter inside memories
var speed_mult := 1.0      # debuffs (The Critic's words) slow the Storytender
var _walk := 0.0
var _invuln := 0.0
var _facing_right := true
var _facing_back := false
var is_sneaking := false   # holding Ctrl/C: slower, much quieter
var elev := 0.0            # visual elevation in px; physics stays on the ground plane
var preview := false       # true when drawn inside the binder's paper-doll panel
var _last_dir := Vector2.RIGHT
var _mouse_idle := 99.0
var _lantern_delay := 0.0
var _atk_cd := 0.0
var _swing := 0.0
var _swing_dir := Vector2.RIGHT
var _swing_combo := 1
var _combo := 0
var _combo_t := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO
var _stun := 0.0
var _trail: Array[Dictionary] = []   # dash afterimages {pos, age}

func _ready() -> void:
	ink = max_ink
	ink_changed.emit(ink, max_ink)
	lantern_changed.emit(lantern_energy, LANTERN_MAX)

## How far your presence carries (hearing), in ground pixels. Creeping is quiet;
## dashing and fighting are loud; the Lantern announces you.
func noise_radius() -> float:
	var r := 45.0 + clampf(velocity.length() / speed, 0.0, 1.0) * 105.0
	if _dash_t > 0.0:
		r = 290.0
	if _swing > 0.0:
		r = maxf(r, 300.0)
	if lantern_on:
		r += 50.0
	if is_sneaking:
		r *= 0.4
	return r

func can_attack() -> bool:
	return GameState.has_flag("has_quill") or GameState.has_flag("has_sword")   # Garrick's First Sword counts until the Quill is forged

func _input(event: InputEvent) -> void:
	if not preview and GameState.has_flag("format_mark") and not GameState.in_dialogue:
		var st := ""
		if event.is_action_pressed("style_underline"):
			st = "underline"
		elif event.is_action_pressed("style_bold"):
			st = "bold"
		elif event.is_action_pressed("style_italic"):
			st = "italic"
		if st != "":
			GameState.format_style = st
			style_changed.emit(st)
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_idle = 0.0

func _physics_process(delta: float) -> void:
	if preview:
		return
	var regen := GameState.equipped_stat("regen")
	if regen > 0.0 and ink < max_ink and not is_crumpled:
		ink = minf(ink + regen * delta, max_ink)
		_regen_emit -= delta
		if _regen_emit <= 0.0:
			_regen_emit = 0.25
			ink_changed.emit(ink, max_ink)
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_combo_t -= delta
	_stun = maxf(_stun - delta, 0.0)
	_update_aim()
	var locked := is_crumpled or is_falling or GameState.in_dialogue
	if locked:
		_set_lantern(false, delta)
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_last_dir = dir.normalized()
	_set_lantern(Input.is_action_pressed("lantern") and lantern_energy > 0.0, delta)

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * 520.0
		_trail.append({"pos": position, "age": 0.0})
	elif _stun > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * 0.6 * delta)
	else:
		# WASD are screen directions. The 2:1 isometric plane is squashed
		# vertically, so halve the vertical speed to keep motion visually even.
		is_sneaking = Input.is_action_pressed("sneak")
		var mult := speed_mult * (1.0 + GameState.equipped_stat("speed")) * (0.72 if lantern_on else 1.0) * (0.55 if is_sneaking else 1.0)
		var target := Vector2(dir.x, dir.y * 0.5) * speed * mult
		if dir != Vector2.ZERO:
			velocity = velocity.move_toward(target, accel * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
			_dash(dir)
		elif can_attack() and Input.is_action_just_pressed("attack") and _atk_cd <= 0.0:
			_strike()
	move_and_slide()

	if Input.is_action_just_pressed("debug_damage"):
		take_damage(12.0, true, "debug")
	if Input.is_action_just_pressed("debug_heal"):
		restore_ink(100.0)

func _update_aim() -> void:
	var body := global_position + Vector2(0, -elev - 20.0)
	var d := get_global_mouse_position() - body
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.35:
		aim = stick.normalized()    # right stick aims
		_mouse_idle = 99.0
	elif _mouse_idle < 3.0 and d.length() > 4.0:
		aim = d.normalized()
	else:
		aim = _last_dir
	aim_ground = Vector2(aim.x, aim.y * 2.0).normalized()

func _ground(n: Node2D) -> Vector2:
	var d := n.position - position
	return Vector2(d.x, d.y * 2.0)

func _same_floor(n: Node2D) -> bool:
	return floor_ref == null or absf(floor_ref.height_at(n.position) - floor_ref.height_at(position)) < 0.7

# --- The Quill ---------------------------------------------------------------------------
func _strike() -> void:
	_combo = _combo + 1 if _combo_t > 0.0 else 1
	if _combo > 3:
		_combo = 1
	_combo_t = 0.75
	var finisher := _combo == 3
	var dmg := (3.5 if finisher else 2.0) * (1.0 + GameState.equipped_stat("dmg"))
	var reach := (REACH + (16.0 if finisher else 0.0)) * (1.0 + GameState.equipped_stat("reach"))
	_atk_cd = 0.5 if finisher else 0.3
	_swing = 1.0
	_swing_dir = aim_ground
	_swing_combo = _combo
	if absf(aim.x) > 0.15:
		_facing_right = aim.x > 0.0
	_facing_back = aim.y < -0.4
	velocity += Vector2(aim_ground.x, aim_ground.y * 0.5) * (170.0 if finisher else 120.0)
	attacked.emit()
	var hit_any := false
	for e in get_tree().get_nodes_in_group("hittables"):
		if not is_instance_valid(e):
			continue
		var dg := _ground(e)
		var rad: float = e.get("hit_r") if e.get("hit_r") != null else 16.0
		if dg.length() > reach + rad:
			continue
		if dg.length() > 22.0 and absf(aim_ground.angle_to(dg)) > ARC_HALF:
			continue
		if not _same_floor(e):
			continue
		e.hurt(dmg, dg.normalized())
		hit_any = true
	if hit_any:
		hit_landed.emit()

func _dash(dir: Vector2) -> void:
	var d := dir if dir != Vector2.ZERO else _last_dir
	_dash_dir = Vector2(d.x, d.y * 0.5).normalized()
	_dash_t = 0.2
	_dash_cd = 0.75 * (1.0 + GameState.equipped_stat("dash_cd"))
	_invuln = maxf(_invuln, 0.32)
	dashed.emit()

func knockback(dir_ground: Vector2, force: float) -> void:
	velocity = Vector2(dir_ground.x, dir_ground.y * 0.5) * force
	_stun = 0.18
	_dash_t = 0.0

# --- The Lantern ------------------------------------------------------------------------------
func _set_lantern(want: bool, delta: float) -> void:
	lantern_on = want
	if want:
		lantern_energy = maxf(lantern_energy - LANTERN_DRAIN * delta * maxf(0.1, 1.0 + GameState.equipped_stat("lantern_eff")), 0.0)
		_lantern_delay = 0.9
		for n in get_tree().get_nodes_in_group("lightable"):
			if not is_instance_valid(n):
				continue
			var dg := _ground(n)
			var rad: float = n.get("hit_r") if n.get("hit_r") != null else 16.0
			if dg.length() > BEAM_RANGE + rad:
				continue
			var slack := atan2(rad, maxf(dg.length(), 1.0))
			if dg.length() > 20.0 and absf(aim_ground.angle_to(dg)) > BEAM_HALF + slack:
				continue
			if not _same_floor(n):
				continue
			n.lit(delta)
		lantern_changed.emit(lantern_energy, LANTERN_MAX)
	else:
		_lantern_delay -= delta
		if _lantern_delay <= 0.0 and lantern_energy < LANTERN_MAX:
			lantern_energy = minf(lantern_energy + LANTERN_REGEN * delta, LANTERN_MAX)
			lantern_changed.emit(lantern_energy, LANTERN_MAX)

func refuel(amount: float) -> void:
	lantern_energy = minf(lantern_energy + amount, LANTERN_MAX)
	lantern_changed.emit(lantern_energy, LANTERN_MAX)

func _process(delta: float) -> void:
	_t += delta
	_mouse_idle += delta
	_invuln = maxf(_invuln - delta, 0.0)
	_swing = maxf(_swing - delta / 0.26, 0.0)
	for tr in _trail:
		tr.age += delta
	_trail = _trail.filter(func(tr): return tr.age < 0.3)
	if velocity.length() > 20.0 and _swing <= 0.0:
		_walk += velocity.length() * delta * 0.075
		if absf(velocity.x) > 12.0:
			_facing_right = velocity.x > 0.0
		if velocity.y < -6.0:
			_facing_back = true
		elif velocity.y > 6.0:
			_facing_back = false
	elif lantern_on and not GameState.in_dialogue:
		# While shining the light, face where the light points.
		if absf(aim.x) > 0.2:
			_facing_right = aim.x > 0.0
		_facing_back = aim.y < -0.5
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s): return s.age < 6.0)
	if absf(velocity.x) > 8.0:
		_look = lerpf(_look, signf(velocity.x), 1.0 - exp(-10.0 * delta))
	queue_redraw()

func take_damage(amount: float, lethal: bool = true, source: String = "") -> void:
	if is_crumpled or (_invuln > 0.0 and lethal):
		return
	if lethal:
		amount *= 1.0 - clampf(GameState.equipped_stat("armor"), 0.0, 0.75)
		_invuln = 0.9 + GameState.equipped_stat("invuln")
	ink = maxf(ink - amount, 0.0 if lethal else 1.0)
	Telemetry.log_event("damage", {"src": source if source != "" else ("fall" if not lethal else "other"), "amt": snappedf(amount, 0.1), "ink": snappedf(ink, 0.1)})
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
	_invuln = maxf(_invuln, 2.0)   # a moment to get your bearings
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
	if not preview:
		for k in 5:
			draw_circle(Vector2(0, 0), 92.0 - k * 15.0, Color(Palette.CYAN, (0.022 + 0.006 * k) * flick * lantern_power))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	_draw_trail()
	if is_sneaking and not preview:
		# While creeping, a faint ring shows how far your presence carries.
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, noise_radius(), 0.0, TAU, 40, Color(1, 1, 1, 0.22), 2.0, true)
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if lantern_on:
		_draw_beam(flick)
	if _swing > 0.0:
		_draw_slash()
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	if is_crumpled:
		draw_set_transform(Vector2(0, -8 - elev), 0.0, Vector2.ONE)
		_draw_crumpled(inkc)
		return

	var moving := velocity.length() > 20.0
	var ph := _walk
	var bob := -absf(sin(ph)) * 2.6 if moving else sin(_t * 1.8) * 0.7
	var fx := 1.0 if _facing_right else -1.0
	draw_set_transform(Vector2(0, bob - elev + (4.0 if is_sneaking else 0.0)), 0.0, Vector2(fx * 0.8, 0.8 * (0.9 if is_sneaking else 1.0)))
	if _invuln > 0.0 and int(_t * 20.0) % 2 == 0:
		return   # blink while briefly invulnerable
	if _facing_back:
		_draw_back(ph, moving, flick)
	else:
		_draw_front(ph, moving, flick)

# Ground-plane helpers: points are given in ground metric (y doubled) and drawn squashed.
func _g2s(g: Vector2) -> Vector2:
	return Vector2(g.x, g.y * 0.5)

func _draw_trail() -> void:
	for tr in _trail:
		var d: Vector2 = Vector2(tr.pos) - position
		var a: float = (1.0 - float(tr.age) / 0.3) * 0.35
		draw_colored_polygon(DrawKit.ellipse(d + Vector2(0, -22), 11.0, 22.0, 14), Color(Palette.CYAN, a))

func _draw_beam(flick: float) -> void:
	var base := aim_ground.angle()
	for k in 3:
		var r := BEAM_RANGE * (1.0 - k * 0.26)
		var pts := PackedVector2Array([_g2s(Vector2.from_angle(base) * 6.0) + Vector2(0, -8)])
		for i in 13:
			var a := base - BEAM_HALF + (2.0 * BEAM_HALF) * i / 12.0
			pts.append(_g2s(Vector2.from_angle(a) * r) + Vector2(0, -8))
		draw_colored_polygon(pts, Color(Palette.CYAN, (0.13 + k * 0.08) * flick))
	# Crisp edges and a bright core so the cone reads clearly.
	for sgn in [-1.0, 1.0]:
		var e := _g2s(Vector2.from_angle(base + sgn * BEAM_HALF) * BEAM_RANGE) + Vector2(0, -8)
		draw_line(Vector2(0, -8), e, Color(Palette.CYAN.lightened(0.3), 0.55 * flick), 2.0, true)
	draw_arc(Vector2(0, -8), BEAM_RANGE * 0.5, 0.0, 0.0, 2, Color(0, 0, 0, 0))  # no-op keeps transform state simple
	draw_line(Vector2(0, -8), _g2s(aim_ground * BEAM_RANGE * 0.9) + Vector2(0, -8), Color(1, 1, 1, 0.30 * flick), 3.0)

func _draw_slash() -> void:
	var p := 1.0 - _swing
	var sgn := 1.0 if _swing_combo % 2 == 1 else -1.0
	var base := _swing_dir.angle()
	var big := _swing_combo == 3
	var rad := 60.0 + (20.0 if big else 0.0)
	var pts := PackedVector2Array()
	var pts_in := PackedVector2Array()
	var steps := 16
	var head := clampf(p * 2.4, 0.0, 1.0)
	for i in steps:
		var t := float(i) / (steps - 1)
		if t > head:
			break
		var ang := base + sgn * lerpf(-ARC_HALF, ARC_HALF, t)
		# The trailing end tapers so it reads as a brush-stroke.
		var thick := lerpf(4.0, 26.0 if big else 20.0, t)
		pts.append(_g2s(Vector2.from_angle(ang) * rad) + Vector2(0, -24))
		pts_in.append(_g2s(Vector2.from_angle(ang) * (rad - thick)) + Vector2(0, -24))
	if pts.size() >= 3:
		var fade := clampf(_swing * 2.0, 0.0, 1.0)
		var poly := pts.duplicate()
		for i in range(pts_in.size() - 1, -1, -1):
			poly.append(pts_in[i])
		draw_colored_polygon(poly, Color(Palette.INK, 0.92 * fade))
		draw_polyline(pts, Color(Palette.CYAN.lightened(0.4) if big else Color.WHITE, fade), 4.0 if big else 3.0, true)
		# Flicked ink droplets off the leading edge.
		var tip: Vector2 = pts[pts.size() - 1]
		for k in 3:
			draw_circle(tip + Vector2(randf_range(-6, 6), randf_range(-4, 4)), randf_range(1.2, 2.6), Color(Palette.INK, 0.9 * fade))

func _poly(pts: PackedVector2Array, fill: Color, w: float = 2.4) -> void:
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Palette.OUTLINE, w, true)

func _quill(at: Vector2, ang: float) -> void:
	# A long feather with an inked nib; held in the free hand once Garrick forges it.
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var tip := at + d * 22.0
	draw_line(at, tip, Palette.OUTLINE, 3.2)
	draw_line(at, tip, Color("efe3c4"), 1.6)
	var vane := PackedVector2Array([at + d * 8.0 + n * 1.0, at + d * 18.0 + n * 6.0, tip + n * 1.0, tip - n * 1.0, at + d * 17.0 - n * 5.0, at + d * 7.0 - n * 1.0])
	_poly(vane, Color("f4ecd6"), 1.6)
	draw_circle(at - d * 3.0, 1.8, Palette.CYAN)

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
	if Settings.gfx_on("glow"):
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
	if can_attack():
		_quill(Vector2(-11.5, -22), -2.3 - _swing * 0.9)
	var hand := Vector2(15 + sway * 0.5, -30 + (sin(ph) * 2.0 if moving else 0.0))
	_poly(PackedVector2Array([Vector2(8, -41), Vector2(13, -40), hand + Vector2(3, 0), hand + Vector2(-3, 1)]), Palette.TUNIC.darkened(0.05), 2.6)
	draw_circle(hand, 3.2, Color("c8a888"))
	_lantern(hand + Vector2(0, 5), flick)
	_draw_gear_front()
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

# --- Bindings (armor) and amulet, drawn from whatever is equipped --------------------------
func _draw_gear_front() -> void:
	var b: String = GameState.equipment["binding"]
	if b == "hardcover_binding":
		var cover := Color("6b4a3a")
		var gold := Color("c9a24e")
		_poly(PackedVector2Array([Vector2(-11, -42), Vector2(11, -42), Vector2(10, -27), Vector2(0, -23), Vector2(-10, -27)]), cover, 2.4)
		draw_polyline(PackedVector2Array([Vector2(-8, -39), Vector2(8, -39), Vector2(7, -29), Vector2(0, -26), Vector2(-7, -29), Vector2(-8, -39)]), gold, 1.4)
		draw_circle(Vector2(0, -33), 2.2, gold)
		_poly(PackedVector2Array([Vector2(-17, -46), Vector2(-8, -48), Vector2(-7, -38), Vector2(-17, -38)]), cover, 2.4)
		_poly(PackedVector2Array([Vector2(8, -48), Vector2(17, -46), Vector2(17, -38), Vector2(7, -38)]), cover, 2.4)
		draw_line(Vector2(-16, -44), Vector2(-9, -45), gold, 1.4)
		draw_line(Vector2(9, -45), Vector2(16, -44), gold, 1.4)
	elif b == "softcover_binding":
		var hide := Color("a77a52")
		_poly(PackedVector2Array([Vector2(-10, -43), Vector2(-3, -43), Vector2(0, -34), Vector2(3, -43), Vector2(10, -43), Vector2(11, -24), Vector2(-11, -24)]), hide, 2.4)
		for i in 5:
			draw_line(Vector2(0, -33 + i * 2.2), Vector2(0, -32 + i * 2.2), Color("efe3c4"), 1.4)
		draw_line(Vector2(-11, -28), Vector2(11, -28), Color(0, 0, 0, 0.3), 1.6)
	if GameState.equipment["amulet"] == "oxford_comma":
		draw_line(Vector2(-4, -43), Vector2(0, -35), Palette.OUTLINE, 1.6)
		draw_line(Vector2(4, -43), Vector2(0, -35), Palette.OUTLINE, 1.6)
		draw_circle(Vector2(0, -33), 3.4, Palette.GOLD)
		draw_arc(Vector2(0, -33), 3.4, 0.0, TAU, 10, Palette.OUTLINE, 1.4, true)

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
