class_name InventoryScreen
extends CanvasLayer
## The binder. Left page: the Storytender (paper doll) with equipped gear and stats.
## Right page: the card catalog of everything you carry. Tab / I / Esc to close.

signal use_requested(id: String)

const COLS := 4
const CARD := Vector2(104, 104)
const GAP := 8.0
const GRID_POS := Vector2(684, 150)

var _view: Control
var _doll: Player
var _sub: SubViewport
var _items: Array[String] = []
var _sel := 0
var _scroll := 0
var _hover := -1
var _buttons: Array[Dictionary] = []   # {rect, label, act}
var _slot_rects := {}                   # "binding"/"amulet" -> Rect2
var _diff_rect := Rect2()
var _font: Font
var _ital: Font

func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view)
	_view.draw.connect(_paint)
	_view.gui_input.connect(_on_gui)
	_font = ThemeDB.get_default_theme().default_font
	_ital = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	# Paper-doll viewport hosting a preview Storytender wearing whatever is equipped.
	var cont := SubViewportContainer.new()
	cont.position = Vector2(118, 130)
	cont.size = Vector2(300, 380)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(cont)
	_sub = SubViewport.new()
	_sub.size = Vector2i(300, 380)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.process_mode = Node.PROCESS_MODE_ALWAYS
	cont.add_child(_sub)
	_doll = Player.new()
	_doll.preview = true
	_doll.process_mode = Node.PROCESS_MODE_ALWAYS
	_doll.position = Vector2(150, 330)
	_doll.scale = Vector2(3.2, 3.2)
	_sub.add_child(_doll)
	GameState.inventory_changed.connect(_refresh)

func is_open() -> bool:
	return visible

func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _refresh() -> void:
	var ids: Array[String] = []
	for k in GameState.inventory.keys():
		ids.append(String(k))
	var order := {"consumable": 0, "binding": 1, "amulet": 2, "material": 3, "key": 4}
	ids.sort_custom(func(a: String, b: String):
		var ta: int = order.get(ItemDB.info(a)["type"], 9)
		var tb: int = order.get(ItemDB.info(b)["type"], 9)
		return ta < tb or (ta == tb and ItemDB.info(a)["name"] < ItemDB.info(b)["name"]))
	_items = ids
	_sel = clampi(_sel, 0, maxi(_items.size() - 1, 0))
	if _view:
		_view.queue_redraw()

func _selected() -> String:
	return _items[_sel] if _sel < _items.size() else ""

# --- Input ---------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_right"):
		_move(1, 0)
	elif event.is_action_pressed("ui_left"):
		_move(-1, 0)
	elif event.is_action_pressed("ui_down"):
		_move(0, 1)
	elif event.is_action_pressed("ui_up"):
		_move(0, -1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_primary()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		_set_quick()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_D:
		GameState.toggle_difficulty()
		_view.queue_redraw()
	else:
		return
	get_viewport().set_input_as_handled()

func _move(dx: int, dy: int) -> void:
	if _items.is_empty():
		return
	_sel = clampi(_sel + dx + dy * COLS, 0, _items.size() - 1)
	var row := _sel / COLS
	if row < _scroll:
		_scroll = row
	elif row >= _scroll + 3:
		_scroll = row - 2
	_view.queue_redraw()

func _primary() -> void:
	var id := _selected()
	if id == "":
		return
	match ItemDB.info(id)["type"]:
		"consumable":
			if id == "eraser_crumbs":
				close()
			use_requested.emit(id)
		"binding", "amulet":
			GameState.toggle_equip(id)
	_view.queue_redraw()

func _set_quick() -> void:
	var id := _selected()
	if id != "" and ItemDB.info(id)["type"] == "consumable":
		GameState.quick_slot = id
		GameState.inventory_changed.emit()
		GameState.save_game()

func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _card_at(event.position)
		if h != _hover:
			_hover = h
			_view.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(event.position)
		if i >= 0:
			if i == _sel:
				_primary()
			_sel = i
			_view.queue_redraw()
			return
		if _diff_rect.has_point(event.position):
			GameState.toggle_difficulty()
			_view.queue_redraw()
			return
		for b in _buttons:
			if b["rect"].has_point(event.position):
				b["act"].call()
				return
		for slot in _slot_rects:
			if _slot_rects[slot].has_point(event.position):
				var worn: String = GameState.equipment[slot]
				if worn != "":
					GameState.toggle_equip(worn)
				return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll = clampi(_scroll + 1, 0, maxi(ceili(_items.size() / float(COLS)) - 3, 0))
		_view.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll = maxi(_scroll - 1, 0)
		_view.queue_redraw()

func _card_rect(i: int) -> Rect2:
	var row := i / COLS - _scroll
	var col := i % COLS
	return Rect2(GRID_POS + Vector2(col * (CARD.x + GAP), row * (CARD.y + GAP)), CARD)

func _card_at(p: Vector2) -> int:
	for i in _items.size():
		var row := i / COLS - _scroll
		if row < 0 or row >= 3:
			continue
		if _card_rect(i).has_point(p):
			return i
	return -1

# --- Painting ----------------------------------------------------------------------------------------
func _txt(s: String, pos: Vector2, size: int, col: Color, italic := false) -> void:
	_view.draw_string(_ital if italic else _font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, col)

func _wrap(s: String, pos: Vector2, width: float, size: int, col: Color, italic := false) -> void:
	_view.draw_multiline_string(_ital if italic else _font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, 4, col)

func _paint() -> void:
	_buttons.clear()
	_slot_rects.clear()
	var v := _view
	v.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.62))
	# Binder cover with a thick leather edge.
	var cover := StyleBoxFlat.new()
	cover.bg_color = Color("4a3322")
	cover.border_color = Color("1e140c")
	cover.set_border_width_all(5)
	cover.set_corner_radius_all(20)
	cover.shadow_color = Color(0, 0, 0, 0.5)
	cover.shadow_size = 14
	v.draw_style_box(cover, Rect2(52, 36, 1176, 648))
	# Two pages.
	for r in [Rect2(84, 64, 530, 592), Rect2(666, 64, 530, 592)]:
		v.draw_rect(r, Palette.PAPER_LIGHT)
		v.draw_rect(r, Color("1e140c"), false, 2.0)
		var y: float = r.position.y + 54.0
		while y < r.end.y - 8.0:
			v.draw_line(Vector2(r.position.x + 12.0, y), Vector2(r.end.x - 12.0, y), Color(0.45, 0.55, 0.7, 0.13), 1.0)
			y += 28.0
	# Rings through the spine.
	for ry in [150.0, 360.0, 570.0]:
		v.draw_rect(Rect2(616, ry - 8.0, 48, 16), Color("2a2a30"))
		v.draw_arc(Vector2(640, ry), 15.0, 0.0, TAU, 18, Color("9aa0ad"), 5.0, true)
	_paint_left()
	_paint_right()
	_txt("Tab / Esc close   ·   arrows or mouse   ·   Enter use / equip   ·   Q set quick-use (F)", Vector2(90, 678), 16, Color("d8c8a8"))

