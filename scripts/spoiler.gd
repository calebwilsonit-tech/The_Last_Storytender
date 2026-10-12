class_name Spoiler
extends Node2D
## The Spoiler: Pip's fear of the ending, as a floating book with its last page
## torn out. It does not throw things. It *tells you what is about to happen*,
## in huge words, and then the words come true, unless you rewrite them first.

signal speak                  # time for the next spoiler (the level decides which)
signal damaged(fraction: float)
signal struck                 # the Quill landed during the Reckoning (the level cancels a pending spoiler)
signal defeated_fight

var target: Node2D
var active := false
var certainty := 5            # sentences you must rewrite to quiet it
var interval := 8.0
var text := ""                # the sentence currently being announced
var text_ttl := 0.0
var _t := 0.0
var _cd := 4.0
var _flash := 0.0
var _stun := 0.0
var _fade := 1.0
var _defeated := false
var _home := Vector2.ZERO
var lift := 0.0

# --- The Reckoning: once five sentences are rewritten the book comes down to eye level. ---------
var reckoning := false
var hp := 140.0
var max_hp := 140.0
var hit_r := 40.0
var _dead := false
var _hover := 92.0

func begin_reckoning() -> void:
	reckoning = true
	max_hp = 140.0 * (0.7 if GameState.is_story() else 1.0)
	hp = max_hp
	_dead = false
	certainty = 0
	active = true
	_cd = 2.5
	_stun = 1.0
	_flash = 0.5
	add_to_group("hittables")
	damaged.emit(1.0)

func reset_fight() -> void:
	if reckoning and not _dead:
		hp = max_hp
		_cd = 3.0
		damaged.emit(1.0)

func hurt(dmg: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if not reckoning or _dead:
		return
	hp = maxf(hp - dmg, 0.0)
	_flash = 0.25
	_stun = maxf(_stun, 0.35)
	damaged.emit(hp / max_hp)
	struck.emit()
	if hp <= 0.0:
		_dead = true
		active = false
		remove_from_group("hittables")
		defeated_fight.emit()

func _ready() -> void:
	_home = position

func announce(sentence: String, seconds: float) -> void:
	text = sentence
	text_ttl = seconds

func recoil() -> void:
	_flash = 0.5
	_stun = 1.2
	_cd = maxf(_cd, 2.0)

func defeat() -> void:
	_defeated = true
	active = false
	text_ttl = 0.0

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
		_stun = maxf(_stun - delta, 0.0)
		_hover = lerpf(_hover, 46.0 if reckoning else 92.0, 1.0 - exp(-2.0 * delta))
		var goal := _home + (Vector2(cos(_t * 0.5) * 170.0, sin(_t * 0.8) * 70.0) if reckoning else Vector2(cos(_t * 0.4) * 60.0, sin(_t * 0.7) * 20.0))
		position = position.lerp(goal, 1.0 - exp(-1.2 * delta))
		if _stun <= 0.0:
			_cd -= delta
			if _cd <= 0.0:
				_cd = interval * (0.7 if reckoning and hp < max_hp * 0.5 else 1.0)
				speak.emit()
	queue_redraw()

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
	# The sentence it is announcing.
	if text_ttl > 0.0 and text != "":
		var font := ThemeDB.get_default_theme().default_font
		var sz := 26
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
		var at := Vector2(-w * 0.5, -78.0)
		var a := clampf(text_ttl / 0.5, 0.0, 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 9, Color(Palette.SPOILER_INK, 0.95 * a))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Color(Palette.SPOILER_GOLD, a))
