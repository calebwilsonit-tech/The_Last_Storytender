extends SceneTree
## Port tool: runs each game scene headless for a few frames, then records everything in it as JSON
## (the floor: cells, heights, stairs; every scripted node: its class, name, cell, elevation and simple
## properties; the interactables), so the Tilewright port can be built 1 for 1 from what the game really builds.
## Run: godot --headless --path . -s tools/port/snapshot.gd -- <out_dir>

const SCENES := {
	"overworld": "res://scenes/main.tscn",
	"forge": "res://scenes/memory_forge.tscn",
	"pip": "res://scenes/memory_pip.tscn",
	"maud": "res://scenes/memory_maud.tscn",
	"proof": "res://scenes/memory_proof.tscn",
	"weighing": "res://scenes/memory_weighing.tscn",
	"scissor": "res://scenes/editor_scissor.tscn",
}

var _out := "user://port"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _simple(v: Variant) -> Variant:
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return v if typeof(v) != TYPE_STRING_NAME else String(v)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_COLOR:
			return "#" + v.to_html(true)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var out := []
			for e in v:
				var s = _simple(e)
				if s == null:
					return null
				out.append(s)
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				var s = _simple(v[k])
				if s == null:
					return null
				d[str(k)] = s
			return d
	return null

func _props(n: Object) -> Dictionary:
	var d := {}
	for p in n.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var s = _simple(n.get(p.name))
		if s != null:
			d[p.name] = s
	return d

func _walk(n: Node, out: Array, depth: int) -> void:
	if depth > 6:
		return
	for c in n.get_children():
		var sc = c.get_script()
		if c is Node2D and sc != null:
			var cls: String = sc.get_global_name()
			if cls == "":
				cls = sc.resource_path.get_file().get_basename()
			if cls != "IsoSlice":
				var p: Vector2 = c.position
				var g := Iso.to_grid(p)
				out.append({"class": cls, "name": String(c.name), "pos": [p.x, p.y], "grid": [g.x, g.y],
					"visible": c.visible, "props": _props(c), "parent": String(n.name)})
		_walk(c, out, depth + 1)

func _run() -> void:
	for key in SCENES:
		var packed: PackedScene = load(SCENES[key])
		var level = packed.instantiate()
		root.add_child(level)
		for i in 10:
			await process_frame
		var snap := {"scene": SCENES[key], "class": level.get_script().get_global_name()}
		var fl = level.get("_floor")
		if fl != null:
			var cells := {}
			for c in fl.cells:
				cells["%d,%d" % [c.x, c.y]] = fl.cells[c]
			var heights := {}
			for c in fl.heights:
				heights["%d,%d" % [c.x, c.y]] = fl.heights[c]
			var stairs := {}
			for c in fl.stairs:
				stairs["%d,%d" % [c.x, c.y]] = [fl.stairs[c].x, fl.stairs[c].y]
			var blockers := []
			for c in fl.blockers:
				blockers.append([c.x, c.y])
			snap["floor"] = {"cells": cells, "heights": heights, "stairs": stairs, "blockers": blockers}
		snap["start"] = _simple(Iso.to_grid(level.get("_start"))) if level.get("_start") != null else null
		snap["level_props"] = _props(level)
		var nodes := []
		_walk(level, nodes, 0)
		snap["nodes"] = nodes
		var inter := []
		var il = level.get("_interactables")
		if il != null:
			for it in il:
				var node = it.get("node")
				var prompt := ""
				if it.get("prompt") is Callable:
					var r = it.prompt.call()
					prompt = str(r)
				inter.append({"node": String(node.name) if node else "", "pos": _simple(node.position) if node else null, "prompt": prompt, "range": it.get("range", 0.0)})
		snap["interactables"] = inter
		var f := FileAccess.open(_out.path_join(key + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(snap, "", false))
		f.close()
		print("snapshot ", key, ": ", nodes.size(), " nodes, ", (snap.get("floor", {}) as Dictionary).get("cells", {}).size(), " cells")
		level.queue_free()
		await process_frame
		await process_frame
	quit()
