class_name IsoFloor
extends Node2D
## The isometric page. Cell kinds:  '.' plains   ',' town (ghost until restored)
## '#' plot hole (void pit).  Missing cells are the edge of the page.
## Only cells near `focus` are drawn.

const PLAINS_X_LIMIT := 22            # x >= this is the town (for region labels)

@export var view_radius := 17

var cells: Dictionary = {}            # Vector2i -> String
var focus := Vector2.ZERO             # screen-space point to draw around

func is_pit(cell: Vector2i) -> bool:
	return cells.get(cell, "") == "#"

func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)

func cell_at(p: Vector2) -> Vector2i:
	var g := Iso.to_grid(p)
	return Vector2i(roundi(g.x), roundi(g.y))

func _process(_delta: float) -> void:
	queue_redraw()

static func _h(x: int, y: int, k: int = 0) -> float:
	return fposmod(sin(float(x) * 127.1 + float(y) * 311.7 + float(k) * 74.7) * 43758.5453, 1.0)

func _draw() -> void:
	var g := Iso.to_grid(focus)
	var cx := int(floor(g.x))
	var cy := int(floor(g.y))
	# Back-to-front by (x + y) so cliff faces and pit walls overlap correctly.
	for s in range(cx + cy - view_radius, cx + cy + view_radius + 1):
		for x in range(cx - view_radius, cx + view_radius + 1):
			var y := s - x
			if abs(y - cy) > view_radius:
				continue
			var cell := Vector2i(x, y)
			if not cells.has(cell):
				continue
			var c := Iso.to_screen(Vector2(x, y))
			var kind: String = cells[cell]
			if kind == "#":
				_draw_pit(c)
			else:
				_draw_tile(cell, c, kind)
				_draw_page_edges(cell, c)

func _draw_tile(cell: Vector2i, c: Vector2, kind: String) -> void:
	var d := Iso.diamond(c)
	var r := 1.0
	if kind == ",":
		r = GameState.restored_at(c)
	var line_col := Palette.PENCIL.lerp(Palette.INK_BROWN, r)
	var checker := (cell.x + cell.y) % 2 == 0
	if kind == ".":
		draw_colored_polygon(d, Color(Palette.GRASS, 0.34 if checker else 0.26))
	else:
		# Town: bare page, then warm cobbles as the ink flows back.
		if r > 0.0:
			draw_colored_polygon(d, Color(Palette.COBBLE, (0.30 if checker else 0.20) * r))
		elif checker:
			draw_colored_polygon(d, Color(1, 1, 1, 0.07))
	var loop := d.duplicate()
	loop.append(d[0])
	draw_polyline(loop, Color(line_col, 0.20 + 0.10 * (1.0 - r)), 1.2, true)
	if kind == ".":
		_draw_grass(cell, c)
	elif r > 0.4:
		_draw_flowers(cell, c, r)

func _draw_grass(cell: Vector2i, c: Vector2) -> void:
	if _h(cell.x, cell.y) > 0.62:
		return
	for i in 3:
		var o := Vector2((_h(cell.x, cell.y, i + 1) - 0.5) * 36.0, (_h(cell.x, cell.y, i + 5) - 0.5) * 14.0)
		var p := c + o
		var lean := (_h(cell.x, cell.y, i + 9) - 0.5) * 4.0
		draw_line(p, p + Vector2(lean - 2.0, -6.0), Palette.GRASS_DARK, 1.5, true)
		draw_line(p, p + Vector2(lean + 2.0, -5.0), Palette.GRASS_DARK, 1.5, true)
		draw_line(p, p + Vector2(lean, -8.0), Palette.GRASS_DARK, 1.5, true)

func _draw_flowers(cell: Vector2i, c: Vector2, r: float) -> void:
	if _h(cell.x, cell.y, 20) > 0.18:
		return
	var p := c + Vector2((_h(cell.x, cell.y, 21) - 0.5) * 30.0, (_h(cell.x, cell.y, 22) - 0.5) * 12.0)
	var cols := [Color("e8738c"), Color("f2c14e"), Color("8fb8e8")]
	var col: Color = cols[int(_h(cell.x, cell.y, 23) * 3.0) % 3]
	draw_line(p, p + Vector2(0, -6), Palette.GRASS_DARK, 1.4)
	draw_circle(p + Vector2(0, -7), 2.4, Color(col, r))

# The page is a physical sheet: show its stacked-paper edge where the world ends.
func _draw_page_edges(cell: Vector2i, c: Vector2) -> void:
	var d := Iso.diamond(c)
	var depth := 16.0
	if not cells.has(cell + Vector2i(0, 1)):
		_edge_face(d[3], d[2], depth)
	if not cells.has(cell + Vector2i(1, 0)):
		_edge_face(d[2], d[1], depth)

func _edge_face(a: Vector2, b: Vector2, depth: float) -> void:
	var q := PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)])
	draw_colored_polygon(q, Color(0.93, 0.86, 0.68))
	for i in range(1, 4):
		var o := Vector2(0, depth * i / 4.0)
		draw_line(a + o, b + o, Color(Palette.INK_BROWN, 0.35), 1.0, true)
	draw_line(a, b, Palette.INK_BROWN, 2.0, true)
	draw_line(a + Vector2(0, depth), b + Vector2(0, depth), Palette.INK_BROWN, 2.0, true)

func _draw_pit(c: Vector2) -> void:
	var d := Iso.diamond(c)
	var depth := 16.0
	var l := PackedVector2Array([d[3], d[2], d[2] + Vector2(0, depth), d[3] + Vector2(0, depth)])
	var r := PackedVector2Array([d[2], d[1], d[1] + Vector2(0, depth), d[2] + Vector2(0, depth)])
	draw_colored_polygon(d, Color(0.04, 0.03, 0.08))
	draw_colored_polygon(l, Color(0.34, 0.24, 0.14))
	draw_colored_polygon(r, Color(0.25, 0.17, 0.1))
	# Faint swirl of the Unwritten at the bottom, and a ragged torn lip.
	draw_arc(c + Vector2(0, 3), 7.0, _t_angle(), _t_angle() + 4.0, 12, Color(0.55, 0.5, 0.8, 0.35), 1.4, true)
	var loop := d.duplicate()
	loop.append(d[0])
	draw_polyline(loop, Palette.INK, 2.0, true)

func _t_angle() -> float:
	return Time.get_ticks_msec() / 900.0
