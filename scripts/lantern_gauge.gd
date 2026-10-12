class_name LanternGauge
extends Control
## Lantern fuel: a small lantern icon beside a cyan bar. It drains while the
## beam is on and refills when you rest it or collect Mnemosynth.

var _fraction := 1.0
var _display := 1.0

func _init() -> void:
	custom_minimum_size = Vector2(190, 30)

func set_energy(cur: float, maximum: float) -> void:
	_fraction = clampf(cur / maximum, 0.0, 1.0)

func _process(delta: float) -> void:
	_display = lerpf(_display, _fraction, 1.0 - exp(-12.0 * delta))
	queue_redraw()

func _draw() -> void:
	var low := _display < 0.2
	var col := Palette.CYAN if not low else Color("ff8a6a")
	var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 90.0) if low else 1.0
	# Icon.
	draw_rect(Rect2(8, 4, 12, 3), Color("3a3f4a"))
	draw_rect(Rect2(5, 7, 18, 16), Color(col, 0.25 + 0.7 * _display * flick))
	draw_rect(Rect2(5, 7, 18, 16), Palette.OUTLINE, false, 2.4)
	draw_line(Vector2(5, 7), Vector2(23, 23), Color("3a3f4a"), 1.4)
	draw_line(Vector2(23, 7), Vector2(5, 23), Color("3a3f4a"), 1.4)
	draw_rect(Rect2(3, 23, 22, 4), Color("3a3f4a"))
	# Bar.
	var bar := Rect2(34, 10, 140, 10)
	draw_rect(bar, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _display, bar.size.y)), Color(col, 0.95))
	draw_rect(bar, Palette.OUTLINE, false, 2.2)
