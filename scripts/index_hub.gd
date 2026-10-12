class_name IndexHub
extends CanvasLayer
## The Index: a hub you can reach from any lit lantern post (like a bonfire's hold), with the
## Workbench (craft from RECIPES), the Narrator's Stall (buy and sell for Mnemosynth) and the
## world map. A Pocket Workbench opens the Workbench alone from the Binder, anywhere.

signal map_requested
signal closed

const PANEL := Rect2(120, 60, 1040, 600)
const ROW_H := 52.0
const VISIBLE_ROWS := 8
const QUIPS_BUY := ["\"A fine choice,\" says the Narrator, who is paid per adjective.", "\"Sold,\" says the Narrator, and then sold again to himself.",
	"\"No refunds,\" says the Narrator. \"Only foreshadowing.\"", "\"It suits you,\" says the Narrator, without looking."]
const QUIPS_SELL := ["\"I'll take it,\" says the Narrator. \"Atmosphere is expensive.\"", "\"Lovely. I'll tell people it was mine.\"", "\"One man's clutter is another man's chapter.\""]

var _mode := "hub"          # hub | craft | shop
var _tab := 0               # shop: 0 buy, 1 sell
var _row := 0
var _scroll := 0
var _pocket := false
var _quip := ""
var _quip_t := 0.0
var _view: Control
var _font: Font
var _head: Font
var _ital: Font
var _hit: Array = []        # [{r, i}] clickable rows
var _t := 0.0

func _ready() -> void:
	layer = 54
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view)
	_view.draw.connect(_paint)
	_view.gui_input.connect(_on_gui)
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	_ital = load("res://assets/fonts/IMFellEnglish-Italic.ttf")

func is_open() -> bool:
	return visible

var _dungeon := false       # inside a memory: no fast travel from here

func open_hub(in_dungeon: bool = false) -> void:
	_dungeon = in_dungeon
	_pocket = false
	_enter("hub")

func open_craft() -> void:
	_pocket = true
	_enter("craft")

func _enter(mode: String) -> void:
	_mode = mode
	_row = 0
	_scroll = 0
	_quip = ""
	if not visible:
		visible = true
		get_tree().paused = true
	if mode == "level" and not GameState.has_flag("levels_intro"):
		# The first time the system is shown you get a handful of points to play with.
		GameState.set_flag("levels_intro")
		GameState.free_points += GameState.FREE_POINTS
		_say("\"%d free points,\" says the Narrator. \"On the house. Choose carefully: after these, every point costs more than the last.\"" % GameState.FREE_POINTS)
		_quip_t = 7.0
	_view.queue_redraw()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _process(delta: float) -> void:
	if visible:
		_t += delta
		_quip_t = maxf(_quip_t - delta, 0.0)
		_view.queue_redraw()

# --- Data for the current list ---------------------------------------------------------------
func _craft_ids() -> Array:
	var ids: Array = ItemCatalog.RECIPES.keys()
	ids.sort_custom(func(a: String, b: String):
		var ca: bool = ItemCatalog.can_craft(a)
		var cb: bool = ItemCatalog.can_craft(b)
		if ca != cb:
			return ca
		var ra: int = ItemCatalog.RARITY_ORDER.find(ItemDB.rarity(a))
		var rb: int = ItemCatalog.RARITY_ORDER.find(ItemDB.rarity(b))
		return ra < rb or (ra == rb and String(ItemDB.info(a)["name"]) < String(ItemDB.info(b)["name"])))
	return ids

func _shop_ids() -> Array:
	var out: Array = []
	if _tab == 0:
		for e: Array in ItemCatalog.SHOP_STOCK:
			out.append(e[0])
	else:
		for k in GameState.inventory.keys():
			var id := String(k)
			var t: String = ItemDB.info(id)["type"]
			if t == "key" or GameState.count(id) <= (1 if GameState.is_equipped(id) else 0):
				continue
			out.append(id)
		out.sort_custom(func(a: String, b: String): return String(ItemDB.info(a)["name"]) < String(ItemDB.info(b)["name"]))
	return out

func _ids() -> Array:
	match _mode:
		"craft": return _craft_ids()
		"shop": return _shop_ids()
	if _mode == "level":
		return GameState.ATTR_ORDER.duplicate()
	return ["level", "workbench", "shop", "leave"] if _dungeon else ["level", "workbench", "shop", "travel", "leave"]

func _stock_rank(id: String) -> int:
	for e: Array in ItemCatalog.SHOP_STOCK:
		if e[0] == id:
			return int(e[1])
	return 1

