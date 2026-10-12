class_name TextBlock
extends StaticBody2D
## A word with weight. Strike it with the Quill after choosing a style (keys 1/2/3):
##   UNDERLINE  the word becomes walkable, and any plot hole beneath it becomes a bridge
##   BOLD       the word becomes heavy: it can press a pressure plate
##   ITALIC     the word leans and slides along its slant until something stops it
##              (a wall, another block, you); a block that slides into a plot hole plugs it
## Rising dough (rise_time > 0) cannot be rushed: strike it early and it collapses.
## Hold the Lantern's warmth on it to help it rise.

signal changed(block: TextBlock)
signal slid(block: TextBlock)
signal burned(block: TextBlock)
signal ready_to_use(block: TextBlock)

var word := ""
var cell := Vector2i.ZERO            # first cell along `axis`
var axis := Vector2i(1, 0)
var length := 1
var lean := Vector2i(1, 0)           # the way an italic block slides (grid direction)
var underline := false
var bold := false
var italic := false
var floor_ref: IsoFloor
var elev := 0.0
var rise_time := 0.0                 # > 0 makes this rising dough
var player_cell: Callable            # () -> Vector2i: a sliding block stops before you
var hit_r := 30.0

var _rise := 1.0
var _max_len := 1
var _t := 0.0
var _flash := 0.0
var _burn_flash := 0.0
var _warm := 0.0
var _sliding := false
var _slide_timer := 0.0
var _plugged: Array[Vector2i] = []
var _consumed := false               # slid into a hole and became part of the floor
var _poly: CollisionPolygon2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _move_t := 1.0

func _ready() -> void:
	_max_len = length
	if rise_time > 0.0:
		_rise = 0.0
		length = 1
		add_to_group("lightable")
	_poly = CollisionPolygon2D.new()
	add_child(_poly)
	add_to_group("hittables")
	_register()
	position = _center()
	_from = position
	_to = position
	_update_collision()

func _cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in length:
		out.append(cell + axis * i)
	return out

func _center() -> Vector2:
	return Iso.to_screen(Vector2(cell) + Vector2(axis) * (length - 1) * 0.5)

func _register() -> void:
	for c in _cells():
		floor_ref.block_cells[c] = self

func _unregister() -> void:
	for c in _cells():
		if floor_ref.block_cells.get(c) == self:
			floor_ref.block_cells.erase(c)

func weight() -> int:
	return 2 if bold else 1

func _update_collision() -> void:
	var a := Vector2(axis)
	var n := Vector2(-a.y, a.x)
	var h := length * 0.5 - 0.08
	_poly.polygon = PackedVector2Array([
		Iso.to_screen(a * -h + n * -0.38), Iso.to_screen(a * h + n * -0.38),
		Iso.to_screen(a * h + n * 0.38), Iso.to_screen(a * -h + n * 0.38)])
	_poly.set_deferred("disabled", underline or _consumed)

func _apply_underline(on: bool) -> void:
	if on:
		for c in _cells():
			if floor_ref.cells.get(c, "") == "#":
				floor_ref.cells[c] = "b"
				_plugged.append(c)
	else:
		for c in _plugged:
			floor_ref.cells[c] = "#"
		_plugged.clear()

## Called by the Quill.
func hurt(_dmg: float = 0.0, _dir: Vector2 = Vector2.ZERO) -> void:
	if _sliding or _consumed:
		return
	if rise_time > 0.0 and _rise < 1.0:
		burn()
		return
	_flash = 0.5
	match GameState.format_style:
		"underline":
			underline = not underline
			_apply_underline(underline)
		"bold":
			bold = not bold
		"italic":
			italic = true
			_sliding = true
			_slide_timer = 0.0
	_update_collision()
	changed.emit(self)

func burn() -> void:
	_unregister()
	_apply_underline(false)
	underline = false
	_rise = 0.0
	length = 1
	_register()
	_update_collision()
	_burn_flash = 1.0
	burned.emit(self)

## The Lantern's warmth helps dough rise (but it can still not be rushed completely).
func lit(delta: float) -> void:
	if rise_time > 0.0 and _rise < 1.0:
		_warm = 0.3
		_rise = minf(_rise + delta * 2.5 / rise_time, 1.0)

func is_risen() -> bool:
	return rise_time <= 0.0 or _rise >= 1.0

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_burn_flash = maxf(_burn_flash - delta, 0.0)
	_warm = maxf(_warm - delta, 0.0)
	if rise_time > 0.0 and _rise < 1.0:
		var was := _rise
		_rise = minf(_rise + delta / rise_time, 1.0)
		var nl := 1 + int(_rise * (_max_len - 0.001))
		if _rise >= 1.0:
			nl = _max_len
		if nl != length:
			_unregister()
			length = nl
			_register()
			_update_collision()
			_move_to_center()
		if was < 1.0 and _rise >= 1.0:
			_flash = 1.0
			ready_to_use.emit(self)
	if _sliding:
		_slide_timer += delta
		if _slide_timer >= 0.16:
			_slide_timer = 0.0
			_slide_step()
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta / 0.16, 1.0)
		position = _from.lerp(_to, _move_t)
	queue_redraw()

func _move_to_center() -> void:
	_from = position
	_to = _center()
	_move_t = 0.0

