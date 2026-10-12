class_name PasteGhost
extends Node2D
## The preview of where a held clipping will land (green = valid, red = not).

var cells: Array[Vector2i] = []
var valid := true

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	for c in cells:
		var d := Iso.diamond(Iso.to_screen(Vector2(c)) - position, 0.94)
		var col := Color(0.4, 1.0, 0.5, 0.35) if valid else Color(1.0, 0.3, 0.3, 0.35)
		draw_colored_polygon(d, col)
		var loop := d.duplicate()
		loop.append(d[0])
		draw_polyline(loop, Color(col, 0.95), 3.0, true)
