class_name IsoSlice
extends Node2D
## One diagonal row of the isometric page (cells sharing x + y). Draws tiles at
## their elevation, stacked-paper cliff faces, stairs, and plot holes.

var floor_ref: IsoFloor
var cells: Array[Vector2i] = []

static func _h(x: int, y: int, k: int = 0) -> float:
	return fposmod(sin(float(x) * 127.1 + float(y) * 311.7 + float(k) * 74.7) * 43758.5453, 1.0)

# Slice-local screen position of a grid point at elevation z.
func _p(c: Vector2, z: float) -> Vector2:
	return Iso.pt(c, z) - position

func _quad(cell: Vector2i, z: float) -> PackedVector2Array:
	var c := Vector2(cell)
	return PackedVector2Array([
		_p(c + Vector2(-0.5, -0.5), z), _p(c + Vector2(0.5, -0.5), z),
		_p(c + Vector2(0.5, 0.5), z), _p(c + Vector2(-0.5, 0.5), z)])

func _restoration(cell: Vector2i, kind: String) -> float:
	if kind != ",":
		return 1.0
	return GameState.restored_at(Iso.to_screen(Vector2(cell)))

func _draw() -> void:
	var f := floor_ref.focus
	for cell in cells:
		var kind: String = floor_ref.cells[cell]
		var z := float(floor_ref.level(cell))
		var gp := Iso.pt(Vector2(cell), z)
		if absf(gp.x - f.x) > 800.0 or absf(gp.y - f.y) > 560.0:
			continue
		if floor_ref.stairs.has(cell):
			_draw_stairs(cell, kind)
		elif kind == "#":
			_draw_pit(cell, z)
		else:
			_draw_tile(cell, kind, z)
			_draw_faces(cell, kind, z)

func _draw_tile(cell: Vector2i, kind: String, z: float) -> void:
	var d := _quad(cell, z)
	var r := _restoration(cell, kind)
	var line_col := Palette.PENCIL.lerp(Palette.INK_BROWN, r)
	var checker := (cell.x + cell.y) % 2 == 0
	if kind == "p" or kind == "b":
		_draw_page(cell, d, kind, checker)
		_draw_mark(cell, z)
		return
	if kind == "m":
		# Memory floor: cold slate with faint cyan seams, frozen embers hanging above.
		draw_colored_polygon(d, Color("46566e") if checker else Color("3e4d64"))
		var ml := d.duplicate()
		ml.append(d[0])
		draw_polyline(ml, Color(Palette.CYAN, 0.22), 1.4, true)
		if _h(cell.x, cell.y, 40) > 0.82:
			var q := _p(Vector2(cell), z) + Vector2((_h(cell.x, cell.y, 41) - 0.5) * 30.0, (_h(cell.x, cell.y, 42) - 0.5) * 12.0 - 20.0)
			draw_circle(q, 5.0, Color(Palette.CYAN, 0.10))
			draw_circle(q, 1.6, Color("ffb347", 0.95))
		return
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
	var c := _p(Vector2(cell), z)
	if kind == ".":
		_draw_grass(cell, c)
	elif r > 0.4:
		_draw_flowers(cell, c, r)

# Pip's storybook: floor tiles are printed pages (and, once rewritten, wooden bridge planks).
func _draw_page(cell: Vector2i, d: PackedVector2Array, kind: String, checker: bool) -> void:
	if kind == "b":
		draw_colored_polygon(d, Color("a8774a") if checker else Color("98683e"))
		for i in 1:
			draw_line(d[0].lerp(d[3], 0.5), d[1].lerp(d[2], 0.5), Color(0, 0, 0, 0.35), 2.0)
		var l := d.duplicate()
		l.append(d[0])
		draw_polyline(l, Palette.OUTLINE, 2.4, true)
		return
	draw_colored_polygon(d, Palette.PAGE if checker else Palette.PAGE_SHADE)
	# Printed lines of text running across the page.
	for k in 3:
		var t := 0.25 + k * 0.25
		var a := d[0].lerp(d[3], t).lerp(d[1].lerp(d[2], t), 0.12)
		var b := d[0].lerp(d[3], t).lerp(d[1].lerp(d[2], t), 0.88)
		draw_line(a, b, Color(Palette.INK_BROWN, 0.20), 1.6)
	var loop := d.duplicate()
	loop.append(d[0])
	draw_polyline(loop, Color(Palette.INK_BROWN, 0.35), 1.4, true)

