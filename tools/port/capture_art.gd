extends SceneTree
## Port tool: renders every scripted figure and prop of each scene on its own, on a transparent background, at
## one world pixel per pixel, and saves it as PNG with where its feet are. Needs a real renderer (xvfb), not --headless.
## Run: xvfb-run -a godot --path . -s tools/port/capture_art.gd -- <out_dir> [scene_key ...]

const SCENES := {
	"overworld": "res://scenes/main.tscn",
	"forge": "res://scenes/memory_forge.tscn",
	"pip": "res://scenes/memory_pip.tscn",
	"maud": "res://scenes/memory_maud.tscn",
	"proof": "res://scenes/memory_proof.tscn",
	"weighing": "res://scenes/memory_weighing.tscn",
	"scissor": "res://scenes/editor_scissor.tscn",
}
const IDENTITY := ["kind", "variant", "ghost", "who", "item_id", "occupied", "table_len", "warmth", "done", "options", "index", "prefix", "text", "style", "weight", "open", "length", "axis"]
const PER_KEY_MAX := 16     # at most 16 different pictures of one key (trees); the other instances reuse them

var _out := ""
var _only: Array = []
var _hashes := {}            # png hash -> file name (identical pictures are saved once)
var _index := []             # one entry per captured instance

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_only = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _key(n: Node) -> String:
	var sc = n.get_script()
	var cls: String = sc.get_global_name()
	var parts := [cls]
	var tree: bool = cls == "Prop" and int(n.get("kind")) == 0
	for k in IDENTITY:
		if tree and k == "variant":
			continue   # every tree has its own seed: 16 of them stand in for all
		if k in n:
			parts.append("%s=%s" % [k, str(n.get(k))])
	return "|".join(parts)

