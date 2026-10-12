class_name DungeonKey
extends Node2D
## A thing carried out of one room to open a door in another. Each dungeon names its own ("hammer",
## "tongs", "bellows"...). Drawn procedurally: a gilt tag hanging in the air with the object's outline on it.

var kind := "hammer"
var elev := 0.0
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(_t * 2.2) * 3.0
	var c := Vector2(0, -34 + bob - elev)
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for rad in [32.0, 22.0]:
		draw_circle(c, rad, Color(Palette.GOLD, 0.09))
	draw_circle(c, 17.0, Color("e8c86a"))
	draw_arc(c, 17.0, 0.0, TAU, 24, Palette.OUTLINE, 2.4, true)
	var ink := Color("3a2a18")
	match kind:
		"hammer":
			draw_line(c + Vector2(-6, 9), c + Vector2(5, -6), ink, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1, -10), c + Vector2(11, -3), c + Vector2(7, 1), c + Vector2(-5, -6)]), ink)
		"tongs":
			draw_line(c + Vector2(-2, 11), c + Vector2(-7, -9), ink, 2.6)
			draw_line(c + Vector2(2, 11), c + Vector2(7, -9), ink, 2.6)
			draw_line(c + Vector2(-7, -9), c + Vector2(-2, -4), ink, 2.6)
			draw_line(c + Vector2(7, -9), c + Vector2(2, -4), ink, 2.6)
			draw_circle(c + Vector2(0, 3), 1.8, ink)
		"bellows":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -8), c + Vector2(5, -8), c + Vector2(8, 4), c + Vector2(-9, 4)]), ink)
			draw_line(c + Vector2(8, -2), c + Vector2(13, -2), ink, 3.0)
			draw_line(c + Vector2(-9, 8), c + Vector2(-2, 4), ink, 2.6)
		"page":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -11), c + Vector2(5, -11), c + Vector2(9, -7), c + Vector2(9, 11), c + Vector2(-8, 11)]), Color("fbf3dc"))
			draw_polyline(PackedVector2Array([c + Vector2(-8, -11), c + Vector2(5, -11), c + Vector2(9, -7), c + Vector2(9, 11), c + Vector2(-8, 11), c + Vector2(-8, -11)]), ink, 1.8)
			for k in 3:
				draw_line(c + Vector2(-5, -4 + k * 5), c + Vector2(6, -4 + k * 5), ink, 1.4)
		_:
			draw_circle(c, 6.0, ink)
	for i in 3:
		var ph := fmod(_t * 0.5 + i * 0.33, 1.0)
		draw_circle(c + Vector2(-10 + i * 10, 12 - ph * 30.0), 1.5, Color(Palette.GOLD, (1.0 - ph) * 0.9))
