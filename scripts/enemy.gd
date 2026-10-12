class_name Enemy
extends CharacterBody2D
## The Redaction's "Errors".
##  BARE: a Typo-Ghoul, a bear missing its fur (and an "a"). Slow, heavy lunger.
##        Cut it down, or shine your Lantern on it until it is *proofread* back into a Bear.
##  MITE: a scribble of noise. Fast and fragile; light burns it away.

signal died(enemy: Enemy)
signal proofread(enemy: Enemy)

enum Kind { BARE, MITE }

var kind: Kind = Kind.BARE
var floor_ref: IsoFloor
var target: Player
var hp := 6.0
var max_hp := 6.0
var hit_r := 20.0
var friendly := false
var asleep_t := 0.0         # >0: dozing (rewritten to sleep); wakes when it reaches 0
var elev := 0.0

var _home := Vector2.ZERO
var _state := "idle"
var _st := 0.0
var _cd := 1.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _proof := 0.0
var _lit_now := false
var _t := 0.0
var _seed := 0.0
var _lunge := Vector2.ZERO
var _hit_done := false
var _face := 1.0
var _splats: Array[Dictionary] = []
var _dead_t := -1.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _col: CollisionPolygon2D

# --- Perception (stealth) ---
var vision_range := 270.0          # ground px
var half_cone := 0.95              # radians either side of facing (~54 deg)
var hearing_mult := 1.0
var _alert := 0.0                  # 0 unaware .. 1 has noticed you
var _facing := Vector2.RIGHT       # ground-plane direction it is looking
var _last_seen := Vector2.ZERO
var _lost_t := 0.0
var _look_t := 0.0
var _lured: Node2D                 # a remembered Storytender it is staring at
var _popup := 0.0

func _ready() -> void:
	_seed = position.x * 0.017 + position.y * 0.011
	_t = _seed * 7.0
	_home = position
	if kind == Kind.BARE:
		hp = 9.0
		hit_r = 22.0
	else:
		hp = 2.0
		hit_r = 12.0
	if kind == Kind.MITE:
		vision_range = 230.0
		half_cone = 1.35
		hearing_mult = 1.35
	_facing = Vector2.from_angle(randf() * TAU)
	max_hp = hp
	_col = CollisionPolygon2D.new()
	_col.polygon = Iso.diamond(Vector2.ZERO, 0.6 if kind == Kind.BARE else 0.35)
	add_child(_col)
	add_to_group("enemies")
	add_to_group("hittables")
	add_to_group("lightable")

# --- Interactions from the player ---------------------------------------------------------
func hurt(dmg: float, dir_ground: Vector2) -> void:
	if friendly or _dead_t >= 0.0:
		return
	# Sneak attack: hitting something that hasn't noticed you (or is asleep) does double.
	var unaware := (_state in ["idle", "return", "search"] and _alert < 0.6) or asleep_t > 0.0
	if unaware:
		dmg *= 2.0
		_popup = 1.0
	asleep_t = 0.0          # a hit wakes it
	_alert = 1.0
	_raise_alarm()
	hp -= dmg
	_flash = 0.18
	var force := 230.0 if kind == Kind.MITE else 170.0
	_knock = Vector2(dir_ground.x, dir_ground.y * 0.5) * force
	_state = "hurt"
	_st = 0.22
	for i in 5:
		_splats.append({"pos": Vector2.from_angle(randf() * TAU) * randf_range(6.0, 22.0) + Vector2(0, -22), "r": randf_range(1.6, 4.0), "age": 0.0})
	if hp <= 0.0:
		_die()

## The Lantern's beam: Bares are proofread (corrected); Mites are burned off the page.
func lit(delta: float) -> void:
	if friendly or _dead_t >= 0.0:
		return
	_lit_now = true
	if kind == Kind.BARE:
		_proof += delta / 2.2
		if _proof >= 1.0:
			_correct()
	else:
		hp -= 4.5 * delta
		if hp <= 0.0:
			_die()

func _die() -> void:
	_dead_t = 0.0
	remove_from_group("enemies")
	remove_from_group("hittables")
	remove_from_group("lightable")
	_col.set_deferred("disabled", true)
	died.emit(self)

func _correct() -> void:
	friendly = true
	remove_from_group("enemies")
	remove_from_group("hittables")
	remove_from_group("lightable")
	_state = "idle"
	proofread.emit(self)