func _end_slide() -> void:
	_sliding = false
	italic = false
	_update_collision()
	slid.emit(self)

func _slide_step() -> void:
	var cur := _cells()
	var entering: Array[Vector2i] = []
	for c in cur:
		var nc := c + lean
		if not cur.has(nc):
			entering.append(nc)
	var falls := false
	for nc in entering:
		if not floor_ref.cells.has(nc):
			_end_slide()
			return
		if floor_ref.block_cells.has(nc) and floor_ref.block_cells[nc] != self:
			_end_slide()
			return
		if floor_ref.blockers.has(nc):
			_end_slide()
			return
		if player_cell.is_valid() and player_cell.call() == nc:
			_end_slide()
			return
		if not floor_ref.edge_open(nc - lean, nc):
			_end_slide()
			return
		if floor_ref.cells[nc] == "#":
			falls = true
	_unregister()
	cell += lean
	_register()
	_move_to_center()
	if falls:
		# It tips into the hole and plugs it for good.
		for nc in entering:
			if floor_ref.cells[nc] == "#":
				floor_ref.cells[nc] = "b"
		_consumed = true
		_unregister()
		_sliding = false
		italic = false
		_update_collision()
		slid.emit(self)

# --- Drawing -------------------------------------------------------------------------------------
func _draw() -> void:
	var font := ThemeDB.get_default_theme().default_font
	var a := Vector2(axis)
	var is_dough := rise_time > 0.0
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if not _consumed:
		for i in length:
			var off := Iso.to_screen(a * (i - (length - 1) * 0.5))
			if is_dough:
				_draw_dough_cell(off)
			elif not underline:
				_draw_tablet(off)
	var sz := 30
	var wd := word if not is_dough else ("DOUGH" if _rise >= 1.0 else "dough")
	var tw := font.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var base := Vector2(-tw * 0.5, -34.0 - (6.0 if bold else 0.0) + sin(_t * 2.0) * 1.5)
	if _consumed:
		base.y = -8.0
	var tint := Palette.INK
	if _burn_flash > 0.0:
		tint = Palette.CRITIC_RED
	elif _flash > 0.0:
		tint = Color(0.1, 0.4, 0.6)
	# Italic: shear the text. Bold: stack offset copies for weight.
	if italic or (_sliding):
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.35, 1), Vector2(0, -elev)))
	if bold:
		for dx in [-1.0, 0.0, 1.0]:
			draw_string(font, base + Vector2(dx, 0), wd, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, tint)
	draw_string_outline(font, base, wd, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 7, Color(1, 1, 1, 0.85 if not _consumed else 0.4))
	draw_string(font, base, wd, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, tint)
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	if underline:
		var ul := Color("e0a030")
		draw_line(base + Vector2(0, 6), base + Vector2(tw, 6), ul, 4.0)
	if is_dough:
		_draw_dough_hud(font)

func _draw_tablet(off: Vector2) -> void:
	var lift := 12.0 if bold else 6.0
	var d := Iso.diamond(off, 0.92)
	var left := PackedVector2Array([d[3], d[2], d[2] + Vector2(0, -lift), d[3] + Vector2(0, -lift)])
	var right := PackedVector2Array([d[2], d[1], d[1] + Vector2(0, -lift), d[2] + Vector2(0, -lift)])
	var top := PackedVector2Array([d[0] + Vector2(0, -lift), d[1] + Vector2(0, -lift), d[2] + Vector2(0, -lift), d[3] + Vector2(0, -lift)])
	var col := Color("6a6f80") if bold else Palette.PAGE
	draw_colored_polygon(left, col.darkened(0.15))
	draw_colored_polygon(right, col.darkened(0.3))
	draw_colored_polygon(top, col)
	for poly in [left, right, top]:
		var loop: PackedVector2Array = poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, Palette.OUTLINE, 2.4, true)
	if bold:
		for p in [top[0].lerp(top[2], 0.2), top[0].lerp(top[2], 0.8)]:
			draw_circle(p, 2.2, Palette.GOLD)
	if _sliding:
		draw_arc(off + Vector2(0, -lift), 24.0, 0.0, TAU, 14, Color(Palette.CYAN, 0.7), 2.0, true)

func _draw_dough_cell(off: Vector2) -> void:
	var puff := 0.55 + 0.45 * _rise
	var c := off + Vector2(0, -8)
	draw_colored_polygon(DrawKit.ellipse(c, 26.0 * puff, 14.0 * puff, 18, 0.1, off.x), Color("e9d3a2"))
	draw_polyline(DrawKit.ellipse(c, 26.0 * puff, 14.0 * puff, 18, 0.1, off.x), Palette.OUTLINE, 2.4, true)
	for i in 3:
		draw_circle(c + Vector2((i - 1) * 9.0, sin(_t * 2.0 + i) * 2.0 - 3.0), 2.4, Color("f6ead0"))
	if _warm > 0.0:
		draw_circle(c, 34.0, Color(Palette.GOLD, 0.12))

func _draw_dough_hud(font: Font) -> void:
	if _rise >= 1.0:
		return
	var w := 70.0
	var y := -64.0
	draw_rect(Rect2(-w * 0.5, y, w, 6), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-w * 0.5, y, w * _rise, 6), Palette.GOLD)
	draw_rect(Rect2(-w * 0.5, y, w, 6), Palette.OUTLINE, false, 1.6)
