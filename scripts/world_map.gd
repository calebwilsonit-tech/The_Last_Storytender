class_name WorldMap
extends Control
## The chapter map: an unfolded parchment showing the world as you have discovered it.
## Chapters are listed on the left (only the Prologue exists so far); the map shows the
## regions you have visited, your lit lantern posts, and where you are. Pick a lit post
## to travel there. Up/Down/Left/Right move between posts, Interact travels, Back closes.

signal closed
signal travel_requested(waypoint_id: String)

const CHAPTERS := [
	{"id": "prologue", "name": "The Prologue", "sub": "Prologue Plains · Thistledown", "open": true},
	{"id": "c1", "name": "Chapter One", "sub": "Plot-Twist Peaks", "open": false},
	{"id": "c2", "name": "Chapter Two", "sub": "Purple Prose Swamp", "open": false},
	{"id": "c3", "name": "Chapter Three", "sub": "The Final Chapter", "open": false},
]
## Fast travel only makes sense across real distance: a post closer than this is just a short walk.
const MIN_TRAVEL := 40.0
const MAP_ORIGIN := Vector2(480, 150)
const CELL_X := 3.0
const CELL_Y := 1.5

var _font: Font
var _head: Font
var _tex: ImageTexture
var _ox := 0.0
var _player_cell := Vector2i.ZERO
var _sel := 0                      # selected waypoint index (into _posts)
var _posts: Array[Dictionary] = [] # lit waypoints
var _labels: Array[Dictionary] = []
var _chapter := 0
var _note := ""
var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.get_default_theme().default_font
	_head = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	InputSetup.device_changed.connect(func(_d): queue_redraw())

func is_open() -> bool:
	return visible

func open(player_cell: Vector2i) -> void:
	_player_cell = player_cell
	_note = ""
	_chapter = 0
	_build()
	visible = true
	get_tree().paused = true
	queue_redraw()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

# --- Building the picture -----------------------------------------------------------------------
func _kind_color(ch: String, h: int, region: String) -> Color:
	var base := Color("a9c78a")
	match ch:
		".": base = Color("a9c78a")
		",": base = Color("d9c298")
		"T": base = Color("6f9a62")
		"#": base = Color("4a4358")
		"C": base = Color("e6c15a")
		"H", "F": base = Color("8c7a66")
		"G": base = Color("f6f3ea")
		_: base = Color("a9c78a") if region != "t" else Color("d9c298")
	return base.lightened(0.07 * h)