# --- Actions -----------------------------------------------------------------------------------
func _activate() -> void:
	var ids := _ids()
	if ids.is_empty():
		return
	_row = clampi(_row, 0, ids.size() - 1)
	var id: String = ids[_row]
	match _mode:
		"hub":
			match id:
				"level": _enter("level")
				"workbench": _enter("craft")
				"shop": _enter("shop")
				"travel":
					close()
					map_requested.emit()
				"leave": close()
		"level":
			if GameState.attr(id) >= GameState.ATTR_CAP:
				_say("That one is as strong as it gets.")
			elif GameState.level() >= GameState.LEVEL_CAP:
				_say("Every attribute is at 100. The draft is as revised as it will ever be.")
			elif GameState.spend_point(id):
				_say("%s rises to %d. You are now Level %d." % [GameState.ATTRS[id][0], GameState.attr(id), GameState.level()])
				Telemetry.log_event("level_up", {"attr": id, "level": GameState.level()})
			else:
				_say("You need %d Mnemosynth." % GameState.level_cost())
		"craft":
			if ItemCatalog.craft(id):
				_say("Crafted: %s" % ItemDB.info(id)["name"])
				Telemetry.log_event("craft", {"id": id})
			else:
				_say("You are missing something.")
		"shop":
			if _tab == 0:
				_buy(id)
			else:
				_sell(id)

func _say(t: String) -> void:
	_quip = t
	_quip_t = 3.0

func _buy(id: String) -> void:
	if GameState.rank() < _stock_rank(id):
		_say("\"Not yet,\" says the Narrator. \"Come back when you are Rank %d.\"" % _stock_rank(id))
		return
	var price := ItemCatalog.buy_price(id)
	if GameState.mnemosynth < price:
		_say("\"Short on Mnemosynth,\" says the Narrator, with great sympathy and no discount.")
		return
	if id == "pocket_workbench" and GameState.count(id) > 0:
		_say("\"You already have one. Two benches is a hobby.\"")
		return
	GameState.mnemosynth -= price
	GameState.mnemosynth_changed.emit(GameState.mnemosynth)
	GameState.add_item(id)
	_say(QUIPS_BUY[randi() % QUIPS_BUY.size()])
	Telemetry.log_event("buy", {"id": id, "price": price})

func _sell(id: String) -> void:
	var price := ItemCatalog.sell_price(id)
	if not GameState.remove_item(id):
		return
	GameState.mnemosynth += price
	GameState.mnemosynth_changed.emit(GameState.mnemosynth)
	_say(QUIPS_SELL[randi() % QUIPS_SELL.size()])
	Telemetry.log_event("sell", {"id": id, "price": price})
	_row = clampi(_row, 0, maxi(_ids().size() - 1, 0))

func _back() -> void:
	if _mode == "hub" or _pocket:
		close()
	else:
		var m := _mode
		_enter("hub")
		_row = {"level": 0, "craft": 1}.get(m, 2)

# --- Input -------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.back(event):
		get_viewport().set_input_as_handled()
		_back()
		return
	var d := MenuInput.nav(event)
	if d.y != 0:
		var n := _ids().size()
		if n > 0:
			_row = (_row + d.y + n) % n
			_fit()
	elif d.x != 0 and _mode == "shop":
		_tab = clampi(_tab + d.x, 0, 1)
		_row = 0
		_scroll = 0
	elif MenuInput.accept(event):
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()

func _fit() -> void:
	if _row < _scroll:
		_scroll = _row
	elif _row >= _scroll + VISIBLE_ROWS:
		_scroll = _row - VISIBLE_ROWS + 1

func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for h: Dictionary in _hit:
			if (h["r"] as Rect2).has_point(event.position):
				_row = int(h["i"])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h: Dictionary in _hit:
			if (h["r"] as Rect2).has_point(event.position):
				_row = int(h["i"])
				_activate()
				return
		if _mode == "shop" and Rect2(PANEL.position.x + 30, PANEL.position.y + 78, 380, 34).has_point(event.position):
			_tab = 0 if event.position.x < PANEL.position.x + 220 else 1
			_row = 0
			_scroll = 0
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll = clampi(_scroll + 1, 0, maxi(_ids().size() - VISIBLE_ROWS, 0))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll = clampi(_scroll - 1, 0, maxi(_ids().size() - VISIBLE_ROWS, 0))