func _paint_left() -> void:
	var ink := Palette.INK
	_txt("The Storytender", Vector2(108, 108), 36, ink)
	_view.draw_line(Vector2(108, 118), Vector2(500, 118), Color(ink, 0.5), 2.0)
	# Doll plinth.
	_view.draw_set_transform(Vector2(268, 468), 0.0, Vector2(1, 0.4))
	_view.draw_circle(Vector2.ZERO, 70.0, Color(0, 0, 0, 0.12))
	_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Equipment slots as index-card sockets.
	_slot("binding", "Binding", Rect2(442, 150, 150, 98))
	_slot("amulet", "Amulet", Rect2(442, 262, 150, 98))
	# Tools.
	_txt("Tools", Vector2(442, 392), 22, ink)
	_view.draw_line(Vector2(442, 398), Vector2(592, 398), Color(ink, 0.4), 1.5)
	_txt("Lantern", Vector2(442, 424), 19, Color("1f6b87"))
	_wrap("Beam of narrative importance.", Vector2(442, 442), 150.0, 15, Color(ink, 0.8), true)
	var quill := GameState.has_flag("has_quill")
	_txt("Quill" if quill else "Quill (not yet forged)", Vector2(442, 486), 19, Color("1f6b87") if quill else Color(ink, 0.45))
	if quill:
		_wrap("Rewrites what it touches.", Vector2(442, 504), 150.0, 15, Color(ink, 0.8), true)
	# Stats from equipment.
	var armor := GameState.equipped_stat("armor")
	var spd := GameState.equipped_stat("speed")
	var dash := GameState.equipped_stat("dash_cd")
	var inv := GameState.equipped_stat("invuln")
	var lines := [
		"Damage taken   %s" % _pct(-armor),
		"Move speed    %s" % _pct(spd),
		"Dash cooldown   %s" % _pct(dash),
		"Grace after a hit   %.1fs" % (0.9 + inv),
	]
	for i in lines.size():
		_txt(lines[i], Vector2(108, 546 + i * 24), 18, Color(ink, 0.9))
	# Difficulty: Story is gentle (no death penalty); Normal asks you to take care.
	_diff_rect = Rect2(372, 548, 220, 32)
	_view.draw_rect(_diff_rect, Palette.INK_BROWN)
	_view.draw_rect(_diff_rect, Palette.INK, false, 2.0)
	_txt("Difficulty: %s" % ("Story" if GameState.is_story() else "Normal"), Vector2(384, 570), 19, Palette.PAPER_LIGHT)
	_wrap("Story: gentler, no penalty for crumpling." if GameState.is_story() else "Normal: crumpling costs Mnemosynth and restarts the room.  (D)", Vector2(372, 598), 220.0, 13, Color(Palette.INK, 0.65), true)
	_txt("Layer 0 · The Sketch      Layer 2 · Bindings      Layer 4 · Tools", Vector2(108, 648), 14, Color(ink, 0.45), true)

func _pct(x: float) -> String:
	if absf(x) < 0.001:
		return "no change"
	return "%+d%%" % int(round(x * 100.0))

