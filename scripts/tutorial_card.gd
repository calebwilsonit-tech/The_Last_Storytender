class_name TutorialCard
extends Control
## A pop-up how-to card with the button glyphs for the device in use. Shown once per
## save, the first time a mechanic unlocks. Interact (or Esc) closes it.

signal closed

var _card: Dictionary = {}
var _font: Font
var _head: Font
var _prev_dialogue := false
var _t := 0.0
var _open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	InputSetup.device_changed.connect(func(_d): queue_redraw())
	InputSetup.bindings_changed.connect(queue_redraw)

func is_open() -> bool:
	return _open

func show_card(card: Dictionary) -> void:
	# Two cards at once used to overwrite each other's "what was the dialogue state" and leave the
	# game frozen when they closed. Later cards now wait their turn.
	while _open:
		await closed
	_card = card
	_t = 0.0
	_open = true
	_prev_dialogue = GameState.in_dialogue
	GameState.in_dialogue = true      # freezes the player the same way a conversation does
	visible = true
	queue_redraw()
	await closed

func _process(delta: float) -> void:
	if _open:
		_t += delta
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _t > 0.35 and (event.is_action_pressed("interact") or MenuInput.back(event) or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_open = false
		visible = false
		GameState.in_dialogue = _prev_dialogue
		closed.emit()
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()   # nothing else reacts while the card is up

func _draw() -> void:
	_draw_body()
	MenuLegend.draw(self, [["confirm","confirm","Got it"]])

func _draw_body() -> void:
	if not _open:
		return
	var a := clampf(_t / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.45 * a))
	var items: Array = _card["items"]
	var h := 230.0 + items.size() * 50.0
	var panel := Rect2(300, 360 - h * 0.5 - (1.0 - a) * 12.0, 680, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PAPER_LIGHT, a)
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45 * a)
	sb.shadow_size = 12
	draw_style_box(sb, panel)
	var x0 := panel.position.x + 40.0
	draw_string(_head, Vector2(x0, panel.position.y + 60.0), _card["title"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 42, Palette.INK)
	draw_line(Vector2(x0, panel.position.y + 76.0), Vector2(panel.end.x - 40.0, panel.position.y + 76.0), Color(Palette.INK, 0.5), 2.0)
	draw_multiline_string(_head, Vector2(x0, panel.position.y + 112.0), _card["body"], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 80.0, 22, 3, Color(Palette.INK, 0.85))
	var y := panel.position.y + 176.0 + 24.0
	var lines := int(ceil(_font.get_string_size(_card["body"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x / (panel.size.x - 80.0)))
	y += maxf(0.0, lines - 2) * 24.0
	for it: Dictionary in items:
		var action: String = it["a"]
		var spec: Dictionary = {"t": "move"} if action == "move" else ({"t": "aim"} if action == "aim" else InputSetup.display_spec(action))
		var w := 0.0
		if action == "aim":
			w = Glyph.draw_text(self, _font, InputSetup.action_text("aim"), Vector2(x0, y), 34.0, InputSetup.device == InputSetup.PAD)
		else:
			w = Glyph.draw(self, _font, spec, Vector2(x0, y), 34.0)
		draw_string(_head, Vector2(x0 + maxf(w, 120.0) + 24.0, y + 8.0), it["t"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.INK)
		y += 50.0
	var foot := "Continue"
	var fw := Glyph.draw(self, _font, InputSetup.display_spec("interact"), Vector2(panel.end.x - 40.0 - 160.0, panel.end.y - 36.0), 30.0)
	draw_string(_head, Vector2(panel.end.x - 40.0 - 160.0 + fw + 12.0, panel.end.y - 27.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(Palette.INK, 0.7))