func _draw_mark(cell: Vector2i, z: float) -> void:
	if not floor_ref.marks.has(cell):
		return
	var m: Dictionary = floor_ref.marks[cell]
	var c := _p(Vector2(cell), z)
	var t: float = m["t"]
	if m["kind"] == "crack":
		var a := 0.55 + 0.35 * sin(t * 12.0)
		for seg in [[Vector2(-14, -3), Vector2(-2, 2)], [Vector2(-2, 2), Vector2(8, -4)], [Vector2(8, -4), Vector2(15, 3)], [Vector2(-2, 2), Vector2(2, 9)]]:
			draw_line(c + seg[0], c + seg[1], Color("ff5a3c", a), 2.4)
		draw_colored_polygon(_quad(cell, z), Color(1.0, 0.35, 0.2, 0.10 + 0.08 * sin(t * 12.0)))
	elif m["kind"] == "ink":
		var pulse := 0.8 + 0.2 * sin(t * 6.0)
		draw_colored_polygon(_quad(cell, z), Color(Palette.CRITIC_RED, 0.55 * pulse))
		for i in 4:
			var o := Vector2(-16 + i * 10.0, sin(t * 3.0 + i) * 4.0)
			draw_circle(c + o, 3.0 + sin(t * 4.0 + i), Color(Palette.CRITIC_DARK, 0.9))
	elif m["kind"] == "flower":
		for i in 5:
			var o := Vector2(-18 + i * 9.0, (i % 2) * 6.0 - 3.0)
			draw_line(c + o, c + o + Vector2(0, -7), Palette.GRASS_DARK, 1.6)
			var col := Color("f08aa3") if i % 2 == 0 else Color("ffe08a")
			draw_circle(c + o + Vector2(0, -9), 3.0 + 0.6 * sin(t * 3.0 + i), col)

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

# Cliff faces on the two viewer-facing edges (+y and +x) wherever the ground
# drops, or the page ends.
func _draw_faces(cell: Vector2i, kind: String, z: float) -> void:
	var c := Vector2(cell)
	for side in 2:
		var n := cell + (Vector2i(0, 1) if side == 0 else Vector2i(1, 0))
		var zb := 0.0
		var void_edge := false
		if not floor_ref.cells.has(n):
			void_edge = true
			zb = -16.0 / Iso.LEVEL_H           # a sliver of page thickness below level 0
		elif floor_ref.stairs.has(n):
			continue
		else:
			zb = float(floor_ref.level(n))
			if zb >= z:
				continue
		var a: Vector2
		var b: Vector2
		if side == 0:
			a = _p(c + Vector2(-0.5, 0.5), z)
			b = _p(c + Vector2(0.5, 0.5), z)
		else:
			a = _p(c + Vector2(0.5, 0.5), z)
			b = _p(c + Vector2(0.5, -0.5), z)
		_cliff(a, b, (z - zb) * Iso.LEVEL_H, kind, side, void_edge, _restoration(cell, kind))

func _cliff(a: Vector2, b: Vector2, depth: float, kind: String, side: int, void_edge: bool, r: float) -> void:
	var q := PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)])
	var base := Color(0.93, 0.86, 0.68)             # stacked pages at the world's edge
	if not void_edge:
		base = Color("a98458") if kind == "." else (Color("34415a") if kind == "m" else (Color("e8d9b4") if kind == "p" or kind == "b" else Color("cbb28a")))
	if side == 1:
		base = base.darkened(0.18)
	if kind == "," and not void_edge:
		base = Palette.ghostify(base, r).lerp(Palette.PAPER_LIGHT, (1.0 - r) * 0.55)
	draw_colored_polygon(q, base)
	var edge := Palette.INK_BROWN if (void_edge or r > 0.5) else Palette.PENCIL
	# Strata: horizontal page-edge / soil lines.
	var i := 1
	while i * 7.0 < depth:
		var o := Vector2(0, i * 7.0)
		draw_line(a + o, b + o, Color(edge, 0.30), 1.0, true)
		i += 1
	if kind == "." and not void_edge:
		var lip := PackedVector2Array([a, b, b + Vector2(0, 6), a + Vector2(0, 6)])
		draw_colored_polygon(lip, Color(Palette.GRASS_DARK, 0.85))
	draw_line(a, a + Vector2(0, depth), edge, 2.0, true)
	draw_line(b, b + Vector2(0, depth), edge, 2.0, true)
	draw_line(a + Vector2(0, depth), b + Vector2(0, depth), edge, 2.0, true)
	draw_line(a, b, edge, 2.0, true)

