class_name EnemyKinds
extends RefCounted
## The four Errors beyond the Bare and the Mite, each with its own way of fighting. They are
## unlocked as the story goes on (see main.gd):
##   SLUG      "Run-on": slow, long, leaves a trail of sticky ink that slows you. Proofread it with
##             the Lantern and it learns to stop (a full stop, a friendly snail).
##   DANGLER   "Dangling Modifier": hangs from a thread, keeps its distance and flings slow words.
##             Dodge them; the Lantern ties it off and it stops dangling.
##   CENSOR    "Censor": a black bar across its front blocks the Quill. Hold the Lantern on the bar to
##             strip it for a few seconds, or go around and hit it from behind.
##   ELLIPSIS  "...": blinks around you, then strikes where it lands. The Lantern pins it in place.

static func renown_value(kind: int) -> int:
	match kind:
		Enemy.Kind.MITE: return 1
		Enemy.Kind.BARE: return 2
		Enemy.Kind.SLUG, Enemy.Kind.DANGLER: return 3
		Enemy.Kind.CENSOR, Enemy.Kind.ELLIPSIS: return 4
	return 1

static func is_special(e: Enemy) -> bool:
	return e.kind >= Enemy.Kind.SLUG

static func setup(e: Enemy) -> void:
	match e.kind:
		Enemy.Kind.SLUG:
			e.hp = 10.0
			e.hit_r = 24.0
			e.vision_range = 190.0
			e.half_cone = 1.2
			e.hearing_mult = 0.8
			e.x = {"trail": [], "drip": 0.0, "slowing": false}
		Enemy.Kind.DANGLER:
			e.hp = 5.0
			e.hit_r = 16.0
			e.vision_range = 300.0
			e.half_cone = 1.1
			e.x = {"bolts": [], "fire": 1.6, "tele": 0.0}
		Enemy.Kind.CENSOR:
			e.hp = 12.0
			e.hit_r = 22.0
			e.vision_range = 260.0
			e.half_cone = 0.9
			e.x = {"bar_t": 0.0, "strip": 0.0}
		Enemy.Kind.ELLIPSIS:
			e.hp = 4.0
			e.hit_r = 14.0
			e.vision_range = 260.0
			e.half_cone = 1.4
			e.hearing_mult = 1.2
			e.x = {"blink": 1.6, "phase": "visible", "t": 0.0, "spot": Vector2.ZERO, "pinned": 0.0}

static func pool(e: Enemy) -> float:
	match e.kind:
		Enemy.Kind.SLUG: return 24.0
		Enemy.Kind.CENSOR: return 18.0
		Enemy.Kind.DANGLER: return 10.0
	return 11.0

static func label_top(e: Enemy) -> float:
	match e.kind:
		Enemy.Kind.CENSOR: return -104.0
		Enemy.Kind.DANGLER: return -86.0
		Enemy.Kind.SLUG: return -56.0
	return -56.0

static func word_pair(e: Enemy) -> Array:
	match e.kind:
		Enemy.Kind.SLUG: return ["Runon", "Run on"]
		Enemy.Kind.DANGLER: return ["Dangling", "Hanging"]
	return ["", ""]

# --- Damage rules ----------------------------------------------------------------------------
## Returns true if the hit is blocked (and does nothing).
static func blocks_hit(e: Enemy, dir_ground: Vector2) -> bool:
	if e.kind == Enemy.Kind.ELLIPSIS and e.x.get("phase", "visible") != "visible":
		return true                      # blinked away: nothing there to hit
	if e.kind == Enemy.Kind.CENSOR and float(e.x["bar_t"]) <= 0.0:
		# The bar covers the front. dir_ground points from the attacker to the Censor, so the
		# attacker is in front when the Censor is facing back along it.
		var facing := e._facing.normalized()
		return facing.dot(-dir_ground.normalized()) > 0.25
	return false

