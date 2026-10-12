class_name Spoiler
extends Node2D
## The Spoiler: Pip's fear of the ending, as a floating book with its last page torn out. It tells you
## what is about to happen, in huge words, and then the words come true, unless you rewrite them first.
##
## It fights. In a rhythm it opens its pages and fans paper cuts at you, or rises and dives onto where you
## stand; every third move it stops, drops to eye level and READS a sentence aloud (a countdown ring shows
## how long you have). Strike the book with the Quill while it reads and you rewrite the sentence out of
## existence: it cancels, the book reels, and (in the Reckoning) it takes a real wound. Let the window run
## out and the sentence comes true. It spits slow paper cuts the whole time it reads, so getting close
## enough to strike is the skill.

signal speak                          # entering a read: the level creates the sentence(s) and calls announce()
signal rewritten                      # a strike landed while it was reading: cancel one pending sentence
signal fired(origin: Vector2, dirs: Array, speed: float)    # paper cuts
signal slam(at: Vector2)              # the dive landed
signal damaged(fraction: float)
signal defeated_fight

var target: Node2D
var active := false
var certainty := 5            # sentences you must rewrite to quiet it
var interval := 8.0           # (kept for the level; the book now sets its own rhythm)
var rewrites := 0             # how many sentences have been rewritten so far (the level keeps this current)
var lift := 0.0
var text := ""
var text_ttl := 0.0

var _t := 0.0
var _cd := 3.0
var _flash := 0.0
var _fade := 1.0
var _defeated := false
var _home := Vector2.ZERO
var _hover := 92.0

# the move machine
var _state := "roam"          # roam | fan_tele | fan_recover | dive_tele | dive | rest | read | stagger
var _state_t := 0.0
var _read_total := 1.0
var _read_lines: Array[String] = []
var _read_left := 0
var _spiral_cd := 0.0
var _moves := 0
var _last_move := ""
var _dive_at := Vector2.ZERO
var _aim_dirs: Array = []

# --- The Reckoning: once five sentences are rewritten the book comes down and can be hurt. -------
var reckoning := false
var hp := 140.0
var max_hp := 140.0
var hit_r := 44.0
var _dead := false

func begin_reckoning() -> void:
	reckoning = true
	max_hp = 140.0 * (0.7 if GameState.is_story() else 1.0)
	hp = max_hp
	_dead = false
	certainty = 0
	active = true
	_cd = 2.0
	_state = "stagger"
	_state_t = 1.4
	_flash = 0.5
	damaged.emit(1.0)

func reset_fight() -> void:
	if reckoning and not _dead:
		hp = max_hp
		damaged.emit(1.0)
	reset_moves()

## After the player dies: the book goes back to circling, with a breather before its next move.
func reset_moves() -> void:
	_state = "roam"
	_cd = 3.0
	_read_lines.clear()
	_read_left = 0
	text = ""
	text_ttl = 0.0

func _ready() -> void:
	_home = position
	add_to_group("hittables")

# --- Called by the level ---------------------------------------------------------------------
## The level hands over a sentence to read aloud. Called once per sentence while the book is reading.
func announce(sentence: String, seconds: float) -> void:
	_read_lines.append(sentence)
	_read_left = _read_lines.size()
	_state_t = maxf(_state_t, seconds)
	_read_total = _state_t

func recoil() -> void:
	_flash = 0.5

func defeat() -> void:
	_defeated = true
	active = false
	_read_lines.clear()

