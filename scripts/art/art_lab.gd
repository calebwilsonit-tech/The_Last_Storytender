extends Node2D
## The Art Lab: every figure in every art style, side by side, at any zoom. Open it from the title
## screen (Art Lab) or press F8 in the overworld. A / D change style, W / S change sheet, Q / E zoom,
## Space cycles the background, Esc leaves.

const SHEETS := ["storytender", "friends", "errors", "bosses", "memories", "world", "magic"]
const BGS := [Color("e9dcb7"), Color("7aa35a"), Color("1c2030")]

var style_id := ""
var sheet := "storytender"
var zoom := 2.5
var bg := 0
var t := 0.0
var animate := true
var _real: Array[Node] = []

func _ready() -> void:
	if style_id == "":
		style_id = Settings.art_style if Settings.art_style != "default" else "cel"

func _process(delta: float) -> void:
	if animate:
		t += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_A: _cycle_style(-1)
		KEY_D: _cycle_style(1)
		KEY_W: _cycle_sheet(-1)
		KEY_S: _cycle_sheet(1)
		KEY_Q: zoom = maxf(zoom - 0.5, 1.0)
		KEY_E: zoom = minf(zoom + 0.5, 8.0)
		KEY_SPACE: bg = (bg + 1) % BGS.size()
		KEY_P: animate = not animate
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title.tscn")

func _cycle_style(d: int) -> void:
	var i := (ArtStyles.index_of(style_id) + d + ArtStyles.ORDER.size()) % ArtStyles.ORDER.size()
	style_id = ArtStyles.ORDER[i]
	_clear_real()

func _cycle_sheet(d: int) -> void:
	var i := (SHEETS.find(sheet) + d + SHEETS.size()) % SHEETS.size()
	sheet = SHEETS[i]
	_clear_real()

func _clear_real() -> void:
	for n in _real:
		if is_instance_valid(n):
			n.queue_free()
	_real.clear()

# --- the cells ---------------------------------------------------------------------------------------
func _cells() -> Array:
	var out: Array = []
	match sheet:
		"storytender":
			var base := {"weapon": "stub", "lantern_on": false, "flick": 1.0}
			var names := ["S (to camera)", "SE", "E", "NE", "N (away)", "NW", "W", "SW"]
			var dirs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
			for i in 8:
				out.append(["idle " + names[i], "storytender", _m(base, {"dir": dirs[i].normalized()})])
			for i in 4:
				out.append(["walk %d (SE)" % (i + 1), "storytender", _m(base, {"dir": Vector2(1, 1).normalized(), "moving": true, "phase": i * 1.57})])
			out.append(["pencil swing", "storytender", _m(base, {"dir": Vector2(1, 0.4).normalized(), "swing": 0.7})])
			out.append(["sword swing", "storytender", _m(base, {"dir": Vector2(1, 0.4).normalized(), "swing": 0.5, "weapon": "sword"})])
			out.append(["quill, S", "storytender", _m(base, {"dir": Vector2(0, 1), "weapon": "quill"})])
			out.append(["crumpled", "storytender", _m(base, {"crumpled": true})])
		"friends":
			var base2 := {"restored": 1.0}
			for who in ["garrick", "pip", "maud"]:
				out.append([who + " S", who, _m(base2, {"dir": Vector2(0, 1)})])
				out.append([who + " SE", who, _m(base2, {"dir": Vector2(1, 1).normalized()})])
				out.append([who + " W", who, _m(base2, {"dir": Vector2(-1, 0)})])
				out.append([who + " N", who, _m(base2, {"dir": Vector2(0, -1)})])
			out.append(["garrick missing", "garrick", _m(base2, {"dir": Vector2(0, 1), "restored": 0.0})])
			out.append(["garrick half", "garrick", _m(base2, {"dir": Vector2(0, 1), "restored": 0.5})])
			out.append(["garrick tearful", "garrick", _m(base2, {"dir": Vector2(0, 1), "tearful": true})])
			out.append(["maud missing", "maud", _m(base2, {"dir": Vector2(0, 1), "restored": 0.0})])
		"memories":
			for k in ["young_garrick", "wren", "pip", "maud"]:
				out.append([k + " memory", k, {"memory": true, "restored": 1.0, "dir": Vector2(0.25, 1)}])
			for v in 3:
				out.append(["guest %d seated" % v, "guest", {"variant": v, "restored": 1.0, "dir": Vector2(0.3, 1)}])
				out.append(["guest %d erased-to-be" % v, "guest", {"variant": v, "restored": 0.0, "dir": Vector2(0.3, 1)}])
		"world":
			for v in 3:
				out.append(["tree %d" % v, "prop_tree", {"variant": v, "seed": 3.0 + v * 5.0}])
			out.append(["house", "prop_house", {"variant": 0, "restored": 1.0}])
			out.append(["house (alt)", "prop_house", {"variant": 1, "restored": 1.0}])
			out.append(["house unrestored", "prop_house", {"variant": 0, "restored": 0.0}])
			out.append(["forge", "prop_forge", {"restored": 1.0}])
			out.append(["forge frozen", "prop_forge", {"restored": 1.0, "flame": 0.0}])
			out.append(["forge unrestored", "prop_forge", {"restored": 0.0, "flame": 0.0}])
			out.append(["sign", "prop_sign", {}])
			out.append(["post", "prop_post", {"variant": 0}])
			out.append(["post lit", "prop_post", {"variant": 1}])
			out.append(["chest", "prop_chest", {"variant": 0}])
			out.append(["chest open", "prop_chest", {"variant": 1}])
			out.append(["chair", "prop_chair", {}])
			out.append(["chair occupied", "prop_chair", {"occupied": true}])
		"magic":
			for k in ["crystal", "sword", "shard", "anvil", "portal", "book", "rift", "oven"]:
				out.append([k, "prop_" + k, {}])
			out.append(["gate", "prop_gate", {"variant": 0}])
			out.append(["gate open", "prop_gate", {"variant": 1}])
			out.append(["table cold", "prop_table", {"warmth": 0.0, "table_len": 3}])
			out.append(["table warm", "prop_table", {"warmth": 1.0, "table_len": 3}])
		"errors":
			for k in ["bare", "mite", "slug", "dangler", "censor", "ellipsis"]:
				out.append([k, k, {"face": 1.0, "proof": 0.0, "state": "idle"}])
			for k in ["bare", "slug", "dangler"]:
				out.append([k + " proofread", k, {"face": 1.0, "proof": 1.0, "state": "idle"}])
			out.append(["bare windup", "bare", {"face": 1.0, "proof": 0.0, "state": "windup"}])
			out.append(["bare facing left", "bare", {"face": -1.0, "proof": 0.0, "state": "idle"}])
			out.append(["mite hurt", "mite", {"face": 1.0, "flash": 0.2}])
		"bosses":
			out.append(["critic", "critic", {"layers": 3, "t": 0.0}])
			out.append(["critic (reckoning)", "critic", {"layers": 0}])
			out.append(["critic shouting", "critic", {"layers": 2, "tele": 0.5}])
			out.append(["spoiler", "spoiler", {}])
			out.append(["cold shoulder (to you)", "cold_shoulder", {"face": Vector2(1, 0.3)}])
			out.append(["cold shoulder (from behind)", "cold_shoulder", {"face": Vector2(-1, 0.3), "weak": true}])
			out.append(["scissor-man", "scissor_man", {}])
			out.append(["scissor-man jammed", "scissor_man", {"jam": true}])
			out.append(["scissor-man snipping", "scissor_man", {"snip": 0.8}])
	return out

