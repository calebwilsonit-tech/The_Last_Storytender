extends SceneTree
## Port tool: crops real tile pictures out of the running game, for the Tilewright tileset: the top of a flat cell
## (64x32, outside the diamond cleared) for each kind of floor, both checker colours and a few cells each (the grass
## differs per cell), and one level of a cliff's left and right face. Needs a real renderer (xvfb).
## Run: xvfb-run -a godot --path . -s tools/port/capture_tiles.gd -- <out_dir>

const SCENES := {
	"overworld": "res://scenes/main.tscn",
	"forge": "res://scenes/memory_forge.tscn",
	"pip": "res://scenes/memory_pip.tscn",
	"maud": "res://scenes/memory_maud.tscn",
	"scissor": "res://scenes/editor_scissor.tscn",
}
const PER := 6          # cells captured per kind and checker colour

var _out := ""
var _index := []

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _flat(fl, c: Vector2i, props: Dictionary) -> bool:
	var k: String = fl.cells.get(c, "")
	var h: int = fl.level(c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if fl.cells.get(n, "") != k or fl.level(n) != h or fl.stairs.has(n):
				return false
	return not fl.blockers.has(c) and not props.has(c)

func _crop(img: Image, pts: PackedVector2Array) -> Image:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var box := Rect2i(Vector2i(floor(r.position.x), floor(r.position.y)), Vector2i(ceil(r.size.x), ceil(r.size.y)))
	var out := img.get_region(box)
	out.convert(Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var p := Vector2(box.position) + Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, pts):
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out

func _run() -> void:
	for key in SCENES:
		var level = (load(SCENES[key]) as PackedScene).instantiate()
		root.add_child(level)
		for i in 8:
			await process_frame
		for c in level.get_children():
			if c is CanvasLayer and c.layer >= 0:
				c.visible = false
		var fl = level.get("_floor")
		var player: Node2D = level.get("_player")
		var cam: Camera2D = level.get("_camera")
		var props := {}
		var nodes := []
		_collect(level, nodes)
		for n in nodes:
			var g: Vector2 = Iso.to_grid(n.position)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if absi(dx) + absi(dy) <= 1:
						props[Vector2i(roundi(g.x) + dx, roundi(g.y) + dy)] = true
		for n in nodes:
			n.modulate = Color(1, 1, 1, 0)
			n.self_modulate = Color(1, 1, 1, 0)
		var want := {}      # "kind|parity" -> count
		var faces := {}     # "kind|left" -> done
		var cells: Array = fl.cells.keys()
		cells.sort_custom(func(a, b): return (a.x * 7919 + a.y * 104729) % 1009 < (b.x * 7919 + b.y * 104729) % 1009)
		for c in cells:
			var kind: String = fl.cells[c]
			if kind == "#":
				continue
			var par: int = (c.x + c.y) % 2
			var wk := "%s|%d" % [kind, par]
			var need_top: bool = int(want.get(wk, 0)) < PER and _flat(fl, c, props)
			var h: int = fl.level(c)
			var left_ok: bool = not faces.has(kind + "|left") and h >= 1 and not fl.stairs.has(c + Vector2i(0, 1)) and fl.cells.has(c + Vector2i(0, 1)) and fl.level(c + Vector2i(0, 1)) <= h - 1 and not fl.stairs.has(c) and not props.has(c + Vector2i(0, 1))
			var right_ok: bool = not faces.has(kind + "|right") and h >= 1 and not fl.stairs.has(c + Vector2i(1, 0)) and fl.cells.has(c + Vector2i(1, 0)) and fl.level(c + Vector2i(1, 0)) <= h - 1 and not fl.stairs.has(c) and not props.has(c + Vector2i(1, 0))
			if not (need_top or left_ok or right_ok):
				continue
			var gp: Vector2 = Iso.pt(Vector2(c), float(h))
			player.global_position = Iso.to_screen(Vector2(c))
			player.modulate = Color(1, 1, 1, 0)
			for i in 5:
				if cam:
					cam.zoom = Vector2.ONE
					cam.position_smoothing_enabled = false
					cam.global_position = gp
					cam.offset = Vector2.ZERO
				await process_frame
			var img := root.get_texture().get_image()
			var xf := root.get_canvas_transform()
			var ctr: Vector2 = xf * gp
			var N := ctr + Vector2(0, -16)
			var E := ctr + Vector2(32, 0)
			var S := ctr + Vector2(0, 16)
			var W := ctr + Vector2(-32, 0)
			var drop := Vector2(0, Iso.LEVEL_H)
			var view := Rect2(Vector2.ZERO, Vector2(img.get_size())).grow(-2)
			if not (view.has_point(N) and view.has_point(W) and view.has_point(E) and view.has_point(S + drop)):
				continue
			if need_top:
				var file := "%s_%s_top_%d_%d.png" % [key, kind if kind != "." else "plains", par, want.get(wk, 0)]
				_crop(img, PackedVector2Array([N, E, S, W])).save_png(_out.path_join(file))
				_index.append({"scene": key, "kind": kind, "parity": par, "what": "top", "file": file, "cell": [c.x, c.y]})
				want[wk] = int(want.get(wk, 0)) + 1
			if left_ok:
				var file := "%s_%s_left.png" % [key, kind if kind != "." else "plains"]
				_crop(img, PackedVector2Array([W, S, S + drop, W + drop])).save_png(_out.path_join(file))
				_index.append({"scene": key, "kind": kind, "what": "left", "file": file, "cell": [c.x, c.y]})
				faces[kind + "|left"] = true
			if right_ok:
				var file := "%s_%s_right.png" % [key, kind if kind != "." else "plains"]
				_crop(img, PackedVector2Array([S, E, E + drop, S + drop])).save_png(_out.path_join(file))
				_index.append({"scene": key, "kind": kind, "what": "right", "file": file, "cell": [c.x, c.y]})
				faces[kind + "|right"] = true
		print("tiles ", key, ": ", want, " faces ", faces.keys())
		level.queue_free()
		for i in 3:
			await process_frame
	var f := FileAccess.open(_out.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_index, " "))
	f.close()
	quit()

func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Node2D and c.get_script() != null and c.get_script().get_global_name() not in ["IsoSlice", "IsoFloor", "GroundChunks", "AmbientDrift", "Player"]:
			out.append(c)
		_collect(c, out)
