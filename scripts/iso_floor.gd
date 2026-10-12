class_name IsoFloor
extends Node2D
## Draws the isometric page: faint drafting-grid diamonds over the parchment,
## and void pits ("plot holes") where the world was never written.
## Only cells near the camera are drawn.

@export var grid_size := 40            # world is grid_size x grid_size tiles
@export var view_radius := 16          # tiles drawn around the focus point

var pits: Dictionary = {}              # Vector2i -> true
var focus := Vector2.ZERO              # screen-space point to draw around

func is_pit(cell: Vector2i) -> bool:
	return pits.has(cell)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var g := Iso.to_grid(focus)
	var cx := int(floor(g.x))
	var cy := int(floor(g.y))
	var ink := Color(0.25, 0.17, 0.1)
	# Back-to-front so pit walls overlap correctly.
	for s in range(cx + cy - view_radius, cx + cy + view_radius + 1):
		for x in range(cx - view_radius, cx + view_radius + 1):
			var y := s - x
			if abs(y - cy) > view_radius:
				continue
			var cell := Vector2i(x, y)
			if not in_bounds(cell):
				continue
			var c := Iso.to_screen(Vector2(x, y))
			if pits.has(cell):
				_draw_pit(c)
				continue
			var d := Iso.diamond(c)
			# Alternate faint tint like ruled paper stock.
			if (x + y) % 2 == 0:
				draw_colored_polygon(d, Color(1, 0.97, 0.85, 0.10))
			var loop := d.duplicate()
			loop.append(d[0])
			draw_polyline(loop, Color(ink, 0.22), 1.2, true)
	_draw_border(ink)

func _draw_pit(c: Vector2) -> void:
	var d := Iso.diamond(c)
	var depth := 14.0
	# Inner walls (left & right faces dropping into the void).
	var l := PackedVector2Array([d[3], d[2], d[2] + Vector2(0, depth), d[3] + Vector2(0, depth)])
	var r := PackedVector2Array([d[2], d[1], d[1] + Vector2(0, depth), d[2] + Vector2(0, depth)])
	draw_colored_polygon(d, Color(0.04, 0.03, 0.08))
	draw_colored_polygon(l, Color(0.32, 0.22, 0.13))
	draw_colored_polygon(r, Color(0.24, 0.16, 0.1))
	var loop := d.duplicate()
	loop.append(d[0])
	draw_polyline(loop, Color(0.1, 0.07, 0.05), 2.0, true)

func _draw_border(ink: Color) -> void:
	var lo := -0.5
	var hi := grid_size - 0.5
	var pts := PackedVector2Array([
		Iso.to_screen(Vector2(lo, lo)), Iso.to_screen(Vector2(hi, lo)),
		Iso.to_screen(Vector2(hi, hi)), Iso.to_screen(Vector2(lo, hi))])
	pts.append(pts[0])
	draw_polyline(pts, Color(ink, 0.8), 3.0, true)
