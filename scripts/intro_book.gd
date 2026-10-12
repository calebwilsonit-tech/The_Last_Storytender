extends Node2D
## The opening of a new game: a storybook on a desk opens and tells you what a Storytender is,
## then the last page soaks through with ink and drops you into the Prologue.
## Confirm / click turns the page (finishes the line first); Back / Esc skips the book.

const GAME_SCENE := "res://scenes/main.tscn"
const SPREADS := [
	{"art": "idea", "text": "Every world begins as someone's idea, written in a hurry, mostly in pencil."},
	{"art": "tender", "text": "Writing a world is the easy part. Keeping it is harder. For that there have always been Storytenders: small, patient people who live in the margins and look after whatever the author forgot.\n\nThey mend plot holes. They remember the minor characters. They read the unfinished parts aloud, so those parts know somebody is listening."},
	{"art": "editors", "text": "Once there were thousands. Then the Editors arrived, with red pens and very large scissors and a firm belief that less is more. Behind them came the Redaction: a white that eats everything, and is awfully tidy about it."},
	{"art": "doodle", "text": "Now there is one left. Well. One doodle. In the margin of page forty-one, somebody sketched a small figure holding a lantern, and was then called to dinner.\n\nNobody finished the drawing. Nobody gave it a job."},
	{"art": "you", "text": "That is where you come in. You are not part of the main plot, which is exactly why the Redaction cannot quite see you.\n\nAnd you love this flawed, half-finished world. Somebody ought to."},
	{"art": "blot", "text": "So.\n\nTurn the page."},
]
const BOOK := Rect2(130, 70, 1020, 580)

var _t := 0.0
var _phase := "cover"      # cover -> opening -> read -> turning -> ending
var _spread := 0
var _chars := 0.0
var _anim := 0.0
var _font: Font
var _ital: Font
var _head: Font
var _going := false
var _blot := 0.0

func _ready() -> void:
	_font = ThemeDB.get_default_theme().default_font
	_ital = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	_head = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	GameState.in_dialogue = false

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"opening":
			_anim += delta / 1.1
			if _anim >= 1.0:
				_phase = "read"
				_anim = 0.0
				_chars = 0.0
		"read":
			_chars += delta * 46.0
		"turning":
			_anim += delta / 0.7
			if _anim >= 1.0:
				_spread += 1
				_phase = "read"
				_anim = 0.0
				_chars = 0.0
		"ending":
			_blot += delta / 2.4
			if _blot >= 1.0 and not _going:
				_go()
	queue_redraw()

func _go() -> void:
	_going = true
	Telemetry.log_event("intro_book", {"skipped": _spread < SPREADS.size() - 1})
	GameState.set_flag("book_seen")
	Transition.go(GAME_SCENE, Color("14111a"))

func _input(event: InputEvent) -> void:
	if _going:
		return
	if MenuInput.back(event) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_skip()
		return
	var go: bool = MenuInput.accept(event) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	if event is InputEventKey and event.echo:
		go = false
	if not go:
		return
	get_viewport().set_input_as_handled()
	match _phase:
		"cover":
			_phase = "opening"
			_anim = 0.0
		"read":
			var total: int = (SPREADS[_spread]["text"] as String).length()
			if _chars < total:
				_chars = total
			elif _spread >= SPREADS.size() - 1:
				_phase = "ending"
				_blot = 0.0
			else:
				_phase = "turning"
				_anim = 0.0

func _skip() -> void:
	if _phase == "cover" or _phase == "opening" or _phase == "read" or _phase == "turning":
		_phase = "ending"
		_blot = maxf(_blot, 0.45)

# --- Drawing -----------------------------------------------------------------------------------
func _draw() -> void:
	# Desk and lamp light.
	draw_rect(Rect2(0, 0, 1280, 720), Color("1d1a26"))
	for i in 7:
		draw_circle(Vector2(1100, 120), 520.0 - i * 70.0, Color(0.95, 0.75, 0.4, 0.035))
	if _phase == "cover" or _phase == "opening":
		_draw_cover()
	else:
		_draw_open()
	if _phase == "ending":
		_draw_blot()
	MenuLegend.draw(self, [["confirm", "confirm", "Turn page"], ["back", "back", "Skip"]])