func _build() -> void:
	var rows: Array[String] = PrologueMap.ROWS
	var hrows: Array[String] = PrologueMap.HEIGHTS
	var wcells := rows[0].length()
	var hcells := rows.size()
	_ox = float(hcells) * CELL_X + 6.0
	var img := Image.create(int((wcells + hcells) * CELL_X + 14.0), int((wcells + hcells) * CELL_Y + 12.0), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var sums := {}
	for y in hcells:
		for x in wcells:
			var ch := rows[y][x]
			if ch == " ":
				continue
			var r := PrologueMap.region_at(Vector2i(x, y))
			if not GameState.region_seen(r) and not (r == "o" and GameState.region_seen("m")) and not (r == "m" and GameState.region_seen("s")):
				continue
			var hc := hrows[y][x]
			var h := int(hc) if hc.is_valid_int() else 0
			var col := _kind_color(ch, h, r)
			var px := int((x - y) * CELL_X + _ox)
			var py := int((x + y) * CELL_Y)
			img.fill_rect(Rect2i(px - 2, py, 5, 3), col)
			if not sums.has(r):
				sums[r] = [Vector2.ZERO, 0]
			sums[r][0] += Vector2(x, y)
			sums[r][1] += 1
	_tex = ImageTexture.create_from_image(img)
	_labels.clear()
	for r in sums.keys():
		var c: Vector2 = sums[r][0] / float(sums[r][1])
		_labels.append({"name": PrologueMap.REGIONS.get(r, ""), "at": _to_map(c)})
	_posts.clear()
	for wp: Dictionary in PrologueMap.WAYPOINTS:
		var cell := Vector2i(int(wp["cell"][0]), int(wp["cell"][1]))
		if GameState.waypoint_lit(wp["id"]):
			_posts.append({"id": wp["id"], "name": wp["name"], "cell": cell})
	_sel = 0
	var best := INF
	for i in _posts.size():
		var d := Vector2(_posts[i]["cell"] - _player_cell).length()
		if d < best:
			best = d
			_sel = i

func _to_map(c: Vector2) -> Vector2:
	return MAP_ORIGIN + Vector2((c.x - c.y) * CELL_X + _ox, (c.x + c.y) * CELL_Y)

# --- Input --------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.back(event) or event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
		return
	var d := MenuInput.nav(event)
	if d != Vector2i.ZERO and not _posts.is_empty():
		_move_selection(d)
		get_viewport().set_input_as_handled()
	elif MenuInput.accept(event):
		get_viewport().set_input_as_handled()
		_travel()
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _move_selection(d: Vector2i) -> void:
	# Screen directions on the isometric map: pick the nearest post roughly that way.
	var here := _to_map(Vector2(_posts[_sel]["cell"]))
	var best := -1
	var best_score := INF
	for i in _posts.size():
		if i == _sel:
			continue
		var v := _to_map(Vector2(_posts[i]["cell"])) - here
		var along := v.x * d.x + v.y * d.y
		if along <= 4.0:
			continue
		var across := absf(v.x * d.y) + absf(v.y * d.x)
		var score := v.length() + across * 1.2
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_sel = best

func _travel() -> void:
	if _chapter != 0:
		_note = "That chapter has not been written yet."
		return
	if _posts.is_empty():
		_note = "Light a lantern post out in the world, and you can travel to it from here."
		return
	var dist := Vector2(_posts[_sel]["cell"] - _player_cell).length()
	if dist < MIN_TRAVEL:
		_note = "That post is only a short walk from here. Travel is for the long way round."
		return
	var id: String = _posts[_sel]["id"]
	close()
	travel_requested.emit(id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in CHAPTERS.size():
			if Rect2(60, 170 + i * 92, 360, 80).has_point(event.position):
				_chapter = i
				_note = "" if CHAPTERS[i]["open"] else "That chapter has not been written yet."
				return
		for i in _posts.size():
			if _to_map(Vector2(_posts[i]["cell"])).distance_to(event.position) < 14.0:
				if _sel == i:
					_travel()
				_sel = i
				return

# --- Drawing --------------------------------------------------------------------------------------
func _draw() -> void:
	_draw_body()
	MenuLegend.draw(self, [["move","move","Move"], ["confirm","confirm","Travel"], ["back","back","Close"]])

func _draw_body() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.02, 0.02, 0.05, 0.78))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("efe2c2")
	sb.border_color = Palette.INK_BROWN
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	draw_style_box(sb, Rect2(30, 30, 1220, 660))
	draw_string(_head, Vector2(70, 100), "The Map", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 54, Palette.INK)
	draw_line(Vector2(70, 114), Vector2(1210, 114), Color(Palette.INK, 0.5), 2.0)
	# chapters
	for i in CHAPTERS.size():
		var r := Rect2(60, 170 + i * 92, 360, 80)
		var open: bool = CHAPTERS[i]["open"]
		var sel := i == _chapter
		draw_rect(r, Color(Palette.GOLD, 0.35) if sel else Color(0, 0, 0, 0.06))
		draw_rect(r, Palette.INK_BROWN if open else Color(Palette.INK, 0.35), false, 2.0)
		var name: String = CHAPTERS[i]["name"]
		var sub: String = CHAPTERS[i]["sub"] if (open or GameState.town_published) else "Unwritten"
		draw_string(_head, r.position + Vector2(16, 36), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Palette.INK if open else Color(Palette.INK, 0.45))
		var status := ""
		if i == 0:
			status = "Complete" if GameState.town_published else "Draft"
		draw_string(_font, r.position + Vector2(16, 62), sub if i != 0 else "%s  ·  %s" % [sub, status], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(Palette.INK, 0.65 if open else 0.4))
	# the map itself
	if _chapter == 0 and _tex:
		draw_set_transform(MAP_ORIGIN, 0.0, Vector2.ONE)
		draw_texture(_tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for l: Dictionary in _labels:
			var nm: String = l["name"]
			var w := _head.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
			draw_string(_head, l["at"] - Vector2(w * 0.5, 0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.8))
		_draw_markers()
	else:
		draw_string(_head, Vector2(620, 380), "Not yet written.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 40, Color(Palette.INK, 0.45))
	# footer
	var y := 664.0
	var x := 70.0
	if _note != "":
		draw_string(_head, Vector2(x, y - 30.0), _note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(Palette.INK, 0.8))
	x += Glyph.draw(self, _font, InputSetup.display_spec("interact"), Vector2(x, y), 28.0) + 10.0
	draw_string(_head, Vector2(x, y + 7.0), "Travel (far posts only)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.8))
	x += 280.0
	x += Glyph.draw(self, _font, InputSetup.display_spec("map"), Vector2(x, y), 28.0) + 10.0
	draw_string(_head, Vector2(x, y + 7.0), "Close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(Palette.INK, 0.8))

func _draw_markers() -> void:
	for i in _posts.size():
		var p := _to_map(Vector2(_posts[i]["cell"]))
		var sel := i == _sel
		var near := Vector2(_posts[i]["cell"] - _player_cell).length() < MIN_TRAVEL
		if sel:
			draw_circle(p + Vector2(0, -6), 15.0 + sin(_t * 5.0) * 2.0, Color(Palette.CYAN, 0.25))
			draw_arc(p + Vector2(0, -6), 13.0, 0.0, TAU, 20, Palette.CYAN_DEEP, 2.4, true)
		draw_rect(Rect2(p + Vector2(-3, -14), Vector2(6, 16)), Palette.WOOD if not near else Palette.WOOD.darkened(0.2))
		draw_circle(p + Vector2(5, -12), 4.0, Color("e6f7fb") if not near else Color("9aa0a8"))
		draw_arc(p + Vector2(5, -12), 4.0, 0.0, TAU, 10, Palette.INK, 1.2, true)
		if sel:
			var nm: String = _posts[i]["name"] + ("  (near)" if near else "")
			var w := _head.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
			var tag := Rect2(p.x - w * 0.5 - 10.0, p.y - 52.0, w + 20.0, 28.0)
			draw_rect(tag, Color(0.1, 0.12, 0.17, 0.88))
			draw_string(_head, Vector2(tag.position.x + 10.0, tag.position.y + 21.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("f4ecd8"))
	# you are here
	var me := _to_map(Vector2(_player_cell))
	var bob := sin(_t * 4.0) * 2.0
	draw_colored_polygon(PackedVector2Array([me + Vector2(0, -16 + bob), me + Vector2(7, -26 + bob), me + Vector2(-7, -26 + bob)]), Color("c0405a"))
	draw_polyline(PackedVector2Array([me + Vector2(0, -16 + bob), me + Vector2(7, -26 + bob), me + Vector2(-7, -26 + bob), me + Vector2(0, -16 + bob)]), Palette.INK, 1.6, true)
	draw_string(_font, me + Vector2(-18, -30 + bob), "you", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("c0405a"))