# --- Being struck ---------------------------------------------------------------------------------
func hurt(dmg: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if _dead or _defeated or not active:
		return
	if _state == "read" and _read_left > 0:
		# A rewrite: the Quill strikes a sentence out of the book.
		_read_lines.remove_at(0)
		_read_left -= 1
		_flash = 0.4
		rewritten.emit()
		if reckoning:
			_wound(12.0)
		if _read_left <= 0:
			_enter("stagger", 2.4 if reckoning else 1.6)
		return
	if reckoning:
		var mult := 2.0 if _state == "stagger" else (1.5 if _state == "rest" else 1.0)
		_wound(dmg * mult)
	else:
		_flash = 0.12      # in the puzzle half the book shrugs off an ordinary blow

func _wound(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	_flash = 0.25
	damaged.emit(hp / max_hp)
	if hp <= 0.0 and not _dead:
		_dead = true
		active = false
		remove_from_group("hittables")
		defeated_fight.emit()

# --- The move machine -----------------------------------------------------------------------------
func _enter(st: String, secs: float = 0.0) -> void:
	_state = st
	_state_t = secs

func _roam_gap() -> float:
	if reckoning:
		return 1.1
	return maxf(1.9 - 0.2 * rewrites, 0.9)

func _choose_move() -> void:
	_moves += 1
	if _moves % 3 == 0:
		_begin_read()
		return
	var pick := "dive" if (_last_move != "dive" and randf() < 0.45) else "fan"
	_last_move = pick
	if pick == "fan":
		_aim_fan()
		_enter("fan_tele", 0.75 if not reckoning else 0.6)
	else:
		_dive_at = target.position if target else position
		_enter("dive_tele", 1.0 if not reckoning else 0.8)

func _aim_fan() -> void:
	_aim_dirs.clear()
	var base := (target.position - position).normalized() if target else Vector2.DOWN
	var n := 5 + (2 if (rewrites >= 3 or reckoning) else 0)
	for i in n:
		var k := (float(i) / float(n - 1) - 0.5) * 1.15
		_aim_dirs.append(base.rotated(k))

func _begin_read() -> void:
	_read_lines.clear()
	_read_left = 0
	_state = "read"
	_state_t = 0.0
	_spiral_cd = 0.6
	speak.emit()
	if _read_lines.is_empty():       # the level had nothing to say
		_enter("roam")
		_cd = _roam_gap()

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	text_ttl = maxf(text_ttl - delta, 0.0)
	if _defeated:
		_fade = maxf(_fade - delta / 2.6, 0.0)
		if _fade <= 0.0:
			queue_free()
			return
	elif active:
		_tick(delta)
	if _gate.ok(delta, self):
		queue_redraw()

var _gate := RedrawGate.new()

func _tick(delta: float) -> void:
	var hover_goal := 92.0 if not reckoning else 60.0
	match _state:
		"roam":
			_drift(delta, 1.2)
			_cd -= delta
			if _cd <= 0.0:
				_choose_move()
		"fan_tele":
			_drift(delta, 0.5)
			_state_t -= delta
			if target and _state_t > 0.2:
				_aim_fan()                  # keeps tracking you until the last instant
			if _state_t <= 0.0:
				fired.emit(position, _aim_dirs.duplicate(), 150.0 if not reckoning else 175.0)
				_enter("fan_recover", 0.55)
		"fan_recover":
			_state_t -= delta
			if _state_t <= 0.0:
				_enter("roam")
				_cd = _roam_gap()
		"dive_tele":
			hover_goal = 140.0
			_state_t -= delta
			if target and _state_t > 0.35:
				_dive_at = target.position   # the shadow follows you, then locks
			if _state_t <= 0.0:
				_enter("dive", 0.8)
		"dive":
			hover_goal = 4.0
			position = position.lerp(_dive_at, 1.0 - exp(-11.0 * delta))
			_state_t -= delta
			if position.distance_to(_dive_at) < 16.0 or _state_t <= 0.0:
				position = _dive_at
				slam.emit(_dive_at)
				if reckoning:
					var ring: Array = []
					for i in 8:
						ring.append(Vector2.from_angle(TAU * i / 8.0))
					fired.emit(position, ring, 120.0)
				_enter("rest", 1.5 if not reckoning else 1.2)
		"rest":
			hover_goal = 16.0
			_state_t -= delta
			if _state_t <= 0.0:
				_enter("roam")
				_cd = _roam_gap()
		"read":
			hover_goal = 54.0
			_state_t -= delta
			_spiral_cd -= delta
			if _spiral_cd <= 0.0:
				_spiral_cd = 0.9 if not reckoning else 0.65
				var a := _t * 1.4
				fired.emit(position, [Vector2.from_angle(a), Vector2.from_angle(a + PI)], 130.0)
			if _state_t <= 0.0 or _read_left <= 0:
				_read_lines.clear()
				_read_left = 0
				_enter("roam")
				_cd = _roam_gap()
		"stagger":
			hover_goal = 40.0
			_state_t -= delta
			if _state_t <= 0.0:
				_enter("roam")
				_cd = _roam_gap()
	_hover = lerpf(_hover, hover_goal, 1.0 - exp(-4.0 * delta))

## The book circles its home; in the Reckoning it also leans toward you.
func _drift(delta: float, rate: float) -> void:
	var goal := _home + (Vector2(cos(_t * 0.5) * 170.0, sin(_t * 0.8) * 70.0) if reckoning else Vector2(cos(_t * 0.4) * 60.0, sin(_t * 0.7) * 20.0))
	if reckoning and target:
		goal = goal.lerp(target.position, 0.35)
	position = position.lerp(goal, 1.0 - exp(-rate * delta))

func _page(side: float, flap: float, col: Color) -> void:
	# One open page, hinged at the spine and swept up by `flap`.
	var base := Vector2(0, 0)
	var tip := Vector2(side * 58.0, -28.0 - flap * 18.0)
	var pts := PackedVector2Array([base, base + Vector2(side * 4.0, -34.0), tip + Vector2(0, -34.0), tip + Vector2(side * 4.0, 6.0)])
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Palette.OUTLINE, 3.0, true)
	# Lines of printed text, some cut away by glitches.
	for i in 5:
		var tt := 0.15 + i * 0.16
		var a := pts[0].lerp(pts[3], tt).lerp(pts[1].lerp(pts[2], tt), 0.15)
		var b := pts[0].lerp(pts[3], tt).lerp(pts[1].lerp(pts[2], tt), 0.85)
		var cut := fmod(floor(_t * 6.0) * 0.37 + i * 0.21, 1.0)
		draw_line(a, a.lerp(b, cut), Color(Palette.SPOILER_INK, 0.55), 2.0)
		draw_line(a.lerp(b, minf(cut + 0.12, 1.0)), b, Color(Palette.SPOILER_INK, 0.55), 2.0)

func _draw() -> void:
	var fade := _fade
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	for k in 3:
		draw_circle(Vector2.ZERO, 70.0 - k * 16.0, Color(Palette.GLITCH, (0.10 + 0.06 * k) * fade))
	draw_set_transform(Vector2(0, -lift - _hover + sin(_t * 1.4) * 6.0), 0.0, Vector2.ONE)
	var flap := sin(_t * 2.6)
	var drawn := false
	var art := Skins.art()
	if art != null:
		var org := Vector2(0, -lift - _hover + sin(_t * 1.4) * 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		drawn = art.draw_character(self, "spoiler", {"t": _t, "flash": _flash, "fade": fade, "origin": org, "scale": 1.0})
		draw_set_transform(org, 0.0, Vector2.ONE)
	if not drawn:
		# Cover (dark, ominous), then the two flapping pages.
		var cover := PackedVector2Array([Vector2(-66, 14), Vector2(66, 14), Vector2(60, -40), Vector2(-60, -40)])
		draw_colored_polygon(cover, Color(Palette.SPOILER_INK, fade))
		draw_polyline(PackedVector2Array([cover[0], cover[1], cover[2], cover[3], cover[0]]), Color(Palette.OUTLINE, fade), 3.0, true)
		_page(-1.0, flap, Palette.PAGE.lerp(Color.WHITE, _flash * 2.0))
		_page(1.0, -flap, Palette.PAGE_SHADE.lerp(Color.WHITE, _flash * 2.0))
		draw_line(Vector2(0, 8), Vector2(0, -40), Color(Palette.OUTLINE, fade), 5.0)
		# The torn-out last page: ragged edge, flapping loose beside it.
		var tp := PackedVector2Array([Vector2(70, -4), Vector2(96, -16 + flap * 6.0), Vector2(100, 14), Vector2(92, 22), Vector2(86, 12), Vector2(78, 26), Vector2(72, 14)])
		draw_colored_polygon(tp, Color(Palette.PAGE, fade))
		draw_polyline(PackedVector2Array([tp[0], tp[1], tp[2], tp[3], tp[4], tp[5], tp[6]]), Color(Palette.OUTLINE, fade), 2.4, true)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(80, 8), "END", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(Palette.CRITIC_RED, fade))
		# Eyes: gold exclamation marks, because it cannot stop telling you things.
		for ex in [-22.0, 22.0]:
			var wob := sin(_t * 5.0 + ex) * 1.5
			draw_line(Vector2(ex, -34 + wob), Vector2(ex, -20 + wob), Color(Palette.SPOILER_GOLD, fade), 5.0)
			draw_circle(Vector2(ex, -12 + wob), 3.4, Color(Palette.SPOILER_GOLD, fade))
	# Purple glitch arcs.
	for a in 3:
		var ang := _t * 1.8 + a * TAU / 3.0
		draw_arc(Vector2(0, -12), 84.0 + a * 6.0, ang, ang + 1.0, 10, Color(Palette.GLITCH, 0.6 * fade), 2.4, true)
	_draw_moves(fade)

## What the book is doing right now, readable at a glance: the fan's aim, the dive's shadow, the reading
## countdown with its sentences, and a pulse that says "strike me now".
func _draw_moves(fade: float) -> void:
	var font := ThemeDB.get_default_theme().default_font
	var body := Vector2(0, -lift - _hover + sin(_t * 1.4) * 6.0)
	if _state == "fan_tele":
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
		var k := 1.0 - clampf(_state_t / 0.75, 0.0, 1.0)
		for d: Vector2 in _aim_dirs:
			draw_line(d * 40.0, d * (120.0 + 140.0 * k), Color(Palette.CRITIC_RED, 0.25 + 0.4 * k), 2.0)
	elif _state == "dive_tele" or _state == "dive":
		draw_set_transform(_dive_at - position + Vector2(0, -lift), 0.0, Vector2(1, 0.5))
		var k2 := 1.0 - clampf(_state_t / 1.0, 0.0, 1.0) if _state == "dive_tele" else 1.0
		draw_circle(Vector2.ZERO, 74.0, Color(1.0, 0.35, 0.3, 0.12 + 0.25 * k2))
		draw_arc(Vector2.ZERO, 74.0, 0.0, TAU, 28, Color(1.0, 0.5, 0.4, 0.9), 3.0, true)
		draw_circle(Vector2.ZERO, 74.0 * k2, Color(1.0, 0.35, 0.3, 0.2))
	elif _state == "read" and _read_left > 0:
		draw_set_transform(body + Vector2(0, -12), 0.0, Vector2.ONE)
		var frac := clampf(_state_t / maxf(_read_total, 0.01), 0.0, 1.0)
		var pulse := 0.6 + 0.4 * sin(_t * 12.0)
		draw_arc(Vector2.ZERO, 92.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 36, Color(Palette.SPOILER_GOLD, 0.95 * fade), 5.0, true)
		draw_arc(Vector2.ZERO, 98.0, 0.0, TAU, 36, Color(1, 1, 1, 0.25 * pulse * fade), 2.0, true)
		draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
		for i in _read_lines.size():
			var line: String = _read_lines[i]
			var sz := 26
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
			var at := Vector2(-w * 0.5, body.y - 100.0 - (_read_lines.size() - 1 - i) * 32.0)
			draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 9, Color(Palette.SPOILER_INK, 0.95 * fade))
			draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Color(Palette.SPOILER_GOLD, fade))
		var hint := "STRIKE IT"
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
		draw_string_outline(font, Vector2(-hw * 0.5, body.y + 60.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 6, Color(Palette.OUTLINE, 0.8 * pulse))
		draw_string(font, Vector2(-hw * 0.5, body.y + 60.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1, 1, 1, pulse))