static func on_lit(e: Enemy, delta: float) -> void:
	match e.kind:
		Enemy.Kind.SLUG:
			e._proof += delta / 3.0
			if e._proof >= 1.0:
				e._correct()
		Enemy.Kind.DANGLER:
			e._proof += delta / 1.8
			if e._proof >= 1.0:
				e._correct()
		Enemy.Kind.CENSOR:
			e.x["strip"] = float(e.x["strip"]) + delta
			if float(e.x["strip"]) >= 1.1:
				e.x["strip"] = 0.0
				e.x["bar_t"] = 5.0
		Enemy.Kind.ELLIPSIS:
			e.x["pinned"] = 0.35
			e.hp -= 3.0 * delta
			if e.hp <= 0.0:
				e._die()

static func lunge_damage(e: Enemy) -> float:
	return 10.0 if e.kind == Enemy.Kind.CENSOR else 12.0

static func lunge_source(e: Enemy) -> String:
	return "censor" if e.kind == Enemy.Kind.CENSOR else "bare"

# --- Per-frame upkeep (runs whenever it is awake) -----------------------------------------------
static func tick_always(e: Enemy, delta: float) -> void:
	var tgt := e.target
	match e.kind:
		Enemy.Kind.SLUG:
			var trail: Array = e.x["trail"]
			var in_puddle := false
			for p: Dictionary in trail:
				p["t"] = float(p["t"]) - delta
				if tgt and not tgt.is_falling and e._ground_to_from(p["pos"], tgt.position).length() < 26.0 and p["t"] > 0.0:
					in_puddle = true
			e.x["trail"] = trail.filter(func(p): return float(p["t"]) > 0.0)
			if tgt:
				if in_puddle:
					tgt.speed_mult = minf(tgt.speed_mult, 0.55)
					e.x["slowing"] = true
				elif e.x["slowing"]:
					tgt.speed_mult = 1.0
					e.x["slowing"] = false
		Enemy.Kind.DANGLER:
			var bolts: Array = e.x["bolts"]
			for b: Dictionary in bolts:
				b["pos"] = Vector2(b["pos"]) + Vector2(b["vel"]) * delta
				b["ttl"] = float(b["ttl"]) - delta
				if tgt and not tgt.is_falling and not tgt.is_crumpled and e._ground_to_from(b["pos"], tgt.position).length() < 18.0:
					tgt.take_damage(6.0 * GameState.enemy_dmg_mult(), true, "dangler")
					b["ttl"] = 0.0
				var c: Vector2i = e.floor_ref.cell_at(b["pos"]) if e.floor_ref else Vector2i.ZERO
				if e.floor_ref and not e.floor_ref.has_cell(c):
					b["ttl"] = 0.0
			e.x["bolts"] = bolts.filter(func(b): return float(b["ttl"]) > 0.0)
			e.x["tele"] = maxf(float(e.x["tele"]) - delta, 0.0)
		Enemy.Kind.CENSOR:
			e.x["bar_t"] = maxf(float(e.x["bar_t"]) - delta, 0.0)
			if not e._lit_now:
				e.x["strip"] = maxf(float(e.x["strip"]) - delta * 0.6, 0.0)
		Enemy.Kind.ELLIPSIS:
			e.x["pinned"] = maxf(float(e.x["pinned"]) - delta, 0.0)

static func release(e: Enemy) -> void:
	# Whatever it was doing to the player stops when it dies or is corrected.
	if e.kind == Enemy.Kind.SLUG and e.target and e.x.get("slowing", false):
		e.target.speed_mult = 1.0
		e.x["slowing"] = false