func _slot(slot: String, label: String, r: Rect2) -> void:
	_slot_rects[slot] = r
	var worn: String = GameState.equipment[slot]
	_view.draw_rect(r, Color("efe3c4") if worn != "" else Color(0.9, 0.85, 0.7, 0.4))
	_view.draw_rect(r, Palette.INK_BROWN if worn != "" else Color(Palette.INK_BROWN, 0.5), false, 2.4)
	_txt(label, r.position + Vector2(8, 20), 17, Color(Palette.INK, 0.7))
	if worn == "":
		_txt("empty", r.position + Vector2(r.size.x * 0.5 - 22, 62), 18, Color(Palette.INK, 0.35), true)
	else:
		ItemIcon.draw_item(_view, worn, r.position + Vector2(r.size.x * 0.5, 54), 48.0)
		_txt(ItemDB.info(worn)["name"], r.position + Vector2(8, r.size.y - 8), 14, Palette.INK)

func _paint_right() -> void:
	var ink := Palette.INK
	_txt("Card Catalog", Vector2(692, 108), 36, ink)
	_view.draw_line(Vector2(692, 118), Vector2(1080, 118), Color(ink, 0.5), 2.0)
	_txt("◆ %d" % GameState.mnemosynth, Vector2(1090, 108), 26, Palette.GOLD.darkened(0.3))
	if _items.is_empty():
		_wrap("Nothing here yet. Cards are filed as you find them: Eraser Crumbs, Ink Vials, Bindings, and stranger things.", Vector2(692, 200), 440.0, 20, Color(ink, 0.7), true)
		return
	for i in _items.size():
		var row := i / COLS - _scroll
		if row < 0 or row >= 3:
			continue
		_card(i)
	if _items.size() > COLS * 3:
		_txt("scroll ↕", Vector2(1100, 140), 14, Color(ink, 0.5), true)
	_details()

func _card(i: int) -> void:
	var id := _items[i]
	var r := _card_rect(i)
	var sel := i == _sel
	if sel:
		r.position.y -= 4.0
	_view.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.18))
	_view.draw_rect(r, Color("fbf3dc"))
	# Index-card look: red header rule and faint blue lines.
	_view.draw_line(r.position + Vector2(0, 22), r.position + Vector2(r.size.x, 22), Color("d96a6a", 0.7), 1.6)
	for k in 3:
		_view.draw_line(r.position + Vector2(0, 62 + k * 18), r.position + Vector2(r.size.x, 62 + k * 18), Color(0.45, 0.55, 0.75, 0.2), 1.0)
	_view.draw_rect(r, Palette.INK_BROWN if sel else Color(Palette.INK_BROWN, 0.55), false, 3.2 if sel else 1.6)
	if i == _hover and not sel:
		_view.draw_rect(r, Color(Palette.CYAN, 0.12))
	ItemIcon.draw_item(_view, id, r.position + Vector2(r.size.x * 0.5, 52), 44.0)
	var nm: String = ItemDB.info(id)["name"]
	var fs := 13
	while fs > 9 and _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > r.size.x - 8.0:
		fs -= 1
	_txt(nm, r.position + Vector2(5, 16), fs, Palette.INK)
	var n := GameState.count(id)
	if n > 1 or ItemDB.info(id)["type"] in ["consumable", "material"]:
		_txt("×%d" % n, r.position + Vector2(r.size.x - 34, r.size.y - 8), 18, Palette.INK)
	if GameState.is_equipped(id):
		_view.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 22), Vector2(46, 16)), Palette.GOLD)
		_txt("WORN", r.position + Vector2(8, r.size.y - 9), 12, Palette.INK)
	if GameState.quick_slot == id:
		_txt("F", r.position + Vector2(r.size.x - 18, 40), 20, Palette.CRITIC_RED)

func _details() -> void:
	var id := _selected()
	if id == "":
		return
	var info := ItemDB.info(id)
	var base := Vector2(692, 506)
	_txt(info["name"], base, 26, Palette.INK)
	_txt(ItemDB.type_label(id), base + Vector2(0, 19), 15, Color(Palette.INK, 0.55), true)
	_wrap(info["desc"], base + Vector2(0, 42), 450.0, 17, Color(Palette.INK, 0.9))
	_wrap("\"%s\"" % info["flavor"], base + Vector2(0, 90), 450.0, 17, Color(Palette.INK_BROWN, 0.9), true)
	var x := 692.0
	var t: String = info["type"]
	if t == "consumable":
		x = _button(x, "Use", func(): _primary())
		x = _button(x, "Set quick-use (F)", func(): _set_quick())
	elif t == "binding" or t == "amulet":
		x = _button(x, "Unequip" if GameState.is_equipped(id) else "Equip", func(): _primary())

func _button(x: float, label: String, act: Callable) -> float:
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x + 28.0
	var r := Rect2(x, 622.0, w, 30.0)
	_view.draw_rect(r, Palette.INK_BROWN)
	_view.draw_rect(r, Palette.INK, false, 2.0)
	_txt(label, Vector2(x + 14.0, 643.0), 18, Palette.PAPER_LIGHT)
	_buttons.append({"rect": r, "label": label, "act": act})
	return x + w + 10.0