func _draw_cover() -> void:
	var cx := 640.0
	var w := 440.0
	var open := ease(clampf(_anim, 0.0, 1.0), -2.0) if _phase == "opening" else 0.0
	# The back cover and page block stay put; the front cover swings open about the spine.
	if _phase == "opening":
		_draw_open_pages(Rect2(cx, BOOK.position.y, BOOK.size.x * 0.5, BOOK.size.y), false)
	var x0 := cx - w * 0.5 if _phase == "cover" else cx
	var half := w * 0.5 if _phase == "cover" else w * 0.5
	var wid: float = w
	if _phase == "opening":
		var ang := open * PI
		wid = w * cos(ang)
		x0 = cx
	var r := Rect2(x0, 90, wid, 540)
	if wid < 0.0:
		r = Rect2(x0 + wid, 90, -wid, 540)
	draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color("4a2a22") if wid >= 0.0 else Color("5a3a2c"))
	if r.size.x > 40.0:
		draw_rect(r.grow(-14), Color("7a3a2c"), false, 3.0)
		var tx := r.position.x + (r.size.x * 0.5 if _phase == "cover" else r.size.x * 0.5)
		if wid > 0.0:
			var s := clampf(wid / w, 0.0, 1.0)
			draw_set_transform(Vector2(cx - w * 0.5 + (0.0 if _phase == "cover" else 0.0), 0.0), 0.0, Vector2.ONE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var gold := Color("e0b048")
			_ctext(_head, "The Last", Vector2(r.position.x + r.size.x * 0.5, 250), int(46 * s + 6), gold)
			_ctext(_head, "Storytender", Vector2(r.position.x + r.size.x * 0.5, 320), int(62 * s + 6), gold)
			draw_line(Vector2(r.position.x + r.size.x * 0.18, 345), Vector2(r.position.x + r.size.x * 0.82, 345), gold, 2.0)
			_ctext(_ital, "a book of margins", Vector2(r.position.x + r.size.x * 0.5, 385), int(22 * s + 4), Color(gold, 0.85))
			if _phase == "cover":
				draw_circle(Vector2(r.position.x + r.size.x * 0.5, 480), 14.0, Color(Palette.CYAN, 0.25 + 0.15 * sin(_t * 3.0)))
				_ctext(_ital, "open", Vector2(r.position.x + r.size.x * 0.5, 540), 22, Color(gold, 0.6 + 0.3 * sin(_t * 3.0)))

func _ctext(font: Font, s: String, at: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, at - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, col)

func _draw_open_pages(r: Rect2, left: bool) -> void:
	var paper := Color("f3e7c6")
	draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, paper)
	for k in 5:
		var off := (k + 1) * 3.0
		draw_line(Vector2(r.end.x + off, r.position.y + off), Vector2(r.end.x + off, r.end.y + off), Color(0.6, 0.5, 0.35, 0.5), 1.0)
	draw_rect(r, Color("6a4a30"), false, 3.0)
	draw_rect(Rect2(r.position.x, r.position.y, 26.0, r.size.y) if not left else Rect2(r.end.x - 26.0, r.position.y, 26.0, r.size.y), Color(0, 0, 0, 0.07))

func _draw_open() -> void:
	var lp := Rect2(BOOK.position, Vector2(BOOK.size.x * 0.5, BOOK.size.y))
	var rp := Rect2(BOOK.position.x + BOOK.size.x * 0.5, BOOK.position.y, BOOK.size.x * 0.5, BOOK.size.y)
	draw_rect(Rect2(BOOK.position - Vector2(14, 12), BOOK.size + Vector2(28, 28)), Color("4a2a22"))
	_draw_open_pages(lp, true)
	_draw_open_pages(rp, false)
	var turning := _phase == "turning"
	var idx := _spread
	var next_idx := _spread + 1
	var show_left := idx
	_draw_art(lp, String(SPREADS[show_left]["art"]) if not turning or _anim < 0.5 else String(SPREADS[next_idx]["art"]) if turning else "")
	# Right page text (the old one until the flip passes the spine, then the new one).
	if turning:
		_draw_text(rp, (SPREADS[idx]["text"] as String) if _anim < 0.5 else "", 1.0e9)
		if _anim >= 0.5:
			_draw_text(rp, SPREADS[next_idx]["text"], 0.0)
		# The flipping leaf.
		var f := _anim
		var ang := f * PI
		var w := BOOK.size.x * 0.5 * cos(ang)
		var leaf := Rect2(BOOK.position.x + BOOK.size.x * 0.5, BOOK.position.y, w, BOOK.size.y)
		if w < 0.0:
			leaf = Rect2(leaf.position.x + w, leaf.position.y, -w, leaf.size.y)
		draw_rect(Rect2(leaf.position + Vector2(5, 7), leaf.size), Color(0, 0, 0, 0.18))
		draw_rect(leaf, Color("f1e4c0"))
		draw_rect(leaf, Color("6a4a30"), false, 2.0)
		draw_rect(leaf, Color(0, 0, 0, 0.12 * absf(sin(ang))))
	else:
		_draw_text(rp, SPREADS[idx]["text"], _chars)
	var tag := "%d / %d" % [idx + 1, SPREADS.size()]
	_ctext(_ital, tag, Vector2(BOOK.position.x + BOOK.size.x * 0.5, BOOK.end.y + 14), 16, Color(1, 1, 1, 0.35))

