class_name Critic
extends Node2D
## The Critic: Garrick's own inner voice, made of red ink. It cannot be fought
## with a blade. It shouts discouraging words (WordBolt) and quiets only as the
## Storytender holds up the memories it was built to drown out.

signal fired(word: String, fx: String, origin: Vector2, dir: Vector2)
signal pool_requested(at: Vector2)   # a patch of floor is about to be cut with red ink

const WORDS := [
	{"w": "Derivative!", "fx": "slow"},
	{"w": "Boring!", "fx": "dim"},
	{"w": "Overwritten.", "fx": "slow"},
	{"w": "Clichéd!", "fx": "dim"},
	{"w": "Nobody asked.", "fx": "slow"},
	{"w": "Too slow!", "fx": "slow"},
]

var target: Node2D
var layers := 3          # ink layers remaining; each memory strips one
var active := false
var lift := 0.0
var _t := 0.0
var _cd := 3.0
var _tele := 0.0
var _volley := 0
var _word: Dictionary = {}
var _stun := 0.0
var _flash := 0.0
var _home := Vector2.ZERO
var _dissolve := -1.0    # >= 0 while dissolving into the floor

func _ready() -> void:
	_home = position

func recoil() -> void:
	_stun = 1.4
	_flash = 0.5
	_tele = 0.0
	_cd = 2.5

func dissolve() -> void:
	_dissolve = 0.0
	_tele = 0.0
	active = false

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	if _dissolve >= 0.0:
		_dissolve += delta
		queue_redraw()
		return
	if _stun > 0.0:
		_stun -= delta
	elif active and target:
		var goal := _home + Vector2(cos(_t * 0.5) * 90.0, sin(_t * 0.8) * 34.0)
		position = position.lerp(goal, 1.0 - exp(-1.5 * delta))
		if _tele > 0.0:
			_tele -= delta
			if _tele <= 0.0:
				_fire()
		else:
			_cd -= delta
			if _cd <= 0.0:
				_word = WORDS[randi() % WORDS.size()]
				_tele = 0.85
				_cd = 1.7 + (3 - layers) * 0.6    # quieter with every memory held up
	queue_redraw()

## Speed of its words: a little slower as it quiets, scaled by difficulty.
func bolt_speed() -> float:
	return (190.0 - (3 - layers) * 10.0) * GameState.bolt_speed_mult()

func _fire() -> void:
	var from := position
	var tp := target.position
	# Lead the shot: aim where you are going, not where you are.
	var dist := from.distance_to(tp)
	var tv: Vector2 = target.get("velocity") if target.get("velocity") != null else Vector2.ZERO
	var aim: Vector2 = tp + tv * (dist / maxf(bolt_speed(), 1.0))
	var d: Vector2 = aim - from
	if d == Vector2.ZERO:
		return
	var base: Vector2 = d.normalized()
	var spread: Array = [0.0]
	_volley += 1
	if layers >= 3:
		# Alternate: a flanking pair (stand still and it misses), then a single shot straight at you.
		spread = [-0.28, 0.28] if _volley % 2 == 0 else [0.0]
	elif layers == 2:
		spread = [-0.35, 0.0, 0.35]
	for a: float in spread:
		fired.emit(_word["w"], _word["fx"], from, base.rotated(a))
	# With fewer layers it can no longer hurl as many words, but it cuts the floor instead.
	if layers <= 2:
		pool_requested.emit(aim)