func _targets(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Node2D and c.get_script() != null:
			var cls: String = c.get_script().get_global_name()
			if cls not in ["IsoSlice", "IsoFloor", "GroundChunks", "AmbientDrift"]:
				out.append(c)
		_targets(c, out)

## Engine facings (grid directions, see Tilewright's FACING_NAMES) as the screen direction the game's figures use.
const FACINGS := {"E": Vector2(2, 1), "SE": Vector2(0, 1), "S": Vector2(-2, 1), "SW": Vector2(-1, 0), "W": Vector2(-2, -1), "NW": Vector2(0, -1), "N": Vector2(2, -1), "NE": Vector2(1, 0)}
const FRAME := Vector2i(160, 150)      # every pose frame: this size, the feet at FEET
const FEET := Vector2i(80, 128)

## The Storytender standing and walking in the eight directions, as frames of one size.
func _poses(level: Node, cam: Camera2D, targets: Array) -> void:
	var player: Node2D = level.get("_player")
	if player == null:
		return
	var frames := []
	var up: Node = player
	while up != null and up != level:
		var par: Node = up.get_parent()
		for c in par.get_children():
			if c is CanvasItem:
				c.visible = c == up
		up = par
	for f in FACINGS:
		var d: Vector2 = FACINGS[f].normalized()
		for i in 5:   # 0 = standing, 1..4 = walking
			player.set("_face_dir", d)
			player.set("_facing_right", d.x >= 0.0)
			player.set("_facing_back", d.y < -0.1)
			player.set("velocity", Vector2.ZERO if i == 0 else d * 120.0)
			player.set("_walk", 0.0 if i == 0 else (i - 1) * PI * 0.5)
			player.set("_t", 0.0)
			player.queue_redraw()
			cam.zoom = Vector2.ONE
			cam.position_smoothing_enabled = false
			cam.global_position = player.global_position - Vector2(0, 60)
			cam.force_update_scroll()
			for k in 3:
				await process_frame
			var img := root.get_texture().get_image()
			var feet: Vector2 = root.get_canvas_transform() * player.global_position
			var box := Rect2i(Vector2i(feet) - FEET, FRAME)
			var file := "pose_storytender_%s_%d.png" % [f, i]
			img.get_region(box).save_png(_out.path_join(file))
			frames.append({"figure": "storytender", "facing": f, "pose": "idle" if i == 0 else "walk", "step": i, "file": file})
	var fp := FileAccess.open(_out.path_join("poses.json"), FileAccess.WRITE)
	fp.store_string(JSON.stringify({"frame": [FRAME.x, FRAME.y], "feet": [FEET.x, FEET.y], "frames": frames}, " "))
	fp.close()

func _set_all(n: Node, v: bool) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			c.visible = v

func _run() -> void:
	root.transparent_bg = true
	for key in SCENES:
		if not _only.is_empty() and key not in _only:
			continue
		var level = (load(SCENES[key]) as PackedScene).instantiate()
		root.add_child(level)
		for i in 8:
			await process_frame
		# freeze the scene (the ground's culling and fading would keep switching pieces back on), then show nothing but the figure
		level.process_mode = Node.PROCESS_MODE_DISABLED
		for c in level.get_children():
			if c is CanvasLayer:
				c.visible = false
		var cam: Camera2D = level.get("_camera")
		if cam == null:
			for c in level.get_children():
				if c is Camera2D:
					cam = c
		var actors: Node2D = level.get("_actors")
		var targets := []
		_targets(level, targets)
		var per_key := {}
		var n_saved := 0
		for t in targets:
			var k := _key(t)
			per_key[k] = int(per_key.get(k, 0)) + 1
			var slot: int = (per_key[k] - 1) % PER_KEY_MAX
			var name_base := "%s_%s" % [key, k.md5_text().substr(0, 10)]
			var file := "%s_%d.png" % [name_base, slot]
			var entry := {"scene": key, "key": k, "node": String(t.name), "cls": t.get_script().get_global_name(), "grid": [Iso.to_grid(t.position).x, Iso.to_grid(t.position).y], "file": ""}
			if per_key[k] > PER_KEY_MAX:
				entry["file"] = file
				_index.append(entry)
				continue
			# show only this one: along the path from the level down to it, every sibling is hidden
			var was := {}
			var up: Node = t
			while up != null and up != level:
				var par: Node = up.get_parent()
				for c in par.get_children():
					if c is CanvasItem:
						if not was.has(c):
							was[c] = c.visible
						c.visible = c == up
				up = par
			var gp: Vector2 = t.global_position
			if cam:
				cam.zoom = Vector2.ONE
				cam.position_smoothing_enabled = false
				cam.global_position = gp - Vector2(0, 120)
				cam.offset = Vector2.ZERO
				cam.force_update_scroll()
			for i in 3:
				await process_frame
			var img := root.get_texture().get_image()
			var xf := root.get_canvas_transform()
			var feet: Vector2 = xf * gp
			var used := img.get_used_rect()
			# keep only what is near the figure (another object far away must not widen the picture)
			var box := Rect2i(Vector2i(feet) - Vector2i(256, 448), Vector2i(512, 512)).intersection(used)
			if box.size.x > 0 and box.size.y > 0:
				var crop := img.get_region(box)
				var sub := crop.get_used_rect()
				crop = crop.get_region(sub)
				var png := crop.save_png_to_buffer()
				var h := png.hex_encode().md5_text()
				if not _hashes.has(h):
					_hashes[h] = file
					crop.save_png(_out.path_join(file))
					n_saved += 1
				entry["file"] = _hashes[h]
				entry["feet"] = [feet.x - box.position.x - sub.position.x, feet.y - box.position.y - sub.position.y]
				entry["size"] = [sub.size.x, sub.size.y]
			_index.append(entry)
			for a in was:
				a.visible = was[a]
		if key == "overworld":
			await _poses(level, cam, targets)
		print("art ", key, ": ", targets.size(), " objects, ", n_saved, " new pictures")
		level.queue_free()
		for i in 3:
			await process_frame
	var f := FileAccess.open(_out.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_index, " "))
	f.close()
	quit()