# --- Behaviour ------------------------------------------------------------------------------
func _ground_to(p: Vector2) -> Vector2:
	var d := p - position
	return Vector2(d.x, d.y * 2.0)

func _move(dir_ground: Vector2, spd: float) -> void:
	velocity = Vector2(dir_ground.x, dir_ground.y * 0.5) * spd

func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s): return s.age < 1.0)
	if _dead_t >= 0.0:
		_dead_t += delta
		velocity = Vector2.ZERO
		modulate.a = clampf(1.0 - _dead_t / 0.7, 0.0, 1.0)
		if _dead_t > 0.7:
			queue_free()
		queue_redraw()
		return
	if not _lit_now and not friendly:
		_proof = maxf(_proof - delta * 0.45, 0.0)
	asleep_t = maxf(asleep_t - delta, 0.0)
	var lit_slow := 0.5 if _lit_now else 1.0
	_lit_now = false
	if floor_ref:
		elev = lerpf(elev, floor_ref.height_at(position) * Iso.LEVEL_H, 1.0 - exp(-14.0 * delta))
	_cd = maxf(_cd - delta, 0.0)
	_popup = maxf(_popup - delta, 0.0)
	_st -= delta
	velocity = Vector2.ZERO

	if friendly:
		_friendly_tick(delta)
	else:
		_hostile_tick(delta, lit_slow)

	# Never walk into a plot hole or off the page.
	if floor_ref and velocity != Vector2.ZERO:
		var c := floor_ref.cell_at(position + velocity * delta * 4.0)
		if floor_ref.is_pit(c) or not floor_ref.has_cell(c):
			velocity = Vector2.ZERO
	if absf(velocity.x) > 6.0:
		_face = signf(velocity.x)
	move_and_slide()
	queue_redraw()

func _can_see_target() -> bool:
	if target == null or target.is_crumpled or target.is_falling:
		return false
	if floor_ref and absf(floor_ref.height_at(target.position) - floor_ref.height_at(position)) > 0.6:
		return false
	return true

func sleep_for(seconds: float) -> void:
	asleep_t = seconds
	_state = "idle"

## How strongly you are being sensed this frame (0 = not at all). Hearing falls
## off with distance; sight needs the right direction, range and a clear line.
func _perceive(delta: float) -> bool:
	var rate := 0.0
	if _can_see_target():
		var dg := _ground_to(target.position)
		var dist := dg.length()
		var noise: float = target.noise_radius() * hearing_mult
		if dist < noise:
			rate += (1.0 - dist / noise) * 1.6
		var sight := vision_range * (1.25 if target.lantern_on else 1.0) * (0.75 if target.is_sneaking else 1.0)
		if dist < sight:
			var inside := dist < 90.0 or absf(_facing.angle_to(dg)) < half_cone
			if inside and floor_ref and floor_ref.has_los(position, target.position):
				rate += 0.45 + (1.0 - dist / sight) * 1.5
	if rate > 0.0:
		_alert = minf(_alert + rate * delta, 1.0)
	elif _state in ["idle", "return"]:
		_alert = maxf(_alert - 0.35 * delta, 0.0)
	return rate > 0.0

## A remembered Storytender standing nearby draws the curious to it.
func _check_echo_lure() -> void:
	for e: Node2D in get_tree().get_nodes_in_group("echoes"):
		if e.get("lures") == true and _ground_to(e.position).length() < 420.0 \
				and (floor_ref == null or floor_ref.has_los(position, e.position)):
			_last_seen = e.position
			_lured = e
			_state = "search"
			_look_t = 3.0
			return

## Wake the neighbours: when one Error notices you, the ones beside it do too.
func _raise_alarm() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and not e.friendly and _ground_to(e.position).length() < 170.0:
			e._alert = maxf(e._alert, 1.0)

func _enter_chase() -> void:
	_state = "chase"
	_alert = 1.0
	_lost_t = 0.0
	_last_seen = target.position
	_raise_alarm()

