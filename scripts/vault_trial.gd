class_name VaultTrial
extends CanvasLayer
## Modal that hosts one TrialGames mini-game. Opened by a vault's plinth; emits `finished`
## with true when solved, false when the player fails or walks away.

signal finished(won: bool)

var game: TrialGames.Base
var tier := 1
var _view: Control
var _font: Font
var _head: Font
var _end_timer := 0.0
var _done := false

func _ready() -> void:
	layer = 52
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view)
	_view.draw.connect(_paint)
	_view.gui_input.connect(_on_gui)
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Italic.ttf")

func is_open() -> bool:
	return visible

func open(g: TrialGames.Base) -> void:
	game = g
	tier = g.tier
	_done = false
	_end_timer = 0.0
	visible = true
	get_tree().paused = true
	_view.queue_redraw()

func _close(won: bool) -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	finished.emit(won)

func _process(delta: float) -> void:
	if not visible or game == null:
		return
	game.tick(delta)
	if (game.solved or game.failed) and not _done:
		_done = true
		_end_timer = 1.3
	if _done:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_close(game.solved)
	_view.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or game == null:
		return
	if MenuInput.back(event):
		get_viewport().set_input_as_handled()
		_close(false)
		return
	if _done:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	game.input(event)
	get_viewport().set_input_as_handled()

func _on_gui(event: InputEvent) -> void:
	if _done or game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game.click(event.position)

func _paint() -> void:
	if game == null:
		return
	var vs := _view.size
	_view.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.05, 0.04, 0.08, 0.82))
	var panel := Rect2(vs.x * 0.5 - 430.0, vs.y * 0.5 - 270.0, 860.0, 540.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("efe4c4")
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	_view.draw_style_box(sb, panel)
	var stars := ""
	for i in 4:
		stars += "★" if i < tier else "☆"
	_view.draw_string(_head, panel.position + Vector2(30, 56), game.title(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 40, Palette.INK)
	_view.draw_string(_font, panel.position + Vector2(panel.size.x - 150, 52), stars, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Palette.GOLD.darkened(0.2))
	_view.draw_multiline_string(_head, panel.position + Vector2(30, 88), game.help(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 60.0, 22, 2, Palette.INK_BROWN)
	# tries
	for i in game.max_tries:
		var c := Color("b8402f") if i < game.tries else Color(0.5, 0.45, 0.4, 0.4)
		_view.draw_string(_font, panel.position + Vector2(30 + i * 34, panel.size.y - 24), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, c)
	# timer bar
	if game.time_limit > 0.0:
		var f := clampf(game.time_left / game.time_limit, 0.0, 1.0)
		var bar := Rect2(panel.position.x + 50 + game.max_tries * 34, panel.end.y - 40, 280, 14)
		_view.draw_rect(bar, Color(0, 0, 0, 0.2))
		_view.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color("c9822b") if f > 0.25 else Color("b8402f"))
	MenuLegend.draw(_view, [["move", "move", "Move"], ["confirm", "confirm", "Confirm"], ["back", "back", "Walk away"]], vs)
	var area := Rect2(panel.position + Vector2(30, 120), Vector2(panel.size.x - 60, panel.size.y - 190))
	game.draw(_view, area, _font, _head)
	if game.message != "":
		_view.draw_string(_head, Vector2(panel.position.x + 30, panel.end.y - 62), game.message, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 60.0, 26, Color("8a2f22") if not game.solved else Color("3f7a3a"))