# --- Chasing and attacking ----------------------------------------------------------------------
static func chase(e: Enemy, delta: float, dist: float, dirg: Vector2, slow: float) -> void:
	var tgt := e.target
	match e.kind:
		Enemy.Kind.SLUG:
			e._move(dirg, 40.0 * slow)
			e.x["drip"] = float(e.x["drip"]) - delta
			if float(e.x["drip"]) <= 0.0:
				e.x["drip"] = 0.45
				(e.x["trail"] as Array).append({"pos": e.position, "t": 6.0})
			if dist < 34.0 and e._cd <= 0.0:
				tgt.take_damage(7.0 * GameState.enemy_dmg_mult(), true, "slug")
				tgt.knockback(dirg, 120.0)
				e._cd = 1.3
		Enemy.Kind.DANGLER:
			if dist < 170.0:
				e._move(-dirg, 78.0 * slow)
			elif dist > 290.0:
				e._move(dirg, 64.0 * slow)
			else:
				e._move(dirg.orthogonal() * (1.0 if sin(e._seed * 9.0) > 0.0 else -1.0), 38.0 * slow)
			e.x["fire"] = float(e.x["fire"]) - delta
			if float(e.x["fire"]) <= 0.0 and dist < 360.0 and e.floor_ref and e.floor_ref.has_los(e.position, tgt.position):
				if float(e.x["tele"]) <= 0.0:
					e.x["tele"] = 0.55
					e.x["fire"] = 0.55
				else:
					e.x["fire"] = 2.5 if not GameState.is_story() else 3.2
					var tv: Vector2 = tgt.velocity
					var aim: Vector2 = tgt.position + tv * (dist / 150.0) * 0.6
					var d := e._ground_to(aim).normalized()
					(e.x["bolts"] as Array).append({"pos": e.position + Vector2(0, -22), "vel": Vector2(d.x, d.y * 0.5) * 150.0, "ttl": 3.4})
		Enemy.Kind.CENSOR:
			e._move(dirg, 62.0 * slow)
			e._facing = e._facing.lerp(dirg, 1.0 - exp(-5.0 * delta)).normalized()
			if dist < 76.0 and e._cd <= 0.0 and slow == 1.0:
				e._state = "windup"
				e._st = 0.55
				e._lunge = dirg
		Enemy.Kind.ELLIPSIS:
			_ellipsis_chase(e, delta, dist, dirg, slow)

static func _ellipsis_chase(e: Enemy, delta: float, dist: float, dirg: Vector2, slow: float) -> void:
	var tgt := e.target
	var ph: String = e.x["phase"]
	e.x["t"] = float(e.x["t"]) - delta
	match ph:
		"visible":
			if float(e.x["pinned"]) > 0.0:
				e.velocity = Vector2.ZERO          # held in the light: it cannot blink
				return
			e._move(dirg, 70.0 * slow)
			e.x["blink"] = float(e.x["blink"]) - delta
			if float(e.x["blink"]) <= 0.0:
				e.x["phase"] = "gone"
				e.x["t"] = 0.45
		"gone":
			e.velocity = Vector2.ZERO
			if float(e.x["t"]) <= 0.0:
				# land somewhere around you, on solid ground
				for _try in 12:
					var ang := randf() * TAU
					var off := Vector2.from_angle(ang) * randf_range(90.0, 140.0)
					var np: Vector2 = tgt.position + Vector2(off.x, off.y * 0.5)
					var c: Vector2i = e.floor_ref.cell_at(np)
					if e.floor_ref.has_cell(c) and not e.floor_ref.is_pit(c) and absf(e.floor_ref.height_at(np) - e.floor_ref.height_at(tgt.position)) < 0.6:
						e.position = np
						break
				e.x["phase"] = "tele"
				e.x["t"] = 0.6
		"tele":
			e.velocity = Vector2.ZERO
			if float(e.x["t"]) <= 0.0:
				if dist < 52.0:
					tgt.take_damage(7.0 * GameState.enemy_dmg_mult(), true, "ellipsis")
					tgt.knockback(dirg, 200.0)
				e.x["phase"] = "visible"
				e.x["blink"] = randf_range(1.7, 2.5)

# --- Drawing ---------------------------------------------------------------------------------------
static func draw_body(e: Enemy) -> void:
	match e.kind:
		Enemy.Kind.SLUG: _draw_slug(e)
		Enemy.Kind.DANGLER: _draw_dangler(e)
		Enemy.Kind.CENSOR: _draw_censor(e)
		Enemy.Kind.ELLIPSIS: _draw_ellipsis(e)