func _hostile_tick(delta: float, slow: float) -> void:
	if asleep_t > 0.0 and _state != "hurt":
		return
	var sensed := _perceive(delta)
	if _state in ["idle", "return"] and _alert < 1.0:
		_check_echo_lure()
	var dg := _ground_to(target.position) if target else Vector2(9999, 0)
	var dist := dg.length()
	var dirg := dg.normalized() if dist > 0.01 else Vector2.RIGHT
	if velocity.length() > 3.0:
		_facing = _facing.lerp(Vector2(velocity.x, velocity.y * 2.0).normalized(), 1.0 - exp(-6.0 * delta)).normalized()
	match _state:
		"idle":
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(1.0, 2.5)
				_wander = Vector2.from_angle(randf() * TAU) if randf() > 0.4 else Vector2.ZERO
				if _ground_to(_home).length() > 110.0:
					_wander = _ground_to(_home).normalized()   # guards drift, but not far from their post
			_move(_wander, 28.0)
			if _wander == Vector2.ZERO:
				# Standing still, it slowly scans left and right.
				_facing = _facing.rotated(sin(_t * 0.8 + _seed) * 0.6 * delta)
			if _alert >= 1.0 and _can_see_target():
				_enter_chase()
		"chase":
			if sensed:
				_lost_t = 0.0
				_last_seen = target.position
			else:
				_lost_t += delta
				if _lost_t > 2.5:
					_state = "search"
					_look_t = 3.0
					return
			if kind == Kind.BARE:
				_move(dirg, 86.0 * slow)
				if dist < 80.0 and _cd <= 0.0 and slow == 1.0:
					_state = "windup"
					_st = 0.45
					_lunge = dirg
			else:
				var jitter := dirg.orthogonal() * sin(_t * 9.0 + _seed) * 0.6
				_move((dirg + jitter).normalized(), 150.0 * slow)
				if dist < 28.0 and _cd <= 0.0:
					target.take_damage(6.0 * GameState.enemy_dmg_mult(), true, "mite")
					target.knockback(dirg, 150.0)
					_cd = 0.9
		"search":
			# It lost you. It walks to where it last saw you, then looks around.
			var to_last := _ground_to(_last_seen)
			if to_last.length() > 30.0:
				_move(to_last.normalized(), 70.0)
			else:
				if is_instance_valid(_lured) and _lured.get("lures") == true:
					# Transfixed: it stares at the echo instead of scanning the room.
					_look_t = 3.0
				else:
					_look_t -= delta
					_facing = _facing.rotated(2.2 * delta)
				if _look_t <= 0.0:
					_alert = 0.3
					_state = "return"
			if _alert >= 1.0 and sensed:
				_enter_chase()
		"windup":
			# Telegraph: the Bare rears back before lunging.
			_move(-_lunge, 14.0)
			if _st <= 0.0:
				_state = "lunge"
				_st = 0.38
				_hit_done = false
		"lunge":
			_move(_lunge, 340.0)
			if not _hit_done and target and dist < 40.0:
				_hit_done = true
				target.take_damage(12.0 * GameState.enemy_dmg_mult(), true, "bare")
				target.knockback(_lunge, 280.0)
			if _st <= 0.0:
				_state = "recover"
				_st = 0.7
				_cd = 1.2
		"recover":
			if _st <= 0.0:
				_state = "chase"
		"hurt":
			velocity = _knock
			_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
			if _st <= 0.0:
				_state = "chase"
				_lost_t = 0.0
				_last_seen = target.position
		"return":
			var back := _ground_to(_home)
			if back.length() < 14.0:
				_state = "idle"
			else:
				_move(back.normalized(), 60.0)
			if _alert >= 1.0 and sensed:
				_enter_chase()

func _friendly_tick(delta: float) -> void:
	# A corrected Bear: wanders, and ambles after you at a polite distance.
	var dg := _ground_to(target.position) if target else Vector2(9999, 0)
	var dist := dg.length()
	if _can_see_target() and dist > 120.0 and dist < 420.0:
		_move(dg.normalized(), 52.0)
		return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander = Vector2.from_angle(randf() * TAU) if randf() > 0.5 else Vector2.ZERO
	_move(_wander, 22.0)

func _draw_cone() -> void:
	# The area it can see: yellow while calm, orange then red as it notices you.
	var col := Color(1.0, 0.9, 0.3, 0.14).lerp(Color(1.0, 0.25, 0.2, 0.30), clampf(_alert, 0.0, 1.0))
	if _state == "chase" or _state == "windup" or _state == "lunge":
		col = Color(1.0, 0.2, 0.15, 0.22)
	var base := _facing.angle()
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var a := base - half_cone + 2.0 * half_cone * i / 12.0
		var g := Vector2.from_angle(a) * vision_range
		pts.append(Vector2(g.x, g.y * 0.5))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	draw_colored_polygon(pts, col)

