extends Node
## Registers every input action in code (so project.godot stays readable) and owns the
## player's key / button remapping. Each action has one rebindable "primary" input per
## device (keyboard+mouse, controller) plus fixed extras (arrow keys, Space, right trigger...).
## Specs are small dictionaries so they can be saved: {"t": "key", "c": keycode},
## {"t": "mouse", "b": button}, {"t": "btn", "b": joy_button}, {"t": "axis", "a": axis}
## (a trigger) and {"t": "stick", "a": axis, "v": -1 or 1}.

signal device_changed(device: String)
signal bindings_changed

const KB := "kb"
const PAD := "pad"

var device := KB                    # whichever the player touched last
var _used := {KB: {}, PAD: {}}

static func K(code: int) -> Dictionary:
	return {"t": "key", "c": code}
static func M(b: int) -> Dictionary:
	return {"t": "mouse", "b": b}
static func B(b: int) -> Dictionary:
	return {"t": "btn", "b": b}
static func TRIG(axis: int) -> Dictionary:
	return {"t": "axis", "a": axis}
static func STICK(axis: int, v: float) -> Dictionary:
	return {"t": "stick", "a": axis, "v": v}

## id -> {label, kb (primary), kb_alt (fixed), pad (primary, may be empty), pad_alt (fixed)}
## Order matters: it is the order of the Controls screen.
var DEFS: Array = []

func _build_defs() -> void:
	DEFS = [
		{"id": "move_up", "label": "Move up", "kb": K(KEY_W), "kb_alt": [K(KEY_UP)], "pad": {}, "pad_alt": [STICK(1, -1.0)]},
		{"id": "move_down", "label": "Move down", "kb": K(KEY_S), "kb_alt": [K(KEY_DOWN)], "pad": {}, "pad_alt": [STICK(1, 1.0)]},
		{"id": "move_left", "label": "Move left", "kb": K(KEY_A), "kb_alt": [K(KEY_LEFT)], "pad": {}, "pad_alt": [STICK(0, -1.0)]},
		{"id": "move_right", "label": "Move right", "kb": K(KEY_D), "kb_alt": [K(KEY_RIGHT)], "pad": {}, "pad_alt": [STICK(0, 1.0)]},
		{"id": "interact", "label": "Interact / continue", "kb": K(KEY_E), "kb_alt": [K(KEY_SPACE), K(KEY_ENTER)], "pad": B(JOY_BUTTON_A), "pad_alt": []},
		{"id": "attack", "label": "Quill (strike)", "kb": K(KEY_J), "kb_alt": [M(MOUSE_BUTTON_LEFT)], "pad": B(JOY_BUTTON_X), "pad_alt": [TRIG(JOY_AXIS_TRIGGER_RIGHT)]},
		{"id": "lantern", "label": "Lantern (hold)", "kb": K(KEY_Q), "kb_alt": [M(MOUSE_BUTTON_RIGHT)], "pad": TRIG(JOY_AXIS_TRIGGER_LEFT), "pad_alt": []},
		{"id": "dash", "label": "Dash", "kb": K(KEY_SHIFT), "kb_alt": [], "pad": B(JOY_BUTTON_B), "pad_alt": []},
		{"id": "sneak", "label": "Creep (hold)", "kb": K(KEY_CTRL), "kb_alt": [K(KEY_C)], "pad": B(JOY_BUTTON_LEFT_STICK), "pad_alt": []},
		{"id": "inventory", "label": "Binder", "kb": K(KEY_TAB), "kb_alt": [K(KEY_I)], "pad": B(JOY_BUTTON_BACK), "pad_alt": []},
		{"id": "use_item", "label": "Use quick item", "kb": K(KEY_F), "kb_alt": [], "pad": B(JOY_BUTTON_Y), "pad_alt": []},
		{"id": "style_underline", "label": "Underline style", "kb": K(KEY_1), "kb_alt": [], "pad": B(JOY_BUTTON_DPAD_LEFT), "pad_alt": []},
		{"id": "style_bold", "label": "Bold style", "kb": K(KEY_2), "kb_alt": [], "pad": B(JOY_BUTTON_DPAD_UP), "pad_alt": []},
		{"id": "style_italic", "label": "Italic style", "kb": K(KEY_3), "kb_alt": [], "pad": B(JOY_BUTTON_DPAD_RIGHT), "pad_alt": []},
		{"id": "paste", "label": "Paste clipping", "kb": K(KEY_V), "kb_alt": [], "pad": B(JOY_BUTTON_RIGHT_SHOULDER), "pad_alt": []},
		{"id": "map", "label": "Open the map", "kb": K(KEY_M), "kb_alt": [], "pad": B(JOY_BUTTON_DPAD_DOWN), "pad_alt": []},
		{"id": "echo", "label": "Remember an Echo", "kb": K(KEY_R), "kb_alt": [], "pad": B(JOY_BUTTON_LEFT_SHOULDER), "pad_alt": []},
	]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_defs()
	rebuild()

