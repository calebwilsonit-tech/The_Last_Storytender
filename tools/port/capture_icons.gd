extends SceneTree
## Port tool: draws every item's icon with the game's own ItemIcon.draw_item at 64x64 on a transparent background.
## Needs a real renderer (xvfb). Run: xvfb-run -a godot --path . -s tools/port/capture_icons.gd -- <out_dir>

class Pad extends Node2D:
	var id := ""
	var icon = null       # the game's ItemIcon script, loaded once the autoloads exist
	func _draw() -> void:
		if icon != null and id != "":
			icon.draw_item(self, id, Vector2(48, 48), 64.0)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.transparent_bg = true
	await process_frame
	var db = load("res://scripts/item_db.gd")
	var cat = load("res://scripts/item_catalog.gd")
	var ids: Array = db.ITEMS.keys()
	for k in cat.ITEMS.keys():
		if k not in ids:
			ids.append(k)
	var pad := Pad.new()
	pad.icon = load("res://scripts/item_icon.gd")
	root.add_child(pad)
	for id in ids:
		pad.id = id
		pad.queue_redraw()
		for i in 3:
			await process_frame
		var img := root.get_texture().get_image().get_region(Rect2i(0, 0, 96, 96))
		img.save_png(out.path_join("icon_%s.png" % id))
	print("icons ", ids.size())
	quit()