## Everything that is not the body: word labels, bolts, the censor's bar, telegraph rings. Used when an art
## style draws the bodies, so the gameplay marks stay identical in every style.
static func draw_overlay(e: Enemy) -> void:
	match e.kind:
		Enemy.Kind.BARE:
			e.draw_bare_labels()
		Enemy.Kind.SLUG:
			_draw_word_pair(e)
		Enemy.Kind.DANGLER:
			var t := e._t
			for b: Dictionary in e.x["bolts"]:
				var off: Vector2 = Vector2(b["pos"]) - e.position
				var bp := Vector2(off.x, off.y)
				e.draw_circle(bp, 9.0, Color(1.0, 0.45, 0.35, 0.3))
				var font := ThemeDB.get_default_theme().default_font
				e.draw_string_outline(font, bp + Vector2(-14, 4), "ing", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 5, Color(Palette.OUTLINE, 0.9))
				e.draw_string(font, bp + Vector2(-14, 4), "ing", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("ffb9a8"))
			_draw_word_pair(e)
		Enemy.Kind.CENSOR:
			var t2 := e._t
			var bob := sin(t2 * 2.0) * 1.5
			var sgn := 1.0 if e._facing.x >= 0.0 else -1.0
			var bar_up := float(e.x["bar_t"]) <= 0.0
			var bw := 40.0 if bar_up else 8.0
			if bar_up or fmod(t2 * 6.0, 1.0) < 0.5 or float(e.x["bar_t"]) > 1.2:
				var rect := Rect2(Vector2(4.0 * sgn - bw * 0.5, -58.0 + bob), Vector2(bw, 16.0))
				e.draw_rect(rect, Color(0.02, 0.02, 0.04))
				e.draw_rect(rect, Color("e4dcf7"), false, 2.0)
			var font2 := ThemeDB.get_default_theme().default_font
			if bar_up:
				e.draw_string(font2, Vector2(-17, -46 + bob), "[CENSORED]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(1, 1, 1, 0.55))
			var st := float(e.x["strip"])
			if st > 0.05:
				e.draw_arc(Vector2(0, -50 + bob), 22.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(st / 1.1, 0.0, 1.0), 20, Palette.CYAN, 3.0, true)
			if e._state == "windup":
				e.draw_string(font2, Vector2(8, -88), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color("ff6a5c"))
		Enemy.Kind.ELLIPSIS:
			var ph: String = e.x["phase"]
			if ph == "gone":
				var a := clampf(float(e.x["t"]) / 0.45, 0.0, 1.0)
				for i in 3:
					e.draw_circle(Vector2(-16 + i * 16, -16), 6.0, Color(1, 1, 1, 0.12 * a))
			elif ph == "tele":
				var k := 1.0 - clampf(float(e.x["t"]) / 0.6, 0.0, 1.0)
				e.draw_set_transform(Vector2(0, -e.elev), 0.0, Vector2(1, 0.5))
				e.draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.3, 0.35 + 0.5 * k), 3.0, true)
				e.draw_circle(Vector2.ZERO, 52.0 * k, Color(1.0, 0.35, 0.3, 0.15))
				e.draw_set_transform(Vector2(0, -e.elev), 0.0, Vector2.ONE)

## Things that lie on the ground (the slug's trail) are drawn before the body.
static func draw_ground(e: Enemy) -> void:
	if e.kind == Enemy.Kind.SLUG:
		for p: Dictionary in e.x["trail"]:
			var off: Vector2 = Vector2(p["pos"]) - e.position
			var a := clampf(float(p["t"]) / 2.0, 0.0, 1.0)
			e.draw_circle(Vector2(off.x, off.y * 2.0), 15.0, Color(0.1, 0.07, 0.18, 0.55 * a))
			e.draw_circle(Vector2(off.x + 3.0, off.y * 2.0 - 3.0), 7.0, Color(Palette.GLITCH, 0.25 * a))

