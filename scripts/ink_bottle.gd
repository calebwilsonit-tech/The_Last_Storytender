class_name InkBottle
extends Control
## Health bar: an ink bottle. As ink drains the level drops, and the glass
## cracks and leaks below 50% / 25%.

var _fraction := 1.0
var _display := 1.0

func _init() -> void:
	custom_minimum_size = Vector2(70, 110)

func set_ink(current: float, maximum: float) -> void:
	_fraction = clampf(current / maximum, 0.0, 1.0)

func _process(delta: float) -> void:
	_display = lerpf(_display, _fraction, 1.0 - exp(-8.0 * delta))
	queue_redraw()

func _draw() -> void:
	var outline := Color(0.15, 0.1, 0.08)
	var glass := Color(0.75, 0.85, 0.9, 0.35)
	var inkc := Color(0.06, 0.05, 0.14)
	var body := Rect2(8, 38, 54, 68)

	# Ink fill
	var fill_h := body.size.y * _display
	draw_rect(Rect2(body.position.x, body.end.y - fill_h, body.size.x, fill_h), inkc)
	# Glass
	draw_rect(body, glass)
	draw_rect(body, outline, false, 3.0)
	# Neck + cork
	draw_rect(Rect2(24, 16, 22, 24), glass)
	draw_rect(Rect2(24, 16, 22, 24), outline, false, 3.0)
	draw_rect(Rect2(22, 6, 26, 12), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(22, 6, 26, 12), outline, false, 2.0)

	# Cracks
	if _fraction < 0.5:
		draw_polyline(PackedVector2Array([Vector2(20, 40), Vector2(28, 56), Vector2(22, 70), Vector2(32, 84)]), outline, 2.0)
	if _fraction < 0.25:
		draw_polyline(PackedVector2Array([Vector2(52, 44), Vector2(44, 60), Vector2(50, 76), Vector2(40, 100)]), outline, 2.0)
		# Leak
		var drip := fmod(Time.get_ticks_msec() / 400.0, 1.0)
		draw_circle(Vector2(40, 100 + drip * 10.0), 3.0, Color(inkc, 1.0 - drip))
