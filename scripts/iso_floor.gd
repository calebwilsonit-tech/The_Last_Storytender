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
var blockers: Dictionary = {}          # Vector2i -> true: trees, houses, crates (block line of sight)
var block_cells: Dictionary = {}       # Vector2i -> TextBlock occupying it
var marks: Dictionary = {}             # Vector2i -> {"kind": "crack"|"flower", "t": float}
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

## Line of sight between two ground-plane positions: blocked by void, solid scenery
## (trees, houses), and terrain higher than both ends (a cliff or terrace between).
func has_los(a: Vector2, b: Vector2) -> bool:
	var ga := Iso.to_grid(a)
	var gb := Iso.to_grid(b)
	var d := gb - ga
	var n := int(d.length() / 0.35) + 1
	var start := Vector2i(roundi(ga.x), roundi(ga.y))
	var end := Vector2i(roundi(gb.x), roundi(gb.y))
	var top := maxf(height_at(a), height_at(b)) + 0.5
	var prev := start
	for i in range(1, n):
		var g := ga + d * (float(i) / n)
		var c := Vector2i(roundi(g.x), roundi(g.y))
		if c == prev:
			continue
		prev = c
		if not cells.has(c):
			return false
		if c != start and c != end and blockers.has(c):
			return false
		if height_at(Iso.to_screen(g)) > top:
			return false
	return true

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
	# Two nodes per diagonal row, because actors are sorted among them by their y position:
	#  - the GROUND node paints flat tops very early, so a tile can never paint over the feet or
	#    shadow of anything standing near it (which flickered as you crossed a tile edge);
	#  - the EDGE node sits just behind actors on this row and paints what can really hide them:
	#    cliff faces, stairs, plot holes, and the tops of ground that is higher than what lies behind.
	_by_s = by_s
	for s: int in by_s.keys():
		var diag_y: float = (s - 0.5) * Iso.TILE_H * 0.5
		for m in [IsoSlice.GROUND, IsoSlice.EDGE]:
			var sl := IsoSlice.new()
			sl.floor_ref = self
			sl.mode = m
			sl.cells.assign(by_s[s])
			sl.diag_y = diag_y
			sl.position = Vector2(0.0, diag_y)
			# Draw order comes from z_index, not from y: everything is ordered by which diagonal
			# row of cells it belongs to, so nothing flips as you cross a cell.
			#   flat ground tops  z = -2000 + s     (always behind every actor)
			#   walls/stairs/holes z = 3s            (behind actors on this row, in front of the row behind)
			#   actors             z = 3s + 1        (set each frame by LevelBase)
			sl.z_index = (3 * s) if m == IsoSlice.EDGE else (-2000 + s)
			parent.add_child(sl)
			_slices.append(sl)
			if m == IsoSlice.EDGE:
				_edge_nodes[s] = sl
				_edge_parent = parent

## True when the ground behind this cell (toward -x or -y) is lower: the cell's own far-side
## wall faces away from the camera, and the cell hides whatever stands below it.
func back_lower(cell: Vector2i) -> bool:
	var lv := level(cell)
	for n in [cell + Vector2i(0, -1), cell + Vector2i(-1, 0)]:
		if cells.has(n) and not stairs.has(n) and level(n) < lv:
			return true
	return false

## The ground is expensive to draw, so it only repaints when something changed: the camera
## moved a little, a mark is animating, a restoration wave is spreading, or a quarter of a
## second has passed. Diagonal rows far above or below the camera are switched off entirely.
var dirty := false
var fade_cells: Dictionary = {}          # cells currently hiding the player (drawn see-through)
var _edge_nodes: Dictionary = {}         # diagonal sum -> its EDGE slice
var _fade_nodes: Dictionary = {}         # diagonal sum -> its FADE slice (made on demand)
var _by_s: Dictionary = {}
var _edge_parent: Node2D
const FADE_ALPHA := 0.4
var _drawn_focus := Vector2(1e9, 1e9)
var _idle := 0.0
var _had_marks := false

func _process(delta: float) -> void:
	for c in marks.keys():
		marks[c]["t"] = float(marks[c]["t"]) + delta
	_idle += delta
	var animated := not marks.is_empty() or _had_marks or GameState.restore_active()
	_had_marks = not marks.is_empty()
	var moved := focus.distance_to(_drawn_focus) > Settings.ground_move_threshold()
	if not (animated or moved or dirty or _idle > Settings.ground_idle_interval()):
		return
	if moved:
		_drawn_focus = focus
	_idle = 0.0
	dirty = false
	for sl in _slices:
		var near := absf(sl.diag_y - focus.y) < Settings.cull_half().y + 190.0
		if near:
			sl.visible = true
			sl.queue_redraw()
		elif sl.visible:
			sl.visible = false

## Cells that are in front of the player and taller than where they stand are drawn see-through,
## so the player is never lost behind a cliff. Pass an empty list to turn it off.
func set_fade(list: Array) -> void:
	var now := {}
	for c in list:
		now[c] = true
	if now.size() == fade_cells.size():
		var same := true
		for c in now.keys():
			if not fade_cells.has(c):
				same = false
				break
		if same:
			return
	var touched := {}
	for c in fade_cells.keys():
		touched[c.x + c.y] = true
	for c in now.keys():
		touched[c.x + c.y] = true
	fade_cells = now
	for s in touched.keys():
		if _edge_nodes.has(s):
			_edge_nodes[s].queue_redraw()
		var want := false
		for c in now.keys():
			if c.x + c.y == s:
				want = true
				break
		if want and not _fade_nodes.has(s) and _edge_parent != null and _by_s.has(s):
			var fn := IsoSlice.new()
			fn.floor_ref = self
			fn.mode = IsoSlice.FADE
			fn.cells.assign(_by_s[s])
			fn.diag_y = (s - 0.5) * Iso.TILE_H * 0.5
			fn.position = Vector2(0.0, fn.diag_y)
			fn.z_index = 3 * s
			fn.modulate.a = FADE_ALPHA
			_edge_parent.add_child(fn)
			_fade_nodes[s] = fn
		if _fade_nodes.has(s):
			_fade_nodes[s].visible = want
			_fade_nodes[s].queue_redraw()