# --- Lookup -------------------------------------------------------------------------------
func def_of(action: String) -> Dictionary:
	for d: Dictionary in DEFS:
		if d["id"] == action:
			return d
	return {}

func primary(action: String, dev: String) -> Dictionary:
	var over: Dictionary = Settings.bindings.get(action, {})
	if over.has(dev):
		return over[dev]
	var d := def_of(action)
	return d.get(dev, {})

func _key(spec: Dictionary) -> String:
	return JSON.stringify(spec, "", true)

# --- Building the InputMap --------------------------------------------------------------------
func spec_to_event(s: Dictionary) -> InputEvent:
	match s.get("t", ""):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(s["c"]) as Key
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = int(s["b"]) as MouseButton
			return e
		"btn":
			var e := InputEventJoypadButton.new()
			e.button_index = int(s["b"]) as JoyButton
			return e
		"axis":
			var e := InputEventJoypadMotion.new()
			e.axis = int(s["a"]) as JoyAxis
			e.axis_value = 1.0
			return e
		"stick":
			var e := InputEventJoypadMotion.new()
			e.axis = int(s["a"]) as JoyAxis
			e.axis_value = float(s["v"])
			return e
	return null

func rebuild() -> void:
	_used = {KB: {}, PAD: {}}
	for d: Dictionary in DEFS:
		for dev in [KB, PAD]:
			var p := primary(d["id"], dev)
			if not p.is_empty():
				_used[dev][_key(p)] = d["id"]
	for d: Dictionary in DEFS:
		var action: String = d["id"]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for dev in [KB, PAD]:
			var specs: Array = []
			var p := primary(action, dev)
			if not p.is_empty():
				specs.append(p)
			for alt: Dictionary in d[dev + "_alt"]:
				# An alternate that another action now owns as its primary steps aside.
				if _used[dev].get(_key(alt), action) == action:
					specs.append(alt)
			for s: Dictionary in specs:
				var ev := spec_to_event(s)
				if ev:
					InputMap.action_add_event(action, ev)
		var dz := 0.5 if d["id"] in ["lantern", "attack"] else 0.25
		InputMap.action_set_deadzone(action, dz)
	_fixed("aim_left", [STICK(JOY_AXIS_RIGHT_X, -1.0)])
	_fixed("aim_right", [STICK(JOY_AXIS_RIGHT_X, 1.0)])
	_fixed("aim_up", [STICK(JOY_AXIS_RIGHT_Y, -1.0)])
	_fixed("aim_down", [STICK(JOY_AXIS_RIGHT_Y, 1.0)])
	_fixed("debug_reset", [K(KEY_F12)])    # wipe the save and restart
	_fixed("debug_report", [K(KEY_F10)])   # save the playtest report
	_fixed("debug_damage", [K(KEY_F1)])    # test: take ink damage
	_fixed("debug_heal", [K(KEY_F2)])      # test: restore ink
	# Start opens the pause menu (and backs out of menus) like Esc and B do.
	if InputMap.has_action("ui_cancel"):
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		if not InputMap.action_has_event("ui_cancel", start):
			InputMap.action_add_event("ui_cancel", start)
	bindings_changed.emit()