static func _draw_slug(e: Enemy) -> void:
	var c := Color("8a9d6a").lerp(Color("c9d08a"), e._proof if not e.friendly else 1.0)
	var t := e._t
	var seg := 4
	for i in seg:
		var k := float(seg - 1 - i)
		var wob := sin(t * 3.0 + k) * 2.0
		var r := 15.0 - i * 1.5
		var ctr := Vector2(-26.0 + i * 15.0, -12.0 + wob)
		e._poly(DrawKit.ellipse(ctr, r, r * 0.8, 14, 0.05, e._seed + i), c.darkened(0.04 * k))
	# a long run of words along its back, with no punctuation at all
	var font := ThemeDB.get_default_theme().default_font
	var txt := "and then and then and then" if not e.friendly else "and then. and then."
	e.draw_string(font, Vector2(-34, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.05, 0.1, 0.05, 0.75))
	# head with eye stalks
	var head := Vector2(36, -14 + sin(t * 4.0))
	e._poly(DrawKit.ellipse(head, 11.0, 10.0, 12), c.lightened(0.05))
	for sx in [-4.0, 5.0]:
		e.draw_line(head + Vector2(sx, -8), head + Vector2(sx + 2, -22 + sin(t * 5.0 + sx)), Palette.OUTLINE, 2.2)
		e.draw_circle(head + Vector2(sx + 2, -23 + sin(t * 5.0 + sx)), 3.2, Color.WHITE)
		e.draw_circle(head + Vector2(sx + 3, -23 + sin(t * 5.0 + sx)), 1.4, Palette.OUTLINE)
	_draw_word_pair(e)

