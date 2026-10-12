class_name ColdShoulder
extends Node2D
## The Cold Shoulder: Maud's fear that nobody will come, as a hunched figure of frost. It always
## turns its shoulder to you, and the shoulder turns the Quill aside. Only a strike from behind
## lands, so you have to keep circling it. Holding the Lantern on it warms it and slows its turn.
## It slams the floor where you stand (a ring warns you first) and rests, open, afterwards.

signal damaged(fraction: float)
signal defeated

var target: Node2D
var floor_ref: IsoFloor
var active := false
var hp := 170.0
var max_hp := 170.0
var hit_r := 48.0
var elev := 0.0
var warmed := false          # the level sets this while the Lantern is held on it
var slam_hit := Callable()   # called with the ring centre (screen) when a slam lands

var _dead := false
var _ang := 0.0              # direction its shoulder faces, in ground space
var _state := "idle"         # idle | tele | rest
var _state_t := 0.0
var _cd := 3.0
var _slam_at := Vector2.ZERO
var _flash := 0.0
var _clang := 0.0
var _t := 0.0
var _fade := 1.0
var _sparks: Array[Dictionary] = []

func begin() -> void:
	max_hp = 170.0 * (0.7 if GameState.is_story() else 1.0)
	hp = max_hp
	_dead = false
	active = true
	_state = "idle"
	_cd = 3.0
	add_to_group("hittables")
	damaged.emit(1.0)

func reset_fight() -> void:
	if active and not _dead:
		hp = max_hp
		_state = "idle"
		_cd = 3.5
		damaged.emit(1.0)

func _ground(p: Vector2) -> Vector2:
	var d := p - position
	return Vector2(d.x, d.y * 2.0)

## True when the player is on the side away from the shoulder.
func behind() -> bool:
	if target == null:
		return false
	return absf(angle_difference(_ang, _ground(target.position).angle())) > 2.0

