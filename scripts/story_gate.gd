class_name StoryGate
extends StaticBody2D
## A paper-cutout gate across a path: a wall of bound pages with a padlock.
## It blocks movement until opened (by rewriting a sentence, or fitting an item).

signal opened

@export var axis := Vector2(0, 1)   # grid direction the gate spans
@export var length := 3.0           # in cells
@export var label := "LOCKED"
var is_open := false
var elev := 0.0
var _slide := 0.0                   # 0 closed .. 1 open
var _t := 0.0
var _poly: CollisionPolygon2D

func _ready() -> void:
	_poly = CollisionPolygon2D.new()
	var a := axis.normalized()
	var n := Vector2(-a.y, a.x)
	var h := length * 0.5
	_poly.polygon = PackedVector2Array([
		Iso.to_screen(a * -h + n * -0.25), Iso.to_screen(a * h + n * -0.25),
		Iso.to_screen(a * h + n * 0.25), Iso.to_screen(a * -h + n * 0.25)])
	add_child(_poly)

func open() -> void:
	if is_open:
		return
	is_open = true
	_poly.set_deferred("disabled", true)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_poly.set_deferred("disabled", false)

func _process(delta: float) -> void:
	_t += delta
	_slide = move_toward(_slide, 1.0 if is_open else 0.0, delta / 1.2)
	queue_redraw()

func _draw() -> void:
	if _slide >= 1.0:
		return
	var a := axis.normalized()
	var h := length * 0.5
	var p0 := Iso.to_screen(a * -h)
	var p1 := Iso.to_screen(a * h)
	var height := 74.0 * (1.0 - _slide)
	if height <= 1.0:
		return
	var pa := p0 + Vector2(0, -elev)
	var pb := p1 + Vector2(0, -elev)
	# A wall of book-spines: vertical strips in muted colors.
	var n := int(length * 3.0)
	var cols := [Color("8e3b32"), Color("2f5d7a"), Color("5b7a3a"), Color("8a6a2f"), Color("5a3a6a")]
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a0 := pa.lerp(pb, t0)
		var a1 := pa.lerp(pb, t1)
		var q := PackedVector2Array([a0, a1, a1 + Vector2(0, -height), a0 + Vector2(0, -height)])
		draw_colored_polygon(q, cols[i % cols.size()])
		draw_polyline(PackedVector2Array([q[0], q[1], q[2], q[3], q[0]]), Palette.OUTLINE, 2.2, true)
		draw_line(q[3].lerp(q[0], 0.3), q[2].lerp(q[1], 0.3), Color("e8c86a", 0.8), 1.4)
	# Padlock.
	if not is_open:
		var m := (pa + pb) * 0.5 + Vector2(0, -height * 0.5)
		draw_rect(Rect2(m + Vector2(-12, -6), Vector2(24, 20)), Palette.GOLD)
		draw_rect(Rect2(m + Vector2(-12, -6), Vector2(24, 20)), Palette.OUTLINE, false, 2.4)
		draw_arc(m + Vector2(0, -6), 8.0, PI, TAU, 10, Palette.OUTLINE, 3.0, true)
		var font := ThemeDB.get_default_theme().default_font
		draw_string_outline(font, m + Vector2(-22, -height * 0.5 - 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 5, Color(Palette.OUTLINE, 0.9))
		draw_string(font, m + Vector2(-22, -height * 0.5 - 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color("ffd24a"))
