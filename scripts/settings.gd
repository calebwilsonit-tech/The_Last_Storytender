extends Node
## Player preferences (autoload as Settings). Stored separately from the save game.

const PATH := "user://settings.json"

signal quality_changed

var master_volume := 0.8
var fullscreen := false
var screen_shake := true
var dialogue_speed := 1          # 0 slow, 1 normal, 2 fast
var playtest_log := true
var tutorial_tips := true         # pop-up how-to cards the first time something unlocks
var bindings: Dictionary = {}     # action -> {"kb": spec, "pad": spec} overrides

const DIALOGUE_CPS := [26.0, 42.0, 80.0]

# --- Graphics ---------------------------------------------------------------------------------
## Every option is an index into its list of choices. "cost" is how much it helps a slow computer.
const GFX := [
	{"id": "density", "label": "Pixel density", "opts": ["Standard (1280x720)", "Sharp (native)"], "cost": "Big saving on hi-DPI / Retina screens", "impact": 3},
	{"id": "paper", "label": "Paper background", "opts": ["Flat color", "Low", "Medium", "High"], "cost": "Resolution of the animated parchment", "impact": 3},
	{"id": "paper_detail", "label": "Paper detail", "opts": ["Grain only", "Grain + fibers", "Full (handwriting)"], "cost": "Extra layers in the parchment shader", "impact": 2},
	{"id": "grass", "label": "Grass and flowers", "opts": ["Off", "On"], "cost": "Many small strokes on the ground", "impact": 2},
	{"id": "outlines", "label": "Tile outlines", "opts": ["Off", "On"], "cost": "A pencil line around every ground tile", "impact": 2},
	{"id": "strata", "label": "Cliff page-edge lines", "opts": ["Off", "On"], "cost": "Layered lines on cliffs", "impact": 1},
	{"id": "refresh", "label": "Ground refresh", "opts": ["Economy", "Normal", "Smooth"], "cost": "How often the ground repaints as you move", "impact": 2},
	{"id": "distance", "label": "Draw distance", "opts": ["Short", "Normal", "Long"], "cost": "Short may show tiles popping in at the edges", "impact": 2},
	{"id": "sway", "label": "Tree sway", "opts": ["Off", "On"], "cost": "Animates every tree on screen", "impact": 2},
	{"id": "shadows", "label": "Shadows", "opts": ["Off", "On"], "cost": "Blob shadows under objects", "impact": 1},
	{"id": "glow", "label": "Glow effects", "opts": ["Off", "On"], "cost": "Halos around the Lantern, crystals and posts", "impact": 1},
	{"id": "vignette", "label": "Screen edge shading", "opts": ["Off", "On"], "cost": "Darkens the corners of the page", "impact": 1},
	{"id": "smooth", "label": "Smooth line edges", "opts": ["Off", "On"], "cost": "Anti-aliasing on hand-drawn outlines", "impact": 2},
	{"id": "fps", "label": "Frame rate limit", "opts": ["30", "60", "120", "Unlimited"], "cost": "Lower uses less power and heat", "impact": 1},
	{"id": "vsync", "label": "VSync", "opts": ["Off", "On"], "cost": "Stops screen tearing; can add input delay", "impact": 0},
	{"id": "show_fps", "label": "Show FPS counter", "opts": ["Off", "On"], "cost": "A small number in the corner", "impact": 0},
]
const PRESET_NAMES := ["Low", "Balanced", "High", "Custom"]
const PRESETS := {
	0: {"density": 0, "paper": 1, "paper_detail": 0, "grass": 0, "outlines": 0, "strata": 0, "refresh": 0, "distance": 0, "sway": 0, "shadows": 0, "glow": 0, "vignette": 0, "smooth": 0, "fps": 1, "vsync": 1, "show_fps": 0},
	1: {"density": 0, "paper": 2, "paper_detail": 1, "grass": 1, "outlines": 1, "strata": 1, "refresh": 1, "distance": 1, "sway": 0, "shadows": 1, "glow": 1, "vignette": 1, "smooth": 0, "fps": 1, "vsync": 1, "show_fps": 0},
	2: {"density": 1, "paper": 3, "paper_detail": 2, "grass": 1, "outlines": 1, "strata": 1, "refresh": 2, "distance": 2, "sway": 1, "shadows": 1, "glow": 1, "vignette": 1, "smooth": 1, "fps": 1, "vsync": 1, "show_fps": 0},
}
var preset := -1                 # 0 Low, 1 Balanced, 2 High, 3 Custom, -1 = pick for this computer on first run
var gfx: Dictionary = {}         # option id -> index
var _fps_label: Label

