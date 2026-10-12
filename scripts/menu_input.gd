class_name MenuInput
extends RefCounted
## One place that decides what counts as "up / down / left / right / accept / back"
## in menus: WASD, arrow keys and gamepad all work.

# A held thumb stick sends a motion event every frame, and each one counts as "pressed", which
# made menus race. Stick motion is therefore rate-limited (the d-pad and keys are untouched).
const STICK_REPEAT_MS := 240
const STICK_MIN := 0.6
static var _stick_last_ms := 0
static var _stick_event_id := 0
static var _stick_result := Vector2i.ZERO

static func nav(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadMotion:
		var id := event.get_instance_id()
		if id == _stick_event_id:
			return _stick_result      # several listeners ask about the same event
		_stick_event_id = id
		_stick_result = Vector2i.ZERO
		if absf(event.axis_value) < STICK_MIN:
			_stick_last_ms = 0         # stick returned to centre: next push is instant
			return _stick_result
		var now := Time.get_ticks_msec()
		if now - _stick_last_ms < STICK_REPEAT_MS:
			return _stick_result
		var d := _nav_raw(event)
		if d != Vector2i.ZERO:
			_stick_last_ms = now
		_stick_result = d
		return d
	return _nav_raw(event)

static func _nav_raw(event: InputEvent) -> Vector2i:
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
	# B / Circle backs out of menus. (In the world B is Dash, so only menus call this.)
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	return event.is_action_pressed("ui_cancel")
