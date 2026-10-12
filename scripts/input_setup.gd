extends Node
## Registers input actions in code so project.godot stays readable.
## 8-directional WASD (arrow keys also work).

func _ready() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("debug_damage", [KEY_SPACE])  # Phase 1 test: take ink damage
	_bind("debug_heal", [KEY_H])        # Phase 1 test: restore ink

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