static func _draw_word_pair(e: Enemy) -> void:
	var wp := word_pair(e)
	if wp[0] == "":
		return
	var font := ThemeDB.get_default_theme().default_font
	var word: String = wp[1] if e.friendly else wp[0]
	var col := Palette.CYAN if e.friendly else Color("ff6a5c")
	var y := label_top(e) - 12.0
	e.draw_string_outline(font, Vector2(-24, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 5, Color(Palette.OUTLINE, 0.8))
	e.draw_string(font, Vector2(-24, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, col)
	if not e.friendly and e._proof > 0.05:
		e.draw_string(font, Vector2(-24, y - 16.0), wp[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(Palette.CYAN, e._proof))

static func _draw_dangler(e: Enemy) -> void:
	var t := e._t
	var sway := sin(t * 1.7 + e._seed) * 5.0
	var top := Vector2(0, -92)
	var body := Vector2(sway, -38 + sin(t * 2.3) * 3.0)
	var c := Color("2a2438").lerp(Color("5a6f8a"), e._proof if not e.friendly else 1.0)
	# the thread it dangles from, going up off the top of the screen
	e.draw_line(top + Vector2(sway * 0.3, 0), body + Vector2(0, -16), Color(0.25, 0.22, 0.3, 0.8), 1.6)
	e.draw_circle(top + Vector2(sway * 0.3, 0), 2.5, Palette.OUTLINE)
	# a hook-shaped body: a swung comma
	e._poly(DrawKit.ellipse(body, 15.0, 17.0, 16, 0.06, e._seed), c)
	e._poly(PackedVector2Array([body + Vector2(-4, 14), body + Vector2(6, 14), body + Vector2(2, 30), body + Vector2(-8, 34)]), c.darkened(0.1), 2.2)
	for ex in [-5.0, 5.0]:
		e.draw_circle(body + Vector2(ex, -4), 3.4, Color.WHITE)
		e.draw_circle(body + Vector2(ex + 1, -4), 1.5, Palette.OUTLINE)
	if float(e.x["tele"]) > 0.0:
		e.draw_circle(body + Vector2(10, -2), 6.0 + sin(t * 30.0) * 1.5, Color(1.0, 0.45, 0.35, 0.8))
	for b: Dictionary in e.x["bolts"]:
		var off: Vector2 = Vector2(b["pos"]) - e.position
		var bp := Vector2(off.x, off.y)
		e.draw_circle(bp, 9.0, Color(1.0, 0.45, 0.35, 0.3))
		var font := ThemeDB.get_default_theme().default_font
		e.draw_string_outline(font, bp + Vector2(-14, 4), "ing", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 5, Color(Palette.OUTLINE, 0.9))
		e.draw_string(font, bp + Vector2(-14, 4), "ing", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("ffb9a8"))
	_draw_word_pair(e)

static func _draw_censor(e: Enemy) -> void:
	var t := e._t
	var bob := sin(t * 2.0) * 1.5
	var facing_right: bool = e._facing.x >= 0.0
	var sgn := 1.0 if facing_right else -1.0
	var robe := Color("2b2b3a")
	# tall robed figure
	e._poly(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(11, -52 + bob), Vector2(-11, -52 + bob)]), robe)
	e._poly(DrawKit.ellipse(Vector2(0, -62 + bob), 11.0, 12.0, 14, 0.03, e._seed), Color("e8e0d0"))
	for ex in [-4.0, 4.0]:
		e.draw_circle(Vector2(ex, -64 + bob), 1.8, Palette.OUTLINE)
	# the black bar across the front (strip it with the Lantern)
	var bar_up := float(e.x["bar_t"]) <= 0.0
	var bw := 40.0 if bar_up else 8.0
	if bar_up or fmod(t * 6.0, 1.0) < 0.5 or float(e.x["bar_t"]) > 1.2:
		var bx := 4.0 * sgn
		var rect := Rect2(Vector2(bx - bw * 0.5, -58.0 + bob), Vector2(bw, 16.0))
		e.draw_rect(rect, Color(0.02, 0.02, 0.04))
		e.draw_rect(rect, Palette.OUTLINE, false, 2.0)
	var font := ThemeDB.get_default_theme().default_font
	if bar_up:
		e.draw_string(font, Vector2(-17, -46 + bob), "[CENSORED]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(1, 1, 1, 0.55))
	var st := float(e.x["strip"])
	if st > 0.05:
		e.draw_arc(Vector2(0, -50 + bob), 22.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(st / 1.1, 0.0, 1.0), 20, Palette.CYAN, 3.0, true)
	if e._state == "windup":
		e.draw_string(font, Vector2(8, -88), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color("ff6a5c"))

static func _draw_ellipsis(e: Enemy) -> void:
	var t := e._t
	var ph: String = e.x["phase"]
	if ph == "gone":
		var a := clampf(float(e.x["t"]) / 0.45, 0.0, 1.0)
		# a faint smear where it was
		for i in 3:
			e.draw_circle(Vector2(-16 + i * 16, -16), 6.0, Color(1, 1, 1, 0.12 * a))
		return
	var pinned := float(e.x["pinned"]) > 0.0
	for i in 3:
		var hop := absf(sin(t * 6.0 + i * 0.9)) * (3.0 if pinned else 9.0)
		var ctr := Vector2(-18 + i * 18, -14 - hop)
		var col := Color(0.06, 0.04, 0.1).lerp(Color.WHITE, e._flash * 4.0)
		e.draw_circle(ctr, 9.5, Color(1, 1, 1, 0.8))
		e.draw_circle(ctr, 8.0, col)
		e.draw_circle(ctr + Vector2(-2, -1), 1.6, Color.WHITE)
		e.draw_circle(ctr + Vector2(2, -1), 1.6, Color.WHITE)
	if ph == "tele":
		var k := 1.0 - clampf(float(e.x["t"]) / 0.6, 0.0, 1.0)
		e.draw_set_transform(Vector2(0, -e.elev), 0.0, Vector2(1, 0.5))
		e.draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.3, 0.35 + 0.5 * k), 3.0, true)
		e.draw_circle(Vector2.ZERO, 52.0 * k, Color(1.0, 0.35, 0.3, 0.15))
		e.draw_set_transform(Vector2(0, -e.elev), 0.0, Vector2.ONE)