# --- Stairs ---------------------------------------------------------------------
func _draw_stairs(cell: Vector2i, kind: String) -> void:
	var u: Vector2i = floor_ref.stairs[cell]
	var base := float(floor_ref.level(cell))
	var r := _restoration(cell, kind)
	var col := Palette.ghostify(Color("d9c298"), r).lerp(Palette.PAPER_LIGHT, (1.0 - r) * 0.5)
	var edge := Palette.PENCIL.lerp(Palette.INK_BROWN, r)
	var n := 4
	var positive := (u.x + u.y) > 0
	# Draw back-to-front so nearer steps overlap farther ones.
	var order: Array = range(n) if positive else range(n - 1, -1, -1)
	var c := Vector2(cell)
	for i: int in order:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var lo := -0.5 + t0 if positive else 0.5 - t1
		var hi := -0.5 + t1 if positive else 0.5 - t0
		var x0 := -0.5
		var x1 := 0.5
		var y0 := -0.5
		var y1 := 0.5
		if u.x != 0:
			x0 = lo
			x1 = hi
		else:
			y0 = lo
			y1 = hi
		_box(c, x0, y0, x1, y1, base, base + float(i + 1) / n, col, edge)

func _box(c: Vector2, x0: float, y0: float, x1: float, y1: float, zb: float, zt: float, col: Color, edge: Color) -> void:
	var n_ := _p(c + Vector2(x0, y0), zt)
	var e_ := _p(c + Vector2(x1, y0), zt)
	var s_ := _p(c + Vector2(x1, y1), zt)
	var w_ := _p(c + Vector2(x0, y1), zt)
	var depth := (zt - zb) * Iso.LEVEL_H
	var left := PackedVector2Array([w_, s_, s_ + Vector2(0, depth), w_ + Vector2(0, depth)])
	var right := PackedVector2Array([s_, e_, e_ + Vector2(0, depth), s_ + Vector2(0, depth)])
	var top := PackedVector2Array([n_, e_, s_, w_])
	draw_colored_polygon(left, col.darkened(0.12))
	draw_colored_polygon(right, col.darkened(0.28))
	draw_colored_polygon(top, col.lightened(0.06))
	for poly in [left, right, top]:
		var loop: PackedVector2Array = poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, Color(edge, 0.9), 1.6, true)

# --- Plot holes -----------------------------------------------------------------
func _draw_pit(cell: Vector2i, z: float) -> void:
	var d := _quad(cell, z)
	var c := _p(Vector2(cell), z)
	var depth := 16.0
	var l := PackedVector2Array([d[3], d[2], d[2] + Vector2(0, depth), d[3] + Vector2(0, depth)])
	var rr := PackedVector2Array([d[2], d[1], d[1] + Vector2(0, depth), d[2] + Vector2(0, depth)])
	draw_colored_polygon(d, Color(0.04, 0.03, 0.08))
	draw_colored_polygon(l, Color(0.34, 0.24, 0.14))
	draw_colored_polygon(rr, Color(0.25, 0.17, 0.1))
	var ang := Time.get_ticks_msec() / 900.0
	draw_arc(c + Vector2(0, 3), 7.0, ang, ang + 4.0, 12, Color(0.55, 0.5, 0.8, 0.35), 1.4, true)
	var loop := d.duplicate()
	loop.append(d[0])
	draw_polyline(loop, Palette.INK, 2.0, true)
