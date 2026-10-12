class_name IsoFloor
extends Node2D
## Data + manager for the isometric page. Cell kinds:
##   '.' plains   ',' town (ghost until restored)   '#' plot hole (pit).
## Missing cells are the edge of the page.
##
## Drawing is split into diagonal slices (all cells with the same x+y) that live
## inside the Y-sorted actor layer, so a tall terrace correctly hides whatever
## stands behind it, and characters walk in front of or behind each cliff.

const PLAINS_X_LIMIT := 22            # x >= this is the town (for region labels)

var cells: Dictionary = {}            # Vector2i -> String (kind)
var heights: Dictionary = {}          # Vector2i -> int level (for stairs: the LOW level)
var stairs: Dictionary = {}           # Vector2i -> Vector2i (direction the stairs rise toward)
var focus := Vector2.ZERO             # screen-space point the camera is looking at
var _slices: Array[IsoSlice] = []

func is_pit(cell: Vector2i) -> bool:
	return cells.get(cell, "") == "#"

func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)

func cell_at(p: Vector2) -> Vector2i:
	var g := Iso.to_grid(p)
	return Vector2i(roundi(g.x), roundi(g.y))

func level(cell: Vector2i) -> int:
	return heights.get(cell, 0)

## Elevation (levels) at the center of a cell; stairs report their midpoint.
func height_of(cell: Vector2i) -> float:
	return level(cell) + (0.5 if stairs.has(cell) else 0.0)

## Smooth elevation (levels) under a ground-plane screen position.
func height_at(p: Vector2) -> float:
	var g := Iso.to_grid(p)
	var cell := Vector2i(roundi(g.x), roundi(g.y))
	if stairs.has(cell):
		var u: Vector2i = stairs[cell]
		var t := clampf(0.5 + (g.x - cell.x) * u.x + (g.y - cell.y) * u.y, 0.0, 1.0)
		return level(cell) + t
	return float(level(cell))

## Can you walk from cell a to adjacent cell b without crossing a cliff?
func edge_open(a: Vector2i, b: Vector2i) -> bool:
	var sa := stairs.has(a)
	var sb := stairs.has(b)
	if not sa and not sb:
		return level(a) == level(b)
	if sa and sb:
		var ua: Vector2i = stairs[a]
		if ua != stairs[b]:
			return false
		var d := b - a
		if d == ua:
			return level(b) == level(a) + 1
		if d == -ua:
			return level(a) == level(b) + 1
		return level(a) == level(b)   # side by side: a wide staircase
	var st: Vector2i = a if sa else b
	var other: Vector2i = b if sa else a
	var u: Vector2i = stairs[st]
	var off := other - st
	if off == -u:
		return level(other) == level(st)       # bottom of the stairs
	if off == u:
		return level(other) == level(st) + 1   # top of the stairs
	return false                                # sides of a staircase are walls

func build(parent: Node2D) -> void:
	var by_s := {}
	for cell: Vector2i in cells.keys():
		var s := cell.x + cell.y
		if not by_s.has(s):
			by_s[s] = []
		by_s[s].append(cell)
	for s: int in by_s.keys():
		var sl := IsoSlice.new()
		sl.floor_ref = self
		sl.cells.assign(by_s[s])
		# Sort key just behind actors standing on this diagonal row.
		sl.position = Vector2(0.0, (s - 0.5) * Iso.TILE_H * 0.5)
		parent.add_child(sl)
		_slices.append(sl)

func _process(_delta: float) -> void:
	for sl in _slices:
		sl.queue_redraw()