# --- Drawing --------------------------------------------------------------------------------
func _draw() -> void:
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	var pool := 20.0 if kind == Kind.BARE else 11.0
	draw_circle(Vector2.ZERO, pool, Color(0, 0, 0, 0.25))
	if _dead_t >= 0.0:
		draw_circle(Vector2.ZERO, pool + _dead_t * 22.0, Color(Palette.INK, 0.55 * (1.0 - _dead_t / 0.7)))
	if not friendly and _dead_t < 0.0 and asleep_t <= 0.0 and target != null and _ground_to(target.position).length() < 460.0:
		_draw_cone()
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if kind == Kind.BARE:
		_draw_bare()
	else:
		_draw_mite()
	if asleep_t > 0.0 and _dead_t < 0.0:
		var font := ThemeDB.get_default_theme().default_font
		for i in 3:
			var ph := fmod(_t * 0.7 + i * 0.33, 1.0)
			draw_string(font, Vector2(14 + i * 7, -62 - ph * 26.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14 + i * 4, Color(1, 1, 1, 1.0 - ph))
	# Ink spatter from hits.
	for s in _splats:
		draw_circle(s.pos, s.r * (1.0 - float(s.age)), Color(Palette.INK, 0.9 * (1.0 - float(s.age))))
	# Alert indicators: "?" while it is noticing you, "!" once it has.
	if not friendly and _dead_t < 0.0:
		var font2 := ThemeDB.get_default_theme().default_font
		var top := -96.0 if kind == Kind.BARE else -52.0
		if _state == "search":
			draw_string_outline(font2, Vector2(-5, top), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, 6, Color(Palette.OUTLINE, 0.9))
			draw_string(font2, Vector2(-5, top), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color("c9c9d6"))
		elif _state == "idle" and _alert > 0.25:
			var q := clampf(_alert, 0.0, 1.0)
			draw_string_outline(font2, Vector2(-5, top), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(18 + 12 * q), 6, Color(Palette.OUTLINE, 0.9))
			draw_string(font2, Vector2(-5, top), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(18 + 12 * q), Color(1.0, 0.8 - 0.4 * q, 0.2))
		if _popup > 0.0:
			draw_string_outline(font2, Vector2(-34, top - 14 - (1.0 - _popup) * 14.0), "Sneak attack!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, 6, Color(Palette.OUTLINE, _popup))
			draw_string(font2, Vector2(-34, top - 14 - (1.0 - _popup) * 14.0), "Sneak attack!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(Palette.GOLD, _popup))
	if not friendly and _dead_t < 0.0 and hp < max_hp:
		var w := 34.0
		draw_rect(Rect2(-w * 0.5, -78, w, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, -78, w * hp / max_hp, 5), Palette.CRITIC_RED.lightened(0.1))

func _poly(pts: PackedVector2Array, fill: Color, w: float = 2.6) -> void:
	var f := fill.lerp(Color.WHITE, _flash * 4.0)
	draw_colored_polygon(pts, f)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Palette.OUTLINE, w, true)

func _draw_bare() -> void:
	var skin := Color("c9a89d")
	var fur := Color("8b6340")
	var c := skin.lerp(fur, _proof) if not friendly else fur
	var belly := Color("d8b5aa").lerp(Color("c8a574"), _proof if not friendly else 1.0)
	var rear := 0.0
	var tele := _state == "windup"
	if tele:
		rear = -4.0
	var bob := sin(_t * (3.0 if _state == "chase" else 1.6)) * 1.5
	draw_set_transform(Vector2(0, -elev + bob), 0.0, Vector2(_face, 1.0))
	# Legs.
	_poly(PackedVector2Array([Vector2(-16, 0), Vector2(-6, 0), Vector2(-6, -14), Vector2(-17, -14)]), c.darkened(0.12))
	_poly(PackedVector2Array([Vector2(8, 0), Vector2(19, 0), Vector2(18, -14), Vector2(8, -14)]), c.darkened(0.12))
	# Hunched body.
	_poly(DrawKit.ellipse(Vector2(-2 + rear, -30), 25.0, 21.0, 20, 0.07, _seed), c)
	_poly(DrawKit.ellipse(Vector2(2 + rear, -26), 14.0, 14.0, 16, 0.05, _seed + 2.0), belly, 2.0)
	# Wrinkles (bare skin) or fur tufts (proofread).
	var wr := 1.0 - (1.0 if friendly else _proof)
	for i in 5:
		var y := -38.0 + i * 5.0
		draw_line(Vector2(-18 + rear, y), Vector2(-9 + rear, y + 2), Color(0.45, 0.25, 0.25, 0.5 * wr), 1.6)
	var tuft := _proof if not friendly else 1.0
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector2(-2 + rear, -30) + Vector2(cos(a) * 25.0, sin(a) * 21.0)
		draw_line(p, p + Vector2(cos(a), sin(a)) * 6.0 * tuft, c.darkened(0.25), 2.2)
	# Head.
	var hc := Vector2(17 + rear * 0.4, -44)
	_poly(DrawKit.ellipse(hc, 13.0, 12.0, 16, 0.04, _seed + 4.0), c)
	_poly(DrawKit.ellipse(hc + Vector2(9, 4), 8.0, 6.0, 12), belly, 2.0)
	draw_circle(hc + Vector2(14, 2), 2.4, Palette.OUTLINE)
	_poly(DrawKit.ellipse(hc + Vector2(-6, -11), 4.5, 4.5, 10), c.darkened(0.08), 2.0)
	_poly(DrawKit.ellipse(hc + Vector2(5, -11), 4.5, 4.5, 10), c.darkened(0.08), 2.0)
	# Eyes: dull holes while broken, warm lights once proofread.
	var eye := Color(0.1, 0.05, 0.08).lerp(Palette.CYAN, tuft)
	draw_circle(hc + Vector2(1, -2), 2.2, eye)
	draw_circle(hc + Vector2(8, -2), 2.2, eye)
	# Arms with claws.
	var ar := hc + Vector2(-4, 10)
	_poly(PackedVector2Array([Vector2(8 + rear, -36), Vector2(16 + rear, -34), ar + Vector2(14, 14), ar + Vector2(6, 16)]), c.darkened(0.1), 2.2)
	if tele or _state == "lunge":
		for k in 3:
			draw_line(ar + Vector2(14, 14), ar + Vector2(20 + k * 3, 22 + k * 2), Color("efe3c4"), 2.0)
	if tele:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(8, -78), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color("ff6a5c"))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	# Proofreader's marks: the misspelling, and the correction fading in as light lands.
	var font := ThemeDB.get_default_theme().default_font
	var word := "Bear" if friendly else "Bare"
	var col := Palette.CYAN if friendly else Color("ff6a5c")
	draw_string_outline(font, Vector2(-17, -86), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 5, Color(Palette.OUTLINE, 0.8))
	draw_string(font, Vector2(-17, -86), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, col)
	if not friendly and _proof > 0.05:
		draw_string_outline(font, Vector2(-17, -102), "Bear", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 5, Color(Palette.OUTLINE, 0.8 * _proof))
		draw_string(font, Vector2(-17, -102), "Bear", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(Palette.CYAN, _proof))
		draw_line(Vector2(-19, -92), Vector2(18, -92), Color("ff6a5c", _proof), 2.0)

func _draw_mite() -> void:
	var hop := absf(sin(_t * 9.0 + _seed)) * 6.0
	var c := Vector2(0, -14 - hop)
	var boil := int(_t * 12.0)
	# Pale halo, as in the enemy sheet, then the black scribble.
	draw_circle(c, 15.0, Color(1, 1, 1, 0.85))
	draw_circle(c, 12.5, Color(Palette.GLITCH, 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = boil * 131 + int(_seed * 100.0)
	for i in 7:
		var pts := PackedVector2Array()
		var a0 := rng.randf() * TAU
		for k in 6:
			var a := a0 + k * 1.3
			var r := rng.randf_range(3.0, 11.5)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(0.05, 0.03, 0.09).lerp(Color.WHITE, _flash * 4.0), 2.2, true)
	for i in 6:
		var a := TAU * i / 6.0 + _t * 3.0
		var base := c + Vector2(cos(a), sin(a)) * 12.0
		draw_line(base, base + Vector2(cos(a + 0.4), sin(a + 0.4)) * 7.0, Color.WHITE, 2.0)
	draw_circle(c + Vector2(-3, -1), 1.8, Color.WHITE)
	draw_circle(c + Vector2(3, -1), 1.8, Color.WHITE)
