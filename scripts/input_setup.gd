extends Node
## Registers input actions in code so project.godot stays readable.
## 8-directional WASD (arrow keys also work).

func _ready() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_bind("attack", [KEY_J])
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind("dash", [KEY_SHIFT])
	_bind("lantern", [KEY_Q])
	_bind_mouse("lantern", MOUSE_BUTTON_RIGHT)
	_bind("style_underline", [KEY_1])
	_bind("style_bold", [KEY_2])
	_bind("style_italic", [KEY_3])
	_bind("paste", [KEY_V])   # place the clipping you are carrying
	_bind("echo", [KEY_R])    # remember a few seconds of walking (Garrick's memory)
	_bind("sneak", [KEY_CTRL, KEY_C])   # hold to creep: slower, much quieter
	_bind("inventory", [KEY_TAB, KEY_I])
	_bind("use_item", [KEY_F])
	_bind("debug_reset", [KEY_F12])  # wipe the save and restart
	_bind("debug_report", [KEY_F10])  # save the playtest report
	_bind("debug_damage", [KEY_F1])   # test: take ink damage
	_bind("debug_heal", [KEY_F2])     # test: restore ink

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _bind_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