func _fixed(action: String, specs: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for s: Dictionary in specs:
		var ev := spec_to_event(s)
		if ev:
			InputMap.action_add_event(action, ev)
	InputMap.action_set_deadzone(action, 0.3)

# --- Rebinding ---------------------------------------------------------------------------------
## Turns a pressed input into a spec for that device, or {} if it can't be bound there.
func event_to_spec(ev: InputEvent, dev: String) -> Dictionary:
	if dev == KB:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode != KEY_ESCAPE:
			return K(int(ev.physical_keycode))
		if ev is InputEventMouseButton and ev.pressed and ev.button_index <= MOUSE_BUTTON_MIDDLE:
			return M(int(ev.button_index))
	else:
		if ev is InputEventJoypadButton and ev.pressed:
			return B(int(ev.button_index))
		if ev is InputEventJoypadMotion and (ev.axis == JOY_AXIS_TRIGGER_LEFT or ev.axis == JOY_AXIS_TRIGGER_RIGHT) and ev.axis_value > 0.7:
			return TRIG(int(ev.axis))
	return {}

func set_binding(action: String, dev: String, spec: Dictionary) -> void:
	var old := primary(action, dev)
	var other: String = _used[dev].get(_key(spec), "")
	if other != "" and other != action:
		# Swap: the action that had this input takes the one being given up.
		_save_override(other, dev, old)
	_save_override(action, dev, spec)
	Settings.save_settings()
	rebuild()

func _save_override(action: String, dev: String, spec: Dictionary) -> void:
	var o: Dictionary = Settings.bindings.get(action, {})
	o[dev] = spec
	Settings.bindings[action] = o

func reset_all() -> void:
	Settings.bindings = {}
	Settings.save_settings()
	rebuild()

func is_rebindable(action: String, dev: String) -> bool:
	return not def_of(action).get(dev, {}).is_empty()

# --- Last-used device ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	var now := ""
	if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed:
		now = KB
	elif event is InputEventJoypadButton and event.pressed:
		now = PAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		now = PAD
	if now != "" and now != device:
		device = now
		device_changed.emit(device)

func pad_style() -> String:
	var n := Input.get_joy_name(0).to_lower()
	for k in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if n.contains(k):
			return "ps"
	for k in ["nintendo", "switch", "pro controller"]:
		if n.contains(k):
			return "nintendo"
	return "xbox"

# --- Names for the screen -------------------------------------------------------------------------
func spec_text(s: Dictionary) -> String:
	match s.get("t", ""):
		"key":
			var code := int(s["c"]) as Key
			var kc := DisplayServer.keyboard_get_keycode_from_physical(code)
			var t := OS.get_keycode_string(kc if kc != KEY_NONE else code)
			return t if t != "" else "Key"
		"mouse":
			return {1: "LMB", 2: "RMB", 3: "MMB"}.get(int(s["b"]), "Mouse")
		"btn":
			return _pad_button_text(int(s["b"]))
		"axis":
			var ps := pad_style()
			var left: bool = int(s["a"]) == JOY_AXIS_TRIGGER_LEFT
			if ps == "ps":
				return "L2" if left else "R2"
			if ps == "nintendo":
				return "ZL" if left else "ZR"
			return "LT" if left else "RT"
		"stick":
			return "L-Stick"
	return "—"

func _pad_button_text(b: int) -> String:
	var ps := pad_style()
	match b:
		JOY_BUTTON_A: return {"xbox": "A", "ps": "Cross", "nintendo": "B"}[ps]
		JOY_BUTTON_B: return {"xbox": "B", "ps": "Circle", "nintendo": "A"}[ps]
		JOY_BUTTON_X: return {"xbox": "X", "ps": "Square", "nintendo": "Y"}[ps]
		JOY_BUTTON_Y: return {"xbox": "Y", "ps": "Triangle", "nintendo": "X"}[ps]
		JOY_BUTTON_BACK: return {"xbox": "View", "ps": "Share", "nintendo": "-"}[ps]
		JOY_BUTTON_START: return {"xbox": "Menu", "ps": "Options", "nintendo": "+"}[ps]
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return {"xbox": "LB", "ps": "L1", "nintendo": "L"}[ps]
		JOY_BUTTON_RIGHT_SHOULDER: return {"xbox": "RB", "ps": "R1", "nintendo": "R"}[ps]
		JOY_BUTTON_DPAD_UP: return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad Right"
	return "Btn %d" % b

## The spec to show for an action on the device in use (falls back to the keyboard
## when the action has no controller input, e.g. movement shows the left stick).
func display_spec(action: String) -> Dictionary:
	if device == PAD:
		var p := primary(action, PAD)
		if not p.is_empty():
			return p
		var d := def_of(action)
		if not d.get("pad_alt", []).is_empty():
			return d["pad_alt"][0]
	return primary(action, KB)

func action_text(action: String) -> String:
	if action == "move":
		return "Left stick" if device == PAD else "WASD"
	if action == "aim":
		return "Right stick" if device == PAD else "Mouse"
	return spec_text(display_spec(action))

## Swaps {action} tokens in story text for the button the player actually uses.
func fmt(text: String) -> String:
	if not text.contains("{"):
		return text
	var out := text
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	for m in re.search_all(text):
		out = out.replace(m.get_string(0), action_text(m.get_string(1)))
	return out
