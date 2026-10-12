class_name DialogueBox
extends CanvasLayer
## Parchment dialogue panel with typewriter reveal and a clack per letter.
## `await box.play(lines, on_cue)`. E / Space / Enter finishes a line, then advances.

signal _advanced

const CPS := 42.0

var _panel: PanelContainer
var _name_tab: PanelContainer
var _tab_style: StyleBoxFlat
var _name_label: Label
var _text: RichTextLabel
var _hint: Label
var _typing := false
var _waiting := false
var _held := false
var _audio: AudioStreamPlayer
var _clack := Blip.clack()

func _ready() -> void:
	layer = 20
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120.0
	_panel.offset_right = -120.0
	_panel.offset_top = -168.0
	_panel.offset_bottom = -26.0
	_panel.add_theme_stylebox_override("panel", _box(Palette.PAPER_LIGHT, Palette.INK_BROWN, 4, 10, 18))
	root.add_child(_panel)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_font_size_override("italics_font_size", 26)
	_text.add_theme_color_override("default_color", Palette.INK)
	_panel.add_child(_text)

	_name_tab = PanelContainer.new()
	_name_tab.position = Vector2(150, 0)
	_tab_style = _box(Palette.INK_BROWN, Palette.INK, 2, 6, 8)
	_name_tab.add_theme_stylebox_override("panel", _tab_style)
	root.add_child(_name_tab)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Palette.PAPER_LIGHT)
	_name_tab.add_child(_name_label)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_color_override("font_color", Palette.INK_BROWN)
	_hint.add_theme_font_size_override("font_size", 22)
	root.add_child(_hint)

	_audio = AudioStreamPlayer.new()
	_audio.stream = _clack
	_audio.volume_db = -14.0
	add_child(_audio)

func _box(bg: Color, border: Color, bw: int, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	return s

func _process(_d: float) -> void:
	if not visible:
		return
	_name_tab.position = Vector2(_panel.global_position.x + 28.0, _panel.global_position.y - 40.0)
	_hint.position = _panel.global_position + Vector2(_panel.size.x - 52.0, _panel.size.y - 40.0)
	_hint.visible = _waiting and int(Time.get_ticks_msec() / 400.0) % 2 == 0

## Temporarily hide the box (used while a cutscene plays inside a cue).
func hold(on: bool) -> void:
	_held = on
	visible = not on

func play(lines: Array, on_cue: Callable = Callable()) -> void:
	GameState.in_dialogue = true
	visible = true
	for l in lines:
		if l.has("cue") and on_cue.is_valid():
			await on_cue.call(l["cue"])
		await _show_line(l)
	visible = false
	GameState.in_dialogue = false

func _show_line(l: Dictionary) -> void:
	var who: String = l.get("who", "")
	var style: String = l.get("style", "speech")
	_tab_style.bg_color = l.get("tint", Palette.INK_BROWN)
	_name_tab.visible = who != ""
	_name_label.text = who
	var body: String = InputSetup.fmt(l["text"])
	match style:
		"action":
			body = "[i]%s[/i]" % body
			_text.add_theme_color_override("default_color", Color(0.3, 0.22, 0.18))
		"sign":
			_text.add_theme_color_override("default_color", Palette.WOOD.darkened(0.3))
		_:
			_text.add_theme_color_override("default_color", Palette.INK)
	_text.text = body
	_text.visible_characters = 0
	var total := _text.get_total_character_count()
	_typing = true
	_waiting = false
	var plain := _text.get_parsed_text()
	var i := 0
	while i < total and _typing:
		i += 1
		_text.visible_characters = i
		if i % 2 == 0 and plain[i - 1] != " ":
			_audio.pitch_scale = randf_range(0.9, 1.15)
			_audio.play()
		await get_tree().create_timer(1.0 / Settings.dialogue_cps()).timeout
	_text.visible_characters = -1
	_typing = false
	_waiting = true
	await _advanced
	_waiting = false

func _input(event: InputEvent) -> void:
	if not visible or _held:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
		elif _waiting:
			_advanced.emit()