func _draw() -> void:
	var fade := 1.0
	if _dissolve >= 0.0:
		fade = clampf(1.0 - _dissolve / 2.4, 0.0, 1.0)
		if fade <= 0.0:
			return
	var boil := int(_t * 8.0)
	var shake := Vector2.ZERO
	if _stun > 0.0:
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0
	elif _tele > 0.0:
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.8
	# Pool of ink on the floor.
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1, 0.5))
	for k in 3:
		draw_circle(Vector2.ZERO, 54.0 - k * 12.0, Color(Palette.CRITIC_RED, (0.20 + k * 0.08) * fade))
	var bob := sin(_t * 1.7) * 5.0
	draw_set_transform(Vector2(0, -lift - 18.0 + bob) + shake, 0.0, Vector2.ONE)
	var body := DrawKit.ellipse(Vector2(0, -52), 30.0, 46.0, 22, 0.28, float(boil))
	var edge := Color(Palette.OUTLINE, fade)
	DrawKit.shape(self, body, Color(Palette.CRITIC_RED, fade), edge, 3.0, float(boil))
	draw_colored_polygon(DrawKit.ellipse(Vector2(-4, -50), 17.0, 30.0, 18, 0.35, float(boil) + 5.0), Color(Palette.CRITIC_DARK, fade))
	# Drips.
	for i in 5:
		var x := -22.0 + i * 11.0
		var l := 8.0 + fmod(float(i) * 7.3 + _t * 12.0, 14.0)
		draw_line(Vector2(x, -10), Vector2(x, -10 + l), Color(Palette.CRITIC_RED, fade), 4.0)
		draw_circle(Vector2(x, -10 + l), 3.0, Color(Palette.CRITIC_RED, fade))
	# Long arms ending in quill claws.
	for sgn in [-1.0, 1.0]:
		var wob := sin(_t * 2.2 + sgn) * 4.0
		var sh := Vector2(sgn * 26.0, -70.0)
		var elbow := Vector2(sgn * 56.0, -52.0 + wob)
		var hand := Vector2(sgn * 48.0, -22.0 + wob * 1.4)
		draw_polyline(PackedVector2Array([sh, elbow, hand]), Color(Palette.CRITIC_DARK, fade), 9.0, true)
		draw_polyline(PackedVector2Array([sh, elbow, hand]), Color(Palette.CRITIC_RED, fade), 5.0, true)
		for k in 3:
			var tip := hand + Vector2(sgn * (6.0 + k * 5.0), 14.0 + k * 3.0)
			draw_colored_polygon(PackedVector2Array([hand + Vector2(-2, 0), hand + Vector2(3, 0), tip]), Color(Palette.OUTLINE, fade))
	# Ink layers: rotating red plates that peel away as memories are remembered.
	for i in layers:
		var a := _t * (0.6 + i * 0.25) + i * TAU / 3.0
		draw_arc(Vector2(0, -52), 54.0 + i * 7.0, a, a + 1.7, 14, Color(Palette.CRITIC_RED.lightened(0.15), fade * 0.9), 6.0, true)
		draw_arc(Vector2(0, -52), 54.0 + i * 7.0, a, a + 1.7, 14, Color(Palette.OUTLINE, fade * 0.8), 1.6, true)
	# Face: two white slits and a jagged mouth.
	var open := 3.0 + (4.0 if _tele > 0.0 else 0.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -80), Vector2(-4, -76), Vector2(-5, -73), Vector2(-17, -77)]), Color(1, 1, 1, fade))
	draw_colored_polygon(PackedVector2Array([Vector2(16, -80), Vector2(4, -76), Vector2(5, -73), Vector2(17, -77)]), Color(1, 1, 1, fade))
	var mouth := PackedVector2Array()
	for i in 9:
		mouth.append(Vector2(-14.0 + i * 3.5, -62.0 + (open if i % 2 == 0 else -open * 0.3)))
	draw_polyline(mouth, Color(1, 1, 1, fade), 2.4, true)
	if _flash > 0.0:
		draw_colored_polygon(body, Color(1, 1, 1, _flash * fade))
	# Telegraph: the word it is about to hurl.
	if _tele > 0.0 and not _word.is_empty():
		var font := ThemeDB.get_default_theme().default_font
		var txt: String = _word["w"]
		var sz := 30
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
		draw_string_outline(font, Vector2(-w * 0.5, -112), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 8, Color(Palette.OUTLINE, 0.9))
		draw_string(font, Vector2(-w * 0.5, -112), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Color("ff6a5c"))
	# Falling ink while dissolving.
	if _dissolve >= 0.0:
		for i in 14:
			var ph := fmod(_dissolve * 0.7 + i * 0.19, 1.0)
			draw_circle(Vector2(-26.0 + i * 4.0, -90.0 + ph * 90.0), 3.0, Color(Palette.CRITIC_RED, fade))