# --- Drawing -----------------------------------------------------------------------------------
func _txt(s: String, at: Vector2, size: int, col: Color, font: Font = null, width: float = -1.0) -> void:
	_view.draw_string(font if font else _head, at, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)

func _paint() -> void:
	_hit.clear()
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.03, 0.03, 0.07, 0.8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("efe2c2")
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	_view.draw_style_box(sb, PANEL)
	var title: String = {"hub": "The Index", "craft": "The Workbench", "shop": "The Narrator's Stall", "level": "Revise Your Draft"}[_mode]
	_txt(title, PANEL.position + Vector2(36, 62), 44, Palette.INK)
	_view.draw_line(PANEL.position + Vector2(36, 76), PANEL.position + Vector2(PANEL.size.x - 36, 76), Color(Palette.INK, 0.45), 2.0)
	# Mnemosynth purse
	var purse := "%d Mnemosynth" % GameState.mnemosynth
	var pw := _font.get_string_size(purse, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
	_view.draw_circle(PANEL.position + Vector2(PANEL.size.x - 60 - pw, 50), 8.0, Palette.GOLD)
	_view.draw_string(_font, PANEL.position + Vector2(PANEL.size.x - 46 - pw, 58), purse, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Palette.INK_BROWN)
	match _mode:
		"hub": _paint_hub()
		"level": _paint_level()
		"craft": _paint_list(true)
		"shop": _paint_list(false)
	if _quip_t > 0.0 and _quip != "":
		_view.draw_multiline_string(_ital, PANEL.position + Vector2(36, PANEL.size.y - 30), _quip, HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 72.0, 22, 2, Color(Palette.INK_BROWN, minf(_quip_t, 1.0)))
	var legend: Array = [["move", "move", "Move"], ["confirm", "confirm", {"hub": "Open", "craft": "Craft", "shop": "Buy / Sell", "level": "Raise"}[_mode]]]
	if _mode == "shop":
		legend.append(["t:A D", "t:◄ ►", "Buy / Sell tab"])
	legend.append(["back", "back", "Back" if _mode != "hub" and not _pocket else "Close"])
	MenuLegend.draw(_view, legend)

func _paint_hub() -> void:
	var base := PANEL.position + Vector2(60, 130)
	_txt("Every lantern post keeps a page of the Index.", base + Vector2(0, -8), 22, Palette.INK_BROWN, _ital)
	var rows := [
		["level", "Revise Your Draft", ("%d free points to spend!" % GameState.free_points) if GameState.free_points > 0 else ("Spend Mnemosynth to grow stronger, sturdier, quicker or wiser." if GameState.has_flag("levels_intro") else "Something new: grow stronger, sturdier, quicker or wiser.")],
		["workbench", "The Workbench", "Turn scraps into something better."],
		["shop", "The Narrator's Stall", "Spend and sell Mnemosynth. He narrates every sale."],
		["travel", "The Map", "Walk the page to any post you have lit."],
		["leave", "Leave the Index", "The lantern will keep your place."],
	]
	if _dungeon:
		rows = rows.filter(func(r): return r[0] != "travel")
	for i in rows.size():
		var r := Rect2(base + Vector2(0, 22 + i * 78), Vector2(PANEL.size.x - 120, 66))
		_hit.append({"r": r, "i": i})
		var sel := i == _row
		_view.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.18))
		_view.draw_rect(r, Color("f8f0d8") if sel else Color("f2e8cc"))
		_view.draw_rect(r, Palette.INK_BROWN if sel else Color(Palette.INK_BROWN, 0.5), false, 4.0 if sel else 2.0)
		if sel:
			_view.draw_circle(r.position + Vector2(-24, r.size.y * 0.5), 8.0, Palette.GOLD)
		_txt(rows[i][1], r.position + Vector2(28, 30), 30, Palette.INK)
		_txt(rows[i][2], r.position + Vector2(28, 56), 19, Color(Palette.INK, 0.65), _ital)
	_view.draw_string(_font, PANEL.position + Vector2(PANEL.size.x - 330, PANEL.size.y - 22), "Level %d   ·   Rank %d" % [GameState.level(), GameState.rank()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(Palette.INK, 0.5))

func _paint_level() -> void:
	var ids := _ids()
	_row = clampi(_row, 0, ids.size() - 1)
	var top := PANEL.position + Vector2(36, 112)
	for i in ids.size():
		var key: String = ids[i]
		var r := Rect2(top + Vector2(0, i * 62), Vector2(470, 54))
		_hit.append({"r": r, "i": i})
		var sel := i == _row
		_view.draw_rect(r, Color("f8f0d8") if sel else Color("f2e8cc"))
		_view.draw_rect(r, Palette.INK_BROWN if sel else Color(Palette.INK_BROWN, 0.5), false, 3.4 if sel else 1.8)
		_txt(String(GameState.ATTRS[key][0]), r.position + Vector2(16, 34), 26, Palette.INK)
		var v := GameState.attr(key)
		var bar := Rect2(r.position + Vector2(210, 20), Vector2(190, 14))
		_view.draw_rect(bar, Color(Palette.INK, 0.12))
		_view.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(v) / GameState.ATTR_CAP, bar.size.y)), Palette.GOLD.darkened(0.1))
		_view.draw_string(_font, r.position + Vector2(r.size.x - 58, 34), "%d" % v, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Palette.INK)
	var key: String = ids[_row]
	var x := PANEL.position.x + 560.0
	var y := PANEL.position.y + 120.0
	_txt(String(GameState.ATTRS[key][0]), Vector2(x, y + 20), 36, Palette.INK)
	_view.draw_multiline_string(_head, Vector2(x, y + 60), "Each point: " + String(GameState.ATTRS[key][1]) + ".", HORIZONTAL_ALIGNMENT_LEFT, 440.0, 22, 4, Color(Palette.INK, 0.9))
	_txt("Level %d" % GameState.level(), Vector2(x, y + 190), 40, Palette.INK)
	var cost := GameState.level_cost()
	var free := GameState.free_points > 0
	var ok := (free or GameState.mnemosynth >= cost) and GameState.attr(key) < GameState.ATTR_CAP
	_txt("Free points left: %d" % GameState.free_points if free else "Next point costs %d Mnemosynth" % cost, Vector2(x, y + 230), 24, Color("3f7a3a") if ok else Color("a8402f"))
	_txt("You have %d" % GameState.mnemosynth, Vector2(x, y + 260), 20, Color(Palette.INK, 0.6), _ital)
	_txt("Current bonus from points:", Vector2(x, y + 310), 20, Palette.INK_BROWN, _ital)
	var lines: PackedStringArray = []
	var fx := {}
	for s in ["armor", "dmg", "reach", "regen", "lantern_eff", "speed", "dash_cd", "luck", "mnemo"]:
		var a := GameState.attr_stat(s)
		if absf(a) > 0.0001:
			fx[s] = a
	if GameState.attr("ink") > 0:
		lines.append("+%d maximum ink" % (2 * GameState.attr("ink")))
	if GameState.attr("wit") >= 20:
		lines.append("+%d tries in Vault Trials" % (GameState.attr("wit") / 20))
	var txt := ItemCatalog.fx_text(fx)
	if txt != "":
		lines.append(txt)
	_view.draw_multiline_string(_head, Vector2(x, y + 340), "\n".join(lines) if not lines.is_empty() else "None yet.", HORIZONTAL_ALIGNMENT_LEFT, 440.0, 19, 6, Color(Palette.INK, 0.85))

