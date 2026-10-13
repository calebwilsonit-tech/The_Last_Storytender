extends SceneTree
# A bot that plays the Weighing Room with the real controls: it presses the move actions, the echo and interact
# keys, and the guards are live. It logs what happens.
var m
var P
var shots := 0
var log_t := 0.0
func _initialize():
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	root.get_node("Settings").tutorial_tips = false
	for k in ["intro_done","met_garrick","tut_move","tut_quill","index_seen","has_quill","lesson_done","tut_echo","tut_echo_done","memory_done"]: gs.set_flag(k)
	m = load("res://scenes/memory_weighing.tscn").instantiate(); root.add_child(m); current_scene = m
	run()
func scr(x, y) -> Vector2: return Iso.to_screen(Vector2(x, y))
func tick(secs: float):
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	var n := int(secs * 60.0)
	for i in n: await physics_frame
func press(a, on):
	if on: Input.action_press(a)
	else: Input.action_release(a)
func steer(target: Vector2):
	var d: Vector2 = target - P.position
	var v: Vector2 = Vector2(d.x, d.y * 2.0)
	var L: float = v.length()
	if L < 1.0: v = Vector2.ZERO
	else: v /= L
	Input.action_release("move_left"); Input.action_release("move_right"); Input.action_release("move_up"); Input.action_release("move_down")
	if v.x < -0.15: Input.action_press("move_left", minf(-v.x, 1.0))
	if v.x > 0.15: Input.action_press("move_right", minf(v.x, 1.0))
	if v.y < -0.15: Input.action_press("move_up", minf(-v.y, 1.0))
	if v.y > 0.15: Input.action_press("move_down", minf(v.y, 1.0))
func stop():
	for a in ["move_left","move_right","move_up","move_down"]: Input.action_release(a)
func status(tag):
	var chasing := 0
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e._state == "chase": chasing += 1
	print("[%s] ink=%.0f cell=%s chasing=%d echoes=%d" % [tag, P.ink, m._floor.cell_at(P.position), chasing, m._echoes.size()])
func go(cells: Array, tag := ""):
	for c in cells:
		var tgt := scr(c[0], c[1])
		var t := 0.0
		while P.position.distance_to(tgt) > 14.0 and t < 14.0:
			steer(tgt)
			await physics_frame
			t += 1.0 / 60.0
		if t >= 14.0:
			print("STUCK going to ", c, " at ", m._floor.cell_at(P.position), " pos ", P.position)
			stop()
			return false
	stop()
	return true
func echo_key():
	var ev := InputEventAction.new(); ev.action = "echo"; ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var ev2 := InputEventAction.new(); ev2.action = "echo"; ev2.pressed = false
	Input.parse_input_event(ev2)
func interact():
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var ev2 := InputEventAction.new(); ev2.action = "interact"; ev2.pressed = false
	Input.parse_input_event(ev2)
	await tick(0.3)
func record(cells: Array):
	await echo_key()
	await go(cells)
	await tick(0.4)
	await echo_key()
	await tick(0.2)
func shot(name):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "_" + name + ".png")
func run():
	await tick(1.0)
	m._busy = false
	P = m._player
	P.position = scr(26, 22)
	status("start")
	# --- Tare Room: one echo on the ledge plate
	await go([[22, 22], [17, 21], [15, 20]])
	await record([[13, 20], [12, 20], [10, 20]])
	await go([[13, 20], [14, 19]])
	await tick(1.5)
	print("A open ", m._gate_nodes["A"].is_open)
	await go([[14, 17], [14, 15]])
	status("relay")
	# --- Relay
	await record([[12, 15], [10, 14]])
	await go([[14, 14], [14, 12]])
	await tick(1.0)
	print("x open ", m._gate_nodes["x"].is_open)
	await go([[14, 10]])
	await record([[14, 9]])
	await go([[16, 9], [18, 9], [19, 10]])
	await tick(0.5)
	print("y open ", m._gate_nodes["y"].is_open)
	await interact()
	await go([[20, 9], [20, 8]])
	await interact()
	print("capacity ", root.get_node("GameState").echo_capacity(), " weights ", m._weights.size())
	await shot("relay")
	# back out through the held gates
	await go([[17, 9], [14, 10], [14, 12], [14, 15], [14, 17], [14, 20], [17, 21], [22, 22], [26, 22], [32, 20], [32, 17], [32, 15]])
	status("night shift")
	await shot("night_enter")
	# --- Night Shift: echoes along the wall to each plate
	await record([[32, 14], [29, 14], [26, 14], [25, 13]])
	status("after echo d")
	await go([[27, 14], [31, 14], [32, 14]])
	await record([[36, 13], [39, 11], [39, 9]])
	status("after echo e")
	await go([[34, 13], [30, 13], [27, 10], [27, 8]])
	await tick(0.5)
	print("B open ", m._gate_nodes["B"].is_open)
	status("at gate B")
	await shot("night_gate")
	await go([[27, 6], [27, 4]])
	# --- Pan Room
	await record([[26, 3], [25, 2]])
	await tick(1.0)
	await go([[27, 3], [30, 2], [33, 2], [35, 2]])
	status("on bridge")
	await shot("pan_bridge")
	await go([[38, 3]])
	await interact()
	print("weights ", m._weights.size())
	await go([[34, 3], [28, 4], [27, 6], [27, 8], [30, 13], [32, 14], [32, 15], [32, 19], [34, 22], [40, 23], [44, 23]])
	status("counterweights")
	# --- Counterweights
	await record([[46, 24]])
	await go([[48, 24], [50, 24]])
	print("s open ", m._gate_nodes["s"].is_open)
	await record([[52, 24]])
	await go([[54, 24], [56, 24]])
	print("t open ", m._gate_nodes["t"].is_open)
	await record([[58, 24]])
	await go([[58, 22]])
	await tick(0.5)
	print("W open ", m._gate_nodes["W"].is_open, " echoes ", m._echoes.size())
	await shot("counter")
	await go([[58, 19], [58, 16], [58, 13], [58, 12]])
	await interact()
	print("weights ", m._weights.size(), " scale open ", m._scale.is_open)
	status("done weights")
	await go([[58, 16], [58, 19], [58, 22], [56, 24], [52, 24], [49, 24], [46, 24], [44, 23], [41, 23], [36, 22], [32, 23], [32, 26], [32, 28], [32, 30]])
	print("scale gate open ", m._scale.is_open)
	await go([[32, 32]])
	await interact()
	await tick(1.0)
	print("reward flag ", root.get_node("GameState").has_flag("side_weighing_done"), " hourglass count ", root.get_node("GameState").count("hourglass_of_drafts"))
	status("vault")
	await shot("vault")
	quit()
