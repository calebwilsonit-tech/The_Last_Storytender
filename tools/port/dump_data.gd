extends SceneTree
## Port tool: writes the game's data tables as JSON for the Tilewright port: every constant and every
## no-argument (or small-integer-argument) static function of the data scripts, as the game itself evaluates them.
## Run: godot --headless --path . -s tools/port/dump_data.gd -- <out_dir>

const SCRIPTS := {
	"story": "res://scripts/story.gd",
	"items": "res://scripts/item_db.gd",
	"catalog": "res://scripts/item_catalog.gd",
	"drops": "res://scripts/drop_tables.gd",
	"tutorials": "res://scripts/tutorials.gd",
	"enemy_kinds": "res://scripts/enemy_kinds.gd",
	"prologue_map": "res://data/prologue_map.gd",
	"trial_prizes": "res://scripts/trial_prizes.gd",
	"palette": "res://scripts/palette.gd",
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for key in SCRIPTS:
		var sc: Script = load(SCRIPTS[key])
		var d := {"constants": {}, "functions": {}}
		var consts := sc.get_script_constant_map()
		for c in consts:
			var v = _plain(consts[c])
			if v != null:
				d.constants[c] = v
		for m in sc.get_script_method_list():
			if not (m.flags & METHOD_FLAG_STATIC):
				continue
			var name: String = m.name
			if name.begins_with("_"):
				continue
			var args: Array = m.args
			print("  ", key, ".", name)
			if args.is_empty():
				d.functions[name] = _plain(sc.call(name))
			elif args.size() == 1 and args[0].type == TYPE_INT:
				var r := {}
				for i in 8:
					r[str(i)] = _plain(sc.call(name, i))
				d.functions[name] = r
		var f := FileAccess.open(out.path_join(key + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(d, " "))
		f.close()
		print("data ", key, ": ", d.constants.size(), " constants, ", d.functions.size(), " functions")
	# what each tiered chest of the overworld pays out (TrialPrizes.roll is seeded by the chest's cell)
	var pm = load("res://data/prologue_map.gd")
	var tp = load("res://scripts/trial_prizes.gd")
	var rolls := {}
	for key in pm.CHESTS:
		var r: String = pm.CHESTS[key]
		var parts: PackedStringArray = String(key).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		rolls[key] = tp.roll(int(r.split(":")[1]), cell) if r.begins_with("tier:") else r
	var f2 := FileAccess.open(out.path_join("chest_rolls.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(rolls, " "))
	f2.close()
	print("data chest_rolls: ", rolls.size())
	quit()

func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_COLOR:
			return "#" + v.to_html(true)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var a := []
			for e in v:
				a.append(_plain(e))
			return a
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
	return null
