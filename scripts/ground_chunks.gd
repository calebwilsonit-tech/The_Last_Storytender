class_name GroundChunks
extends Node2D
## Cached ground. The overworld's ground never changes (except while a restoration wave spreads),
## so instead of issuing thousands of drawing commands every frame, each 16 x 16 block of cells is
## painted once into a texture and shown as a single image. Only blocks near the camera exist.
## Cliff faces, stairs and holes stay dynamic (they have to be depth-sorted against people).

const CS := 16                       # cells per side of a chunk
const MAX_LIFT := 150.0              # room above a chunk for raised ground
const KEEP := 22                     # most chunks kept in memory at once

var floor_ref: IsoFloor
var _cells_by_chunk: Dictionary = {}
var _chunks: Dictionary = {}         # Vector2i -> {vp, painter, sprite, last, town}
var _restore_was := false
var _tick := 0

func _ready() -> void:
	# A cached chunk was painted with the settings of its day, so repaint all of them when they change.
	Settings.quality_changed.connect(repaint_all)

func setup(f: IsoFloor) -> void:
	floor_ref = f
	for cell: Vector2i in f.cells.keys():
		var ck := Vector2i(floori(cell.x / float(CS)), floori(cell.y / float(CS)))
		if not _cells_by_chunk.has(ck):
			_cells_by_chunk[ck] = []
		_cells_by_chunk[ck].append(cell)

func chunk_rect(ck: Vector2i) -> Rect2:
	var x0 := ck.x * CS
	var y0 := ck.y * CS
	var left := (x0 - (y0 + CS) - 1) * 32.0
	var right := ((x0 + CS) - y0 + 1) * 32.0
	var top := (x0 + y0 - 1) * 16.0 - MAX_LIFT
	var bottom := ((x0 + CS) + (y0 + CS) + 1) * 16.0 + 10.0
	return Rect2(Vector2(floorf(left), floorf(top)), Vector2(ceilf(right - left), ceilf(bottom - top)))

func _process(_delta: float) -> void:
	if floor_ref == null:
		return
	_tick += 1
	var focus := floor_ref.focus
	var view := Rect2(focus - Vector2(1000, 650), Vector2(2000, 1300))
	# 1) which chunks are wanted: those near the camera
	var wanted: Array[Vector2i] = []
	for ck: Vector2i in _cells_by_chunk.keys():
		if chunk_rect(ck).intersects(view):
			wanted.append(ck)
	# 2) paint at most one missing chunk per frame, nearest first
	var missing: Array[Vector2i] = []
	for ck in wanted:
		if not _chunks.has(ck):
			missing.append(ck)
		else:
			_chunks[ck]["last"] = _tick
	if not missing.is_empty():
		missing.sort_custom(func(a: Vector2i, b: Vector2i): return chunk_rect(a).get_center().distance_to(focus) < chunk_rect(b).get_center().distance_to(focus))
		_make(missing[0])
	# 3) while the ink is spreading, repaint the town chunks that are on screen
	var active := GameState.restore_active()
	if active or _restore_was:
		var n := 0
		for ck: Vector2i in _chunks.keys():
			if _chunks[ck]["town"] and chunk_rect(ck).intersects(view) and n < 3:
				_repaint(ck)
				n += 1
	_restore_was = active
	# 4) forget chunks that are far behind
	if _chunks.size() > KEEP:
		var old: Array = _chunks.keys()
		old.sort_custom(func(a: Vector2i, b: Vector2i): return int(_chunks[a]["last"]) < int(_chunks[b]["last"]))
		for ck: Vector2i in old.slice(0, _chunks.size() - KEEP):
			if not wanted.has(ck):
				_free(ck)

func _make(ck: Vector2i) -> void:
	var rect := chunk_rect(ck)
	var vp := SubViewport.new()
	vp.size = Vector2i(rect.size)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := IsoSlice.new()
	painter.floor_ref = floor_ref
	painter.mode = IsoSlice.CHUNK
	painter.cells.assign(_cells_by_chunk[ck])
	painter.origin = rect.position
	painter.uncull = true
	vp.add_child(painter)
	add_child(vp)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = vp.get_texture()
	spr.position = rect.position
	spr.z_index = -2100
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(spr)
	var town := false
	for c: Vector2i in _cells_by_chunk[ck]:
		if floor_ref.cells[c] == ",":
			town = true
			break
	_chunks[ck] = {"vp": vp, "painter": painter, "sprite": spr, "last": _tick, "town": town}

func _repaint(ck: Vector2i) -> void:
	var c: Dictionary = _chunks[ck]
	(c["painter"] as IsoSlice).queue_redraw()
	(c["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

## Repaints just the chunk that holds this cell (a bridge unrolled, a causeway page crumbled).
func repaint_cell(cell: Vector2i) -> void:
	var ck := Vector2i(floori(cell.x / float(CS)), floori(cell.y / float(CS)))
	if _chunks.has(ck):
		_repaint(ck)

func repaint_all() -> void:
	for ck: Vector2i in _chunks.keys():
		_repaint(ck)

func _free(ck: Vector2i) -> void:
	var c: Dictionary = _chunks[ck]
	(c["sprite"] as Sprite2D).queue_free()
	(c["vp"] as SubViewport).queue_free()
	_chunks.erase(ck)

func chunk_count() -> int:
	return _chunks.size()
