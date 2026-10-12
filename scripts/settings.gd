extends Node
## Player preferences (autoload as Settings). Stored separately from the save game.

const PATH := "user://settings.json"

var master_volume := 0.8
var fullscreen := false
var screen_shake := true
var dialogue_speed := 1          # 0 slow, 1 normal, 2 fast
var playtest_log := true
var tutorial_tips := true         # pop-up how-to cards the first time something unlocks
var bindings: Dictionary = {}     # action -> {"kb": spec, "pad": spec} overrides

const DIALOGUE_CPS := [26.0, 42.0, 80.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	InputSetup.rebuild()   # InputSetup is ready first, so re-apply any saved remapping

func dialogue_cps() -> float:
	return DIALOGUE_CPS[clampi(dialogue_speed, 0, 2)]

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	# Tests and headless runs keep the log off via the environment variable.
	if OS.get_environment("STORYTENDER_NOSAVE") == "":
		Telemetry.enabled = playtest_log

func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"master_volume": master_volume, "fullscreen": fullscreen, "screen_shake": screen_shake,
			"dialogue_speed": dialogue_speed, "playtest_log": playtest_log,
			"tutorial_tips": tutorial_tips, "bindings": bindings,
		}))

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	master_volume = float(data.get("master_volume", master_volume))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	screen_shake = bool(data.get("screen_shake", screen_shake))
	dialogue_speed = int(data.get("dialogue_speed", dialogue_speed))
	playtest_log = bool(data.get("playtest_log", playtest_log))
	tutorial_tips = bool(data.get("tutorial_tips", tutorial_tips))
	var b = data.get("bindings", {})
	bindings = _fix_bindings(b) if typeof(b) == TYPE_DICTIONARY else {}

## JSON turns every number into a float; bring the saved specs back to ints.
func _fix_bindings(b: Dictionary) -> Dictionary:
	var out := {}
	for action in b.keys():
		var per: Dictionary = {}
		for dev in b[action].keys():
			var spec: Dictionary = b[action][dev]
			var fixed := {}
			for k in spec.keys():
				fixed[k] = int(spec[k]) if typeof(spec[k]) == TYPE_FLOAT and k != "v" else spec[k]
			per[dev] = fixed
		out[action] = per
	return out