func _draw_text(r: Rect2, text: String, chars: float) -> void:
	if text == "":
		return
	var shown := text.substr(0, mini(int(chars), text.length()))
	var pos := Vector2(r.position.x + 56.0, r.position.y + 90.0)
	draw_multiline_string(_head, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100.0, 27, -1, Color("3b2a1c"))
	if int(chars) >= text.length() and _phase == "read":
		var a := 0.45 + 0.35 * sin(_t * 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 60, r.end.y - 40), Vector2(r.end.x - 40, r.end.y - 40), Vector2(r.end.x - 50, r.end.y - 28)]), Color(0.23, 0.16, 0.11, a))

func _wob(a: Vector2, b: Vector2, col: Color, w: float = 2.4, seed_v: float = 0.0) -> void:
	DrawKit.line(self, a, b, col, w, seed_v, 1.4)

func _draw_art(r: Rect2, art: String) -> void:
	var c := r.position + r.size * 0.5
	var ink := Color("3b2a1c")
	var pen := Color("6a6e84")
	# Faint ruled lines like a notebook margin.
	for k in 14:
		draw_line(Vector2(r.position.x + 40, r.position.y + 70 + k * 36), Vector2(r.end.x - 30, r.position.y + 70 + k * 36), Color(0.45, 0.55, 0.75, 0.16), 1.0)
	draw_line(Vector2(r.position.x + 82, r.position.y + 30), Vector2(r.position.x + 82, r.end.y - 30), Color(0.85, 0.4, 0.4, 0.3), 1.4)
	match art:
		"idea":
			# A pencil sketch of a tower and a sun, still unfinished.
			var base := c + Vector2(0, 90)
			_wob(base + Vector2(-60, 0), base + Vector2(-60, -160), pen, 2.2, 1.0)
			_wob(base + Vector2(60, 0), base + Vector2(60, -160), pen, 2.2, 2.0)
			_wob(base + Vector2(-60, -160), base + Vector2(0, -230), pen, 2.2, 3.0)
			_wob(base + Vector2(60, -160), base + Vector2(0, -230), pen, 2.2, 4.0)
			_wob(base + Vector2(-60, 0), base + Vector2(60, 0), pen, 2.2, 5.0)
			draw_rect(Rect2(base + Vector2(-14, -50), Vector2(28, 50)), Color(pen, 0.0), false, 2.0)
			draw_arc(c + Vector2(130, -130), 34.0, 0.0, TAU, 20, pen, 2.0, true)
			for k in 8:
				var a := k * TAU / 8.0
				_wob(c + Vector2(130, -130) + Vector2(cos(a), sin(a)) * 44.0, c + Vector2(130, -130) + Vector2(cos(a), sin(a)) * 62.0, pen, 2.0, k)
			# A pencil laid across the page.
			var p0 := c + Vector2(-150, 150)
			var p1 := c + Vector2(40, 190)
			draw_line(p0, p1, Color("e0b048"), 14.0)
			draw_line(p1, p1 + Vector2(26, 6), Color("e6c9a0"), 12.0)
			draw_line(p1 + Vector2(22, 5), p1 + Vector2(32, 7.5), ink, 8.0)
		"tender":
			_draw_storytender(c + Vector2(0, 30), 3.0, 1.0, 1.0)
			# small mended page patches in the margin
			for k in 3:
				var q := c + Vector2(-120 + k * 90, -150 + (k % 2) * 30)
				draw_rect(Rect2(q, Vector2(46, 34)), Color("e8dcb4"))
				draw_rect(Rect2(q, Vector2(46, 34)), Color("8a7a5a"), false, 1.6)
				draw_line(q + Vector2(8, 12), q + Vector2(38, 12), pen, 1.6)
				draw_line(q + Vector2(8, 22), q + Vector2(30, 22), pen, 1.6)
		"editors":
			# A huge pair of scissors and a white stain eating the page from the corner.
			var o := c + Vector2(0, -20)
			draw_line(o + Vector2(-90, -120), o + Vector2(30, 70), ink, 7.0)
			draw_line(o + Vector2(90, -120), o + Vector2(-30, 70), ink, 7.0)
			draw_arc(o + Vector2(-34, 100), 28.0, 0.0, TAU, 18, Color("b8402f"), 7.0, true)
			draw_arc(o + Vector2(34, 100), 28.0, 0.0, TAU, 18, Color("b8402f"), 7.0, true)
			var grow := 0.6 + 0.1 * sin(_t * 1.5)
			for k in 7:
				draw_circle(r.end - Vector2(40 + k * 5, 60 + k * 7) * 1.0, (120.0 - k * 9.0) * grow + 20.0, Color(1, 1, 1, 0.18))
		"doodle":
			# Page 41 with a half-drawn, dashed Storytender.
			_ctext(_ital, "41", Vector2(c.x, r.end.y - 36), 22, Color(ink, 0.5))
			_draw_storytender(c + Vector2(0, 30), 3.0, 0.0, 0.0)
			_wob(c + Vector2(-80, 120), c + Vector2(-34, 120), pen, 2.0, 3.0)
		"you":
			_draw_storytender(c + Vector2(0, 30), 3.2, 1.0, 1.0)
			for k in 18:
				var ph := fmod(_t * 0.2 + k * 0.071, 1.0)
				draw_circle(c + Vector2(40 + sin(_t + k) * 30.0 + k * 3.0, 90 - ph * 300.0), 2.6, Color(Palette.CYAN, (1.0 - ph) * 0.7))
		"blot":
			# One drop of ink gathering at the top of the page.
			var bx := c.x
			var by := r.position.y + 150 + 40.0 * sin(_t * 1.4)
			draw_circle(Vector2(bx, by), 20.0 + 3.0 * sin(_t * 3.0), ink)
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 12, by - 6), Vector2(bx, by - 70), Vector2(bx + 12, by - 6)]), ink)
			draw_circle(Vector2(bx - 6, by - 4), 5.0, Color(1, 1, 1, 0.3))

