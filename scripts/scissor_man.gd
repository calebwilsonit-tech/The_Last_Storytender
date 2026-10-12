class_name ScissorMan
extends Node2D
## The Scissor-Man ("Cut Content"): half colored, half pencil sketch, with a pair of
## shears where his hands should be. His blades deflect everything... except while
## they are jammed in a patch of paper you pasted onto his cut line.

signal damaged(fraction: float)
signal defeated
signal unjammed

var hp := 90.0
var max_hp := 90.0
var vulnerable := false
var elev := 0.0
var hit_r := 40.0
var dead := false
var _jam_t := 0.0
var _t := 0.0
var _flash := 0.0
var _clang := 0.0
var _snip := 0.0            # 0 blades open .. 1 closed
var _snip_t := -1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _move_t := 1.0
var _move_dur := 1.0
var _sparks: Array[Dictionary] = []
var _fade := 1.0

func _ready() -> void:
	add_to_group("hittables")
	_from = position
	_to = position

func move_to(p: Vector2, seconds: float) -> void:
	_from = position
	_to = p
	_move_t = 0.0
	_move_dur = maxf(seconds, 0.05)

func snip_blades() -> void:
	_snip_t = 0.0

func jam(seconds: float) -> void:
	vulnerable = true
	_jam_t = seconds