func _m(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := a.duplicate()
	d.merge(b, true)
	return d

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), BGS[bg])
	var font := ThemeDB.get_default_theme().default_font
	var style := ArtStyles.get_style(style_id)
	var names: String = ArtStyles.NAMES.get(style_id, style_id)
	draw_string(font, Vector2(24, 34), "ART LAB   %s   ·   sheet: %s   ·   zoom %.1fx" % [names, sheet, zoom], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.1, 0.08, 0.1) if bg < 2 else Color.WHITE)
	draw_string(font, Vector2(24, vs.y - 14), "A/D style   W/S sheet   Q/E zoom   Space background   P pause   Esc leave", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.1, 0.08, 0.1, 0.7) if bg < 2 else Color(1, 1, 1, 0.7))
	var cells := _cells()
	var cols := 6
	var cw := (vs.x - 40.0) / cols
	var rows := int(ceil(cells.size() / float(cols)))
	var ch := (vs.y - 100.0) / maxf(rows, 1)
	for i in cells.size():
		var c: Array = cells[i]
		var pos := Vector2(20.0 + (i % cols) * cw + cw * 0.5, 60.0 + (i / cols) * ch + ch * 0.82)
		var ctx: Dictionary = (c[2] as Dictionary).duplicate()
		ctx["t"] = t
		ctx["origin"] = pos
		ctx["scale"] = zoom
		if style != null and ctx.get("moving", false) and not ctx.has("phase"):
			ctx["phase"] = t * 9.0
		var ok := false
		if style != null:
			draw_set_transform(pos, 0.0, Vector2(zoom, zoom * 0.5))
			draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.22))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ok = style.draw_prop(self, c[1], ctx) if String(c[1]).begins_with("prop_") else style.draw_character(self, c[1], ctx)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not ok:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var lbl := "(original art)" if style == null else "(not drawn in this style yet)"
			draw_string(font, pos + Vector2(-60, -30), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.3, 0.3, 0.3, 0.8) if bg < 2 else Color(1, 1, 1, 0.5))
		draw_string(font, pos + Vector2(-cw * 0.5 + 10, 14), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.1, 0.08, 0.1, 0.8) if bg < 2 else Color(1, 1, 1, 0.7))
