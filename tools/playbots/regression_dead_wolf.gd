extends SceneTree
var m
func _initialize():
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	root.get_node("Settings").tutorial_tips = false
	for k in ["intro_done","met_garrick","tut_move","tut_quill","index_seen","has_quill","lesson_done","tut_echo","tut_echo_done","memory_done","tut_rewrite"]: gs.set_flag(k)
	m = load("res://scenes/memory_pip.tscn").instantiate(); root.add_child(m); current_scene = m
	run()
func run():
	for i in 360: await process_frame
	var gs = root.get_node("GameState")
	gs.in_dialogue = false
	m._busy = false
	var g: Dictionary = m._sleepers["wood"]
	print("wolves tracked ", g["enemies"].size())
	g["enemies"][0].queue_free()
	for i in 5: await process_frame
	m._stones["b"]._cd = 0.0
	m._stones["b"].rewrite()
	for i in 5: await process_frame
	print("rewrote with a dead wolf")
	m._stones["b"]._cd = 0.0
	m._stones["b"].rewrite()
	m._stones["b"]._cd = 0.0
	m._stones["b"].rewrite()
	print("end")
	quit()