## The Quill. Only a jammed Scissor-Man can be hurt; otherwise his blades turn it aside.
func hurt(dmg: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	if not vulnerable:
		_clang = 0.25
		for i in 4:
			_sparks.append({"p": Vector2(randf_range(-30, 30), -80 + randf_range(-20, 20)), "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 90), "a": 0.0})
		return
	hp = maxf(hp - dmg, 0.0)
	_flash = 0.2
	damaged.emit(hp / max_hp)
	if hp <= 0.0:
		dead = true
		vulnerable = false
		defeated.emit()

var _gate := RedrawGate.new()

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_clang = maxf(_clang - delta, 0.0)
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta / _move_dur, 1.0)
		var e := _move_t * _move_t * (3.0 - 2.0 * _move_t)
		position = _from.lerp(_to, e)
	if _snip_t >= 0.0:
		_snip_t += delta
		_snip = clampf(sin(_snip_t / 0.45 * PI), 0.0, 1.0)
		if _snip_t >= 0.45:
			_snip_t = -1.0
			_snip = 0.0
	if vulnerable:
		_jam_t -= delta
		_snip = 1.0
		if _jam_t <= 0.0 and not dead:
			vulnerable = false
			_snip = 0.0
			unjammed.emit()
	if dead:
		_fade = maxf(_fade - delta / 2.2, 0.0)
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["a"] += delta
	_sparks = _sparks.filter(func(s): return s["a"] < 0.5)
	if _gate.ok(delta, self):
		queue_redraw()

func _blade(origin: Vector2, ang: float, length: float, col: Color) -> void:
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var pts := PackedVector2Array([origin + n * 6.0, origin + d * length, origin - n * 3.0 + d * (length * 0.15)])
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Palette.OUTLINE, 3.0, true)
	draw_line(origin + n * 1.5 + d * 6.0, origin + d * (length * 0.92), Color(1, 1, 1, 0.65), 2.0)
	# Finger loop at the root.
	draw_arc(origin - d * 9.0, 9.0, 0.0, TAU, 14, Palette.OUTLINE, 4.0, true)
	draw_arc(origin - d * 9.0, 9.0, 0.0, TAU, 14, Color("d9a830"), 2.0, true)

func _draw() -> void:
	var a := _fade
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	for k in 3:
		draw_circle(Vector2.ZERO, 54.0 - k * 12.0, Color(0, 0, 0, (0.16 + k * 0.05) * a))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var pencil := Color(0.78, 0.8, 0.86, a)
	var ink := Color(Palette.OUTLINE, a)
	var flash := Color(1, 1, 1, _flash * 3.0)
	var sway := sin(_t * 1.6) * 2.0
	var jam := vulnerable
	var drawn := false
	var art := Skins.art()
	var hc := Vector2(sway * 0.5, -108)
	var shoulder := Vector2(0, -92)
	if art != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		drawn = art.draw_character(self, "scissor_man", {"t": _t, "flash": _flash, "snip": _snip, "jam": vulnerable, "fade": a, "origin": Vector2(0, -elev), "scale": 1.0})
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if not drawn:
		# Legs: one inked and filled, one only a pencil sketch.
		var legL := PackedVector2Array([Vector2(-16, 0), Vector2(-4, 0), Vector2(-6, -44), Vector2(-18, -44)])
		var legR := PackedVector2Array([Vector2(4, 0), Vector2(16, 0), Vector2(18, -44), Vector2(6, -44)])
		draw_colored_polygon(legL, Color("2f4a7a", a))
		draw_polyline(PackedVector2Array([legL[0], legL[1], legL[2], legL[3], legL[0]]), ink, 3.0, true)
		draw_polyline(PackedVector2Array([legR[0], legR[1], legR[2], legR[3], legR[0]]), pencil, 2.4, true)
		for i in 4:
			draw_line(legR[3].lerp(legR[0], 0.1 + i * 0.22), legR[2].lerp(legR[1], 0.1 + i * 0.22), Color(pencil, 0.5 * a), 1.2)
		# Coat: left half colored, right half still being drawn.
		var coat := PackedVector2Array([Vector2(-22, -44), Vector2(22, -44), Vector2(26, -92), Vector2(-26, -92)])
		var coatL := PackedVector2Array([coat[0], Vector2(0, -44), Vector2(0, -92), coat[3]])
		draw_colored_polygon(coatL, Color("2f4a7a", a).lightened(_flash * 1.5))
		draw_polyline(PackedVector2Array([coat[0], coat[1], coat[2], coat[3], coat[0]]), pencil, 2.6, true)
		draw_polyline(PackedVector2Array([coat[0], Vector2(0, -44), Vector2(0, -92), coat[3], coat[0]]), ink, 3.0, true)
		for i in 8:
			var y := -48.0 - i * 5.5
			draw_line(Vector2(2, y), Vector2(24 - i * 0.3, y - 3), Color(pencil, 0.55 * a), 1.2)
		# A tailor's measuring tape draped across, with ticks.
		var t0 := Vector2(-24, -86)
		var t1 := Vector2(24, -54)
		draw_line(t0, t1, Color("e8c860", a), 7.0)
		for i in 10:
			var tp := t0.lerp(t1, i / 9.0)
			draw_line(tp, tp + Vector2(-2, -4), Color(Palette.OUTLINE, 0.8 * a), 1.4)
		# Head: a round sketch with two button eyes and a pincushion on top.
		draw_colored_polygon(DrawKit.ellipse(hc, 15.0, 17.0, 18, 0.03, 4.0), Color("e9d7c0", a))
		draw_polyline(DrawKit.ellipse(hc, 15.0, 17.0, 18, 0.03, 4.0) + PackedVector2Array([hc + Vector2(15, 0)]), ink, 3.0, true)
		for ex in [-6.0, 6.0]:
			draw_circle(hc + Vector2(ex, -2), 4.0, Color("1a1a24", a))
			draw_line(hc + Vector2(ex - 2, -4), hc + Vector2(ex + 2, 0), Color(1, 1, 1, a), 1.2)
			draw_line(hc + Vector2(ex - 2, 0), hc + Vector2(ex + 2, -4), Color(1, 1, 1, a), 1.2)
		draw_line(hc + Vector2(-6, 9), hc + Vector2(6, 9), Color(ink, 0.8), 2.0)
		draw_circle(hc + Vector2(0, -20), 7.0, Color(Palette.CRITIC_RED, a))
		draw_circle(hc + Vector2(0, -20), 7.0, Color(0, 0, 0, 0.0))
		for pin in [-4.0, 0.0, 4.0]:
			draw_line(hc + Vector2(pin, -20), hc + Vector2(pin * 1.6, -32), Color("e8e8f0", a), 1.6)
			draw_circle(hc + Vector2(pin * 1.6, -32), 1.6, Color("d9a830", a))
		# The shears: two blades like rabbit ears, closing for a snip, crossed and stuck when jammed.
		var open := 1.0 - _snip
		var lang := lerpf(-PI * 0.5 - 0.06, -PI * 0.5 - 0.62, open)
		var rang := lerpf(-PI * 0.5 + 0.06, -PI * 0.5 + 0.62, open)
		if jam:
			lang = -PI * 0.5 + 0.18 + sin(_t * 30.0) * 0.03
			rang = -PI * 0.5 - 0.18 - sin(_t * 30.0) * 0.03
		var steel := Color("c8ced9", a).lerp(Color.WHITE, _flash * 3.0)
		_blade(shoulder + Vector2(-8, 0), lang, 74.0, steel)
		_blade(shoulder + Vector2(8, 0), rang, 74.0, steel.darkened(0.12))
	if jam:
		# Caught in the paper: a tangle of thread, sparks, and a dizzy ring of stars.
		for i in 6:
			var ang := _t * 2.0 + i * TAU / 6.0
			draw_circle(hc + Vector2(cos(ang) * 22.0, -6 + sin(ang) * 8.0), 2.6, Color(Palette.SPOILER_GOLD, a))
		var secs := ceili(_jam_t)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(-8, -150), "%d" % secs, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(Palette.SPOILER_GOLD, a))
	if _clang > 0.0:
		draw_circle(shoulder + Vector2(0, -40), 18.0 + (0.25 - _clang) * 60.0, Color(1, 1, 1, _clang * 3.0))
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(-16, -150), "clang", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1, 1, 1, _clang * 4.0))
	for s in _sparks:
		draw_circle(s["p"], 2.4, Color(1, 0.9, 0.5, 1.0 - float(s["a"]) * 2.0))
	if _flash > 0.0:
		draw_circle(Vector2(0, -80), 50.0, flash)
