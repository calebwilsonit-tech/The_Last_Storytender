class_name Redactor
extends StaticBody2D
## A floating black censor bar that blocks a path. The Quill passes through it;
## only light can "highlight" what is written underneath, and once the text is
## revealed the way is open.

signal revealed

@export var axis := Vector2(1, 0)       # grid direction the bar runs along
@export var length := 3.0               # in cells
@export var text := "the way up"
var hit_r := 46.0
var progress := 0.0
var elev := 0.0
var _lit := false
var _t := 0.0
var _gone := false
var _fade := 1.0
var _poly: CollisionPolygon2D
var _seed := 0.0

func _ready() -> void:
	_seed = position.x * 0.013 + position.y * 0.007
	_poly = CollisionPolygon2D.new()
	var a := axis.normalized()
	var n := Vector2(-a.y, a.x)
	var h := length * 0.5
	_poly.polygon = PackedVector2Array([
		Iso.to_screen(a * -h + n * -0.3), Iso.to_screen(a * h + n * -0.3),
		Iso.to_screen(a * h + n * 0.3), Iso.to_screen(a * -h + n * 0.3)])
	add_child(_poly)
	add_to_group("lightable")

func lit(delta: float) -> void:
	if _gone:
		return
	_lit = true
	progress = minf(progress + delta / 1.4, 1.0)
	if progress >= 1.0:
		_gone = true
		_poly.set_deferred("disabled", true)
		remove_from_group("lightable")
		revealed.emit()

func _process(delta: float) -> void:
	_t += delta
	if _gone:
		_fade -= delta / 1.6
		if _fade <= 0.0:
			queue_free()
			return
	elif not _lit:
		progress = maxf(progress - delta * 0.4, 0.0)
	_lit = false
	queue_redraw()

static func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)

func _draw() -> void:
	var a := axis.normalized()
	var lift := elev + 36.0 + sin(_t * 1.8 + _seed) * 3.0
	var h := length * 0.5
	var p0 := Iso.to_screen(a * -h)
	var p1 := Iso.to_screen(a * h)
	var mid := (p0 + p1) * 0.5
	# What is written underneath, in the Old Script, brightening with the light.
	var font := ThemeDB.get_default_theme().default_font
	var sz := 22
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var tpos := mid + Vector2(-w * 0.5, -lift + 7.0)
	var ta := clampf(progress * 1.5, 0.0, 1.0) * _fade
	if ta > 0.0:
		draw_string_outline(font, tpos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 6, Color(Palette.OUTLINE, 0.8 * ta))
		draw_string(font, tpos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Color(Palette.CYAN.lightened(0.5), ta))
	# The bar, cut into slices that fall away as the highlight spreads.
	var n := 12
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var thresh := _h(float(i) + _seed * 17.0)
		var vis := clampf((thresh - progress * 1.15) * 4.0 + 0.4, 0.0, 1.0) * _fade
		if vis <= 0.01:
			continue
		var a0 := p0.lerp(p1, t0)
		var a1 := p0.lerp(p1, t1)
		var jit := Vector2(0, (_h(float(i) + floorf(_t * 8.0)) - 0.5) * 2.0 * (1.0 + progress * 3.0))
		var q := PackedVector2Array([a0 + Vector2(0, -lift - 13) + jit, a1 + Vector2(0, -lift - 13) + jit, a1 + Vector2(0, -lift + 13) + jit, a0 + Vector2(0, -lift + 13) + jit])
		draw_colored_polygon(q, Color(0.04, 0.03, 0.07, vis))
		if _h(float(i) * 3.1 + floorf(_t * 10.0)) > 0.9:
			draw_rect(Rect2(a0 + Vector2(0, -lift - 4) + jit, Vector2((a1 - a0).x, 3)), Color(1, 1, 1, 0.5 * vis))
	if progress < 0.99 and not _gone:
		# Ground shadow so the bar reads as floating.
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
		draw_line(p0, p1, Color(0, 0, 0, 0.25), 8.0)
