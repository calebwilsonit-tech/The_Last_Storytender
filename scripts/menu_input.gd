class_name MenuInput
extends RefCounted
## One place that decides what counts as "up / down / left / right / accept / back"
## in menus: WASD, arrow keys and gamepad all work.

static func nav(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO

static func accept(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")

static func back(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel")