func _paint_list(craft: bool) -> void:
	var ids := _ids()
	var top := PANEL.position + Vector2(36, 100)
	if not craft:
		for k in 2:
			var tab := Rect2(top.x + k * 190, top.y - 22, 180, 34)
			var on := k == _tab
			_view.draw_rect(tab, Color("f8f0d8") if on else Color(Palette.INK, 0.08))
			_view.draw_rect(tab, Palette.INK_BROWN if on else Color(Palette.INK_BROWN, 0.4), false, 3.0 if on else 1.4)
			_txt("Buy" if k == 0 else "Sell", tab.position + Vector2(70, 25), 22, Palette.INK if on else Color(Palette.INK, 0.5))
		top.y += 28.0
	if ids.is_empty():
		_txt("Nothing here you can sell." if not craft else "No recipes yet.", top + Vector2(10, 50), 24, Color(Palette.INK, 0.6), _ital)
		return
	_row = clampi(_row, 0, ids.size() - 1)
	for k in VISIBLE_ROWS:
		var i := _scroll + k
		if i >= ids.size():
			break
		var id: String = ids[i]
		var r := Rect2(top + Vector2(0, k * ROW_H), Vector2(420, ROW_H - 6.0))
		_hit.append({"r": r, "i": i})
		var sel := i == _row
		var ok := true
		var sub := ""
		if craft:
			ok = ItemCatalog.can_craft(id)
			sub = "x%d" % int(ItemCatalog.RECIPES[id].get("gives", 1)) if int(ItemCatalog.RECIPES[id].get("gives", 1)) > 1 else ""
		elif _tab == 0:
			var locked := GameState.rank() < _stock_rank(id)
			ok = not locked and GameState.mnemosynth >= ItemCatalog.buy_price(id)
			sub = ("Rank %d" % _stock_rank(id)) if locked else "%d" % ItemCatalog.buy_price(id)
		else:
			sub = "+%d  (x%d)" % [ItemCatalog.sell_price(id), GameState.count(id)]
		_view.draw_rect(r, Color("f8f0d8") if sel else Color("f2e8cc"))
		_view.draw_rect(r, ItemDB.rarity_color(id) if sel else Color(ItemDB.rarity_color(id), 0.6), false, 3.4 if sel else 1.8)
		ItemIcon.draw_item(_view, id, r.position + Vector2(28, r.size.y * 0.5), 34.0)
		var col := Palette.INK if ok else Color(Palette.INK, 0.4)
		_txt(String(ItemDB.info(id)["name"]), r.position + Vector2(58, 31), 22, col, _head, 280.0)
		var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x
		_view.draw_string(_font, r.position + Vector2(r.size.x - sw - 12, 31), sub, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, col if not craft else (Color("3f7a3a") if ok else Color(Palette.INK, 0.4)))
	if ids.size() > VISIBLE_ROWS:
		var bar_h := (PANEL.size.y - 220.0) * VISIBLE_ROWS / ids.size()
		var bar_y := top.y + (PANEL.size.y - 220.0 - bar_h) * float(_scroll) / maxi(ids.size() - VISIBLE_ROWS, 1)
		_view.draw_rect(Rect2(top.x + 428, bar_y, 6, bar_h), Color(Palette.INK, 0.3))
	_paint_detail(ids[_row], craft)

