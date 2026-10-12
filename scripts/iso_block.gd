class_name IsoBlock
extends StaticBody2D
## A stacked-books style cube sitting on one tile. Position = base center of
## the tile, so Y-sorting puts the player correctly in front of / behind it.

@export var height := 36.0
@export var tint := Color(0.55, 0.3, 0.2)

func _ready() -> void:
	var cs := CollisionPolygon2D.new()
	cs.polygon = Iso.diamond(Vector2.ZERO, 0.9)
	add_child(cs)

func _draw() -> void:
	var d := Iso.diamond(Vector2.ZERO, 0.9)
	var up := Vector2(0, -height)
	var top := PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up])
	var left := PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up])
	var right := PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up])
	var ink := Color(0.12, 0.08, 0.06)
	draw_colored_polygon(left, tint.darkened(0.25))
	draw_colored_polygon(right, tint.darkened(0.45))
	draw_colored_polygon(top, tint.lightened(0.15))
	# Page-edge lines on the sides, like a stack of books.
	for i in range(1, int(height / 9.0)):
		var o := Vector2(0, -i * 9.0)
		draw_line(d[3] + o, d[2] + o, Color(1, 0.95, 0.8, 0.35), 1.0)
		draw_line(d[2] + o, d[1] + o, Color(1, 0.95, 0.8, 0.2), 1.0)
	for poly in [top, left, right]:
		var loop: PackedVector2Array = poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, ink, 2.0, true)