func g(id: String) -> int:
	return int(gfx.get(id, PRESETS[2].get(id, 0)))

func gfx_on(id: String) -> bool:
	return g(id) == 1

func set_preset(p: int) -> void:
	preset = clampi(p, 0, 2)
	gfx = (PRESETS[preset] as Dictionary).duplicate()
	apply()

func set_gfx(id: String, v: int) -> void:
	gfx[id] = v
	preset = 3
	for p in 3:
		var same := true
		for k in (PRESETS[p] as Dictionary).keys():
			if g(k) != int(PRESETS[p][k]):
				same = false
		if same:
			preset = p
	apply()

## 1.0 is the paper background at native size; the value is the size of its render target.
func paper_scale() -> float:
	return [0.0, 0.25, 0.4, 0.5][clampi(g("paper"), 0, 3)]

func cull_half() -> Vector2:
	return [Vector2(440.0, 270.0), Vector2(500.0, 330.0), Vector2(620.0, 420.0)][clampi(g("distance"), 0, 2)]

func ground_move_threshold() -> float:
	return [110.0, 56.0, 28.0][clampi(g("refresh"), 0, 2)]

func ground_idle_interval() -> float:
	return [0.6, 0.25, 0.1][clampi(g("refresh"), 0, 2)]

func _detect_preset() -> int:
	if DisplayServer.get_name() == "headless":
		return 2
	var scale := DisplayServer.screen_get_scale()
	return 1 if (scale > 1.4 or OS.get_name() == "macOS") else 2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	InputSetup.rebuild()   # InputSetup is ready first, so re-apply any saved remapping

func dialogue_cps() -> float:
	return DIALOGUE_CPS[clampi(dialogue_speed, 0, 2)]

func apply() -> void:
	if preset < 0:
		set_preset_silent(_detect_preset())
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		var w := get_window()
		if g("density") == 1:
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		else:
			# Render at the base 1280x720 and scale up: far fewer pixels on a Retina screen.
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			w.content_scale_size = Vector2i(1280, 720)
		Engine.max_fps = [30, 60, 120, 0][clampi(g("fps"), 0, 3)]
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g("vsync") == 1 else DisplayServer.VSYNC_DISABLED)
	_update_fps_label()
	# Tests and headless runs keep the log off via the environment variable.
	if OS.get_environment("STORYTENDER_NOSAVE") == "":
		Telemetry.enabled = playtest_log
	quality_changed.emit()

func set_preset_silent(p: int) -> void:
	preset = clampi(p, 0, 2)
	gfx = (PRESETS[preset] as Dictionary).duplicate()

func _update_fps_label() -> void:
	if g("show_fps") != 1:
		if _fps_label:
			_fps_label.get_parent().visible = false
		return
	if _fps_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 120
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_fps_label = Label.new()
		_fps_label.position = Vector2(1180, 4)
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_color", Color("1c242e"))
		_fps_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		_fps_label.add_theme_constant_override("outline_size", 5)
		layer.add_child(_fps_label)
	_fps_label.get_parent().visible = true

func _process(_delta: float) -> void:
	if _fps_label and _fps_label.get_parent().visible:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()

func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"master_volume": master_volume, "fullscreen": fullscreen, "screen_shake": screen_shake,
			"dialogue_speed": dialogue_speed, "playtest_log": playtest_log,
			"tutorial_tips": tutorial_tips, "preset": preset, "gfx": gfx, "bindings": bindings,
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
	preset = int(data.get("preset", preset))
	var gd = data.get("gfx", {})
	if typeof(gd) == TYPE_DICTIONARY and not gd.is_empty():
		gfx = {}
		for k in gd.keys():
			gfx[str(k)] = int(gd[k])
	elif preset >= 0 and preset < 3:
		gfx = (PRESETS[preset] as Dictionary).duplicate()
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