func _paint_detail(id: String, craft: bool) -> void:
	var x := PANEL.position.x + 520.0
	var y := PANEL.position.y + 112.0
	var info := ItemDB.info(id)
	ItemIcon.draw_item(_view, id, Vector2(x + 30, y + 24), 56.0)
	_txt(String(info["name"]), Vector2(x + 80, y + 20), 32, Palette.INK)
	_txt("%s  ·  %s" % [ItemDB.rarity(id).capitalize(), ItemDB.type_label(id)], Vector2(x + 80, y + 42), 16, ItemDB.rarity_color(id).darkened(0.1), _ital)
	_view.draw_multiline_string(_head, Vector2(x, y + 84), String(info.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, 520.0, 19, 3, Color(Palette.INK, 0.9))
	_view.draw_multiline_string(_ital, Vector2(x, y + 150), "\"%s\"" % info.get("flavor", ""), HORIZONTAL_ALIGNMENT_LEFT, 520.0, 18, 2, Color(Palette.INK_BROWN, 0.85))
	var by := y + 210.0
	if craft:
		_txt("Needs", Vector2(x, by), 22, Palette.INK)
		var k := 0
		for need: String in ItemCatalog.RECIPES[id]["needs"]:
			var n: int = ItemCatalog.RECIPES[id]["needs"][need]
			var have := GameState.count(need)
			var ok := have >= n
			ItemIcon.draw_item(_view, need, Vector2(x + 20, by + 34 + k * 40), 30.0)
			_txt(String(ItemDB.info(need)["name"]), Vector2(x + 48, by + 40 + k * 40), 20, Palette.INK)
			var cnt := "%d / %d" % [have, n]
			_view.draw_string(_font, Vector2(x + 340, by + 40 + k * 40), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("3f7a3a") if ok else Color("a8402f"))
			k += 1
	elif _tab == 0:
		_txt("Price: %d Mnemosynth" % ItemCatalog.buy_price(id), Vector2(x, by), 24, Palette.INK)
		var owned := GameState.count(id)
		if owned > 0:
			_txt("You carry %d" % owned, Vector2(x, by + 30), 18, Color(Palette.INK, 0.6), _ital)
	else:
		_txt("The Narrator pays: %d Mnemosynth" % ItemCatalog.sell_price(id), Vector2(x, by), 24, Palette.INK)
	var fx: Dictionary = info.get("fx", {})
	if not fx.is_empty():
		_view.draw_multiline_string(_head, Vector2(x, PANEL.position.y + PANEL.size.y - 80.0), "Worn: " + ItemCatalog.fx_text(fx), HORIZONTAL_ALIGNMENT_LEFT, 520.0, 18, 2, Color("3f5a8a"))