## The little hooded Storytender. `fill` fades the body in; `lamp` lights the lantern.
func _draw_storytender(c: Vector2, s: float, fill: float, lamp: float) -> void:
	var out := Palette.OUTLINE
	var body := PackedVector2Array([c + Vector2(-16, 34) * s, c + Vector2(-12, -6) * s, c + Vector2(-8, -22) * s, c + Vector2(0, -28) * s, c + Vector2(8, -22) * s, c + Vector2(12, -6) * s, c + Vector2(16, 34) * s])
	if fill > 0.0:
		draw_colored_polygon(body, Color("3a3150"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12) * s, c + Vector2(0, -22) * s, c + Vector2(8, -12) * s, c + Vector2(8, 0) * s, c + Vector2(-8, 0) * s]), Color("14111a"))
		draw_circle(c + Vector2(-3, -9) * s, 1.6 * s, Palette.CYAN)
		draw_circle(c + Vector2(3, -9) * s, 1.6 * s, Palette.CYAN)
	var loop := body.duplicate()
	loop.append(body[0])
	if fill > 0.0:
		draw_polyline(loop, out, 2.6, true)
	else:
		for k in body.size():
			var a := body[k]
			var b := body[(k + 1) % body.size()]
			var d := (b - a)
			var n := int(d.length() / 10.0)
			for j in range(0, n, 2):
				draw_line(a + d * (float(j) / n), a + d * (float(j + 1) / n), Color("6a6e84"), 2.0)
	# Lantern on a pole at the right hand.
	var lp := c + Vector2(22, 4) * s
	draw_line(lp + Vector2(0, -26) * s, lp + Vector2(0, 32) * s, Color("8a6a40") if fill > 0.0 else Color("6a6e84"), 2.4)
	if lamp > 0.0:
		for i in 4:
			draw_circle(lp + Vector2(0, -26) * s, (30.0 - i * 6.0) * s * 0.7, Color(Palette.CYAN, 0.07 * lamp))
		draw_rect(Rect2(lp + Vector2(-5, -36) * s, Vector2(10, 12) * s), Color(Palette.CYAN, 0.9 * lamp))
		draw_rect(Rect2(lp + Vector2(-5, -36) * s, Vector2(10, 12) * s), out, false, 2.0)

func _draw_blot() -> void:
	var p := clampf(_blot, 0.0, 1.0)
	var c := Vector2(640, 110 + 40.0 * p)
	var r := (p * p) * 1500.0
	draw_circle(c, r, Color("14111a"))
