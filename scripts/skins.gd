extends CanvasLayer
## Art-style "Skins" (autoload as Skins). A skin is a look for the whole world: the default is the
## hand-built Cut Paper style; the others are screen filters so you can compare directions on the
## real game before committing. Screen filters: F9. Character art styles (ArtStyles): F7.
## The filter sits under the HUD and menus (they are never restyled) and costs nothing when off.
## A skin may also name a sprite folder (res://skins/<id>/) for hand-made character art later.

const LIST := [
	{"id": "cutpaper", "name": "Cut Paper (default)", "style": 0},
	{"id": "sketch", "name": "Pencil Sketch", "style": 1},
	{"id": "watercolor", "name": "Watercolor", "style": 2},
	{"id": "pixel", "name": "Pixel", "style": 3},
	{"id": "noir", "name": "Ink Noir", "style": 4},
	{"id": "print", "name": "Picture Book Print", "style": 5},
]

signal changed(id: String)

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 4                      # above the world (0), below the HUD (10) and every menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/skin.gdshader")
	_rect.material = _mat
	add_child(_rect)
	apply()

## The active character art style (null = the original procedural art).
func art() -> ArtStyle:
	return ArtStyles.get_style(Settings.art_style)

func cycle_art(dir: int = 1) -> void:
	var i := (ArtStyles.index_of(Settings.art_style) + dir + ArtStyles.ORDER.size()) % ArtStyles.ORDER.size()
	Settings.art_style = ArtStyles.ORDER[i]
	Settings.save_settings()
	changed.emit(Settings.art_style)
	Settings.quality_changed.emit()    # statics (props, tiles, baked trees) repaint in the new style

func art_name() -> String:
	return String(ArtStyles.NAMES.get(Settings.art_style, "Original"))

func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0

func current_name() -> String:
	return String(LIST[index_of(Settings.skin)]["name"])

func apply() -> void:
	var s: Dictionary = LIST[index_of(Settings.skin)]
	var st := int(s["style"])
	_rect.visible = st != 0
	_mat.set_shader_parameter("style", st)
	_mat.set_shader_parameter("screen_size", Vector2(get_viewport().get_visible_rect().size))
	changed.emit(String(s["id"]))

func cycle(dir: int = 1) -> void:
	var i := (index_of(Settings.skin) + dir + LIST.size()) % LIST.size()
	Settings.skin = String(LIST[i]["id"])
	Settings.save_settings()
	apply()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var hud: Object = get_tree().current_scene.get("_hud") if get_tree().current_scene else null
		if event.keycode == KEY_F9:
			cycle(1)
			if hud:
				hud.toast("Screen filter: %s" % current_name())
		elif event.keycode == KEY_F7:
			cycle_art(1)
			if hud:
				hud.toast("Character art: %s" % art_name())