func hurt(dmg: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if not active or _dead:
		return
	if not behind() and _state != "rest":
		_clang = 0.25
		for i in 4:
			_sparks.append({"p": Vector2(randf_range(-30, 30), -70 + randf_range(-20, 20)), "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 90), "a": 0.0})
		return
	hp = maxf(hp - dmg * (1.4 if _state == "rest" else 1.0), 0.0)
	_flash = 0.2
	damaged.emit(hp / max_hp)
	if hp <= 0.0:
		_dead = true
		active = false
		remove_from_group("hittables")
		defeated.emit()

func _fury() -> float:
	return 0.7 if hp < max_hp * 0.5 else 1.0

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_clang = maxf(_clang - delta, 0.0)
	for s in _sparks:
		s["a"] = float(s["a"]) + delta
		s["p"] = Vector2(s["p"]) + Vector2(s["v"]) * delta
	_sparks = _sparks.filter(func(s): return float(s["a"]) < 0.4)
	if _dead:
		_fade = maxf(_fade - delta / 2.2, 0.0)
		if _fade <= 0.0:
			queue_free()
			return
	elif active and target:
		_tick(delta)
	queue_redraw()

func _tick(delta: float) -> void:
	# The shoulder follows you; warmth (the Lantern) slows it, and a rest slows it more.
	var rate := 1.25
	if warmed:
		rate *= 0.45
	if _state == "rest":
		rate *= 0.3
	var want := _ground(target.position).angle()
	var diff := angle_difference(_ang, want)
	_ang += clampf(diff, -rate * delta, rate * delta)
	match _state:
		"idle":
			# Drift toward the player a little so it cannot be ignored.
			var g := _ground(target.position)
			if g.length() > 110.0:
				position += Vector2(g.x, g.y * 0.5).normalized() * 38.0 * delta
			_cd -= delta
			if _cd <= 0.0:
				_state = "tele"
				_state_t = 1.0 * _fury()
				_slam_at = target.position
		"tele":
			_state_t -= delta
			if _state_t <= 0.0:
				if slam_hit.is_valid():
					slam_hit.call(_slam_at)
				_state = "rest"
				_state_t = 1.7
		"rest":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "idle"
				_cd = 2.6 * _fury()

func slam_radius() -> float:
	return 84.0

func _draw() -> void:
	var fade := _fade
	var out := Color(Palette.OUTLINE, fade)
	var face := Vector2(cos(_ang), sin(_ang) * 0.5)      # on-screen direction of the shoulder
	# Slam warning ring on the floor.
	if _state == "tele":
		var p := _slam_at - position
		draw_set_transform(p, 0.0, Vector2(1, 0.5))
		var k := 1.0 - _state_t / 1.0
		draw_circle(Vector2.ZERO, slam_radius(), Color(0.55, 0.85, 1.0, 0.12 + 0.25 * k))
		draw_arc(Vector2.ZERO, slam_radius(), 0.0, TAU, 28, Color(0.8, 0.95, 1.0, 0.8), 4.0, true)
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	for k in 3:
		draw_circle(Vector2.ZERO, 70.0 - k * 14.0, Color(0.6, 0.85, 1.0, (0.10 + k * 0.06) * fade))
	draw_set_transform(Vector2(0, -elev + sin(_t * 1.6) * 3.0), 0.0, Vector2.ONE)
	var drawn := false
	var art := Skins.art()
	if art != null:
		var org := Vector2(0, -elev + sin(_t * 1.6) * 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		drawn = art.draw_character(self, "cold_shoulder", {"t": _t, "flash": _flash, "fade": fade, "face": face, "weak": behind(), "warmed": warmed, "state": _state, "origin": org, "scale": 1.0})
		draw_set_transform(org, 0.0, Vector2.ONE)
	if not drawn:
		var body := DrawKit.ellipse(Vector2(0, -60), 38.0, 54.0, 22, 0.22, floorf(_t * 3.0))
		var body_col := Color("cfe9f7") if _state != "rest" else Color("e8f6ff")
		DrawKit.shape(self, body, Color(body_col, fade), out, 3.2, floorf(_t * 3.0))
		draw_colored_polygon(DrawKit.ellipse(Vector2(-5, -56), 22.0, 36.0, 18, 0.3, 4.0), Color("8cc4e4", fade))
		# The shoulder: a big plate of ice toward the side it faces.
		var sc := Vector2(0, -78) + face * 46.0
		var plate := PackedVector2Array([sc + Vector2(-26, -26), sc + Vector2(24, -30), sc + Vector2(34, 6), sc + Vector2(0, 30), sc + Vector2(-30, 8)])
		DrawKit.shape(self, plate, Color("eaf7ff", fade * 0.95), out, 3.4, 2.0)
		draw_line(sc + Vector2(-14, -12), sc + Vector2(12, 6), Color(0.55, 0.78, 0.95, fade), 2.0)
		# Its face is turned away: only the back of a hood.
		draw_circle(Vector2(0, -112) - face * 6.0, 14.0, Color("b9dcef", fade))
		draw_arc(Vector2(0, -112) - face * 6.0, 14.0, 0.0, TAU, 14, out, 2.6, true)
		# Weak spot hint: the back glows gold when you are behind it.
		if behind() or _state == "rest":
			draw_circle(Vector2(0, -70) - face * 40.0, 12.0 + 3.0 * sin(_t * 6.0), Color(Palette.GOLD, 0.7 * fade))
		if _flash > 0.0:
			draw_colored_polygon(body, Color(1, 1, 1, _flash * fade))
	if _clang > 0.0:
		for s in _sparks:
			draw_circle(Vector2(s["p"]), 3.0, Color(1, 0.95, 0.7, 1.0 - float(s["a"]) / 0.4))
	if warmed:
		for i in 5:
			draw_circle(Vector2(-20 + i * 10, -140 - fmod(_t * 30.0 + i * 11.0, 30.0)), 2.6, Color(Palette.CYAN, 0.7))
