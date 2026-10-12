class_name PuzzleSites
extends Node
## The overworld's puzzle sites, built from PrologueMap.SITES (see tools/gen_phase2.py). Every site guards
## a chest and borrows a skill the Storytender learned somewhere else:
##   echo     two weighing plates and a sealed stair. Remember an Echo (Garrick's memory) to hold one plate
##            while you stand on the other.
##   words    three sentence stones (Pip's rewriting) and a sign that says how they should read; a bridge of
##            pages unrolls across a moat of plot holes when they are right.
##   arena    step on the plate and the gate slams shut; beat the waves of Errors and it opens again.
##   crumble  a ravine and a zig-zag causeway of loose pages that crumble a moment after you step on them.
## Side dungeons (PORTALS) are doorways into small memories of their own.
## The vault trials (the minigames) still guard two of the old riddle chests; see main.gd.

const KIND_OF := {"g": Enemy.Kind.BARE, "x": Enemy.Kind.MITE, "l": Enemy.Kind.SLUG, "d": Enemy.Kind.DANGLER, "n": Enemy.Kind.CENSOR, "z": Enemy.Kind.ELLIPSIS}
const PORTAL_NEEDS := {"weighing": "memory_done", "proof": "has_quill"}
const PORTAL_NEED_TEXT := {"weighing": "It does not open yet. Something in you has to learn to be in two places at once first: finish Garrick's memory.",
	"proof": "It does not open yet. You would need something to write with before a place like this would take you seriously."}

var lvl                      # the overworld (a LevelBase)
var _st: Dictionary = {}     # site id -> runtime state

# --- queries used by the level -------------------------------------------------------------------
static func solved(id: String) -> bool:
	return GameState.has_flag("site_" + id)

## The site (if any) that keeps the chest at this cell shut. Crumble sites never lock their chest.
static func site_for_chest(cell: Vector2i) -> String:
	for id in PrologueMap.SITES.keys():
		var sd: Dictionary = PrologueMap.SITES[id]
		var c: Array = sd["chest"]
		if Vector2i(int(c[0]), int(c[1])) == cell and String(sd["type"]) != "crumble":
			return id
	return ""

static func chest_locked(cell: Vector2i) -> bool:
	var id := site_for_chest(cell)
	return id != "" and not solved(id)

# --- setup ---------------------------------------------------------------------------------------------
func setup(level) -> void:
	lvl = level
	for id in PrologueMap.SITES.keys():
		var sd: Dictionary = PrologueMap.SITES[id]
		match String(sd["type"]):
			"echo": _setup_echo(id, sd)
			"words": _setup_words(id, sd)
			"arena": _setup_arena(id, sd)
			"crumble": _setup_crumble(id, sd)
	for pid in PrologueMap.PORTALS.keys():
		_setup_portal(pid, PrologueMap.PORTALS[pid])

func _c(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

func _gate(cell: Vector2i, axis: Array, label: String, open_now: bool) -> StoryGate:
	var g := StoryGate.new()
	g.axis = Vector2(float(axis[0]), float(axis[1]))
	g.length = 3.0
	g.label = label
	g.position = Iso.to_screen(Vector2(cell))
	g.elev = lvl._lift_at(cell)
	lvl._actors.add_child(g)
	if open_now:
		g.open()
	return g

func _sign(cell: Vector2i, text_id: String) -> void:
	var s: Prop = lvl._add_prop(Prop.Kind.SIGN, cell)
	lvl._register(s, func(): return "Read", func(): await lvl._say(Story.lore(text_id)))

func _plate(cell: Vector2i) -> EchoPlate:
	var p := EchoPlate.new()
	p.floor_ref = lvl._floor
	p.player = lvl._player
	p.position = Iso.to_screen(Vector2(cell))
	p.elev = lvl._lift_at(cell)
	lvl._actors.add_child(p)
	return p

func _finish(id: String, toast_text: String) -> void:
	GameState.set_flag("site_" + id)
	GameState.add_renown(4)
	lvl._hud.toast(toast_text)
	Telemetry.log_event("puzzle", {"p": "site_" + id})

# --- echo -----------------------------------------------------------------------------------------------
func _setup_echo(id: String, sd: Dictionary) -> void:
	var done := solved(id)
	var gate := _gate(_c(sd["gate"]), sd["axis"], "WEIGHED", done)
	var plates: Array[EchoPlate] = []
	for p: Array in sd["plates"]:
		plates.append(_plate(_c(p)))
	_sign(_c(sd["hint"]), String(sd["hint_id"]))
	_st[id] = {"gate": gate, "plates": plates}

func _tick_echo(id: String) -> void:
	if solved(id):
		return
	var s: Dictionary = _st[id]
	for p: EchoPlate in s["plates"]:
		if not p.pressed:
			return
	(s["gate"] as StoryGate).open()
	_finish(id, "The plates settle. The way is open.")

# --- words ----------------------------------------------------------------------------------------------
func _setup_words(id: String, sd: Dictionary) -> void:
	var done := solved(id)
	var stones: Array[SentenceStone] = []
	var n_st: int = sd["stones"].size()
	for d: Dictionary in sd["stones"]:
		var st := SentenceStone.new()
		st.tablet_dx = (float(stones.size()) - (n_st - 1) * 0.5) * 28.0
		st.prefix = d["prefix"]
		st.options = PackedStringArray(d["options"])
		st.suffix = d["suffix"]
		var cell := _c(d["cell"])
		st.position = Iso.to_screen(Vector2(cell))
		st.elev = lvl._lift_at(cell)
		lvl._actors.add_child(st)
		lvl._register(st, func(): return "Rewrite" if not st.locked else "", func(): st.rewrite(), 80.0)
		if done:
			st.index = int(d["good"])
			st.locked = true
		else:
			st.rewritten.connect(func(_s, _i): _check_words(id))
		stones.append(st)
	_sign(_c(sd["sign"]), String(sd["sign_id"]))
	_st[id] = {"stones": stones}
	if done:
		_build_bridge(sd, false)

func _check_words(id: String) -> void:
	if solved(id):
		return
	var sd: Dictionary = PrologueMap.SITES[id]
	var stones: Array = _st[id]["stones"]
	for i in stones.size():
		if (stones[i] as SentenceStone).index != int(sd["stones"][i]["good"]):
			return
	for st: SentenceStone in stones:
		st.locked = true
	_build_bridge(sd, true)
	_finish(id, "The sentence holds. A bridge of pages unrolls.")

func _build_bridge(sd: Dictionary, fx: bool) -> void:
	for c: Array in sd["bridge"]:
		var cell := _c(c)
		lvl.set_cell_kind(cell, ".")
		if fx:
			lvl._floor.marks[cell] = {"kind": "flower", "t": 0.0}
	if fx:
		lvl.camera_shake(0.3, 3.0)

# --- arena ----------------------------------------------------------------------------------------------
func _setup_arena(id: String, sd: Dictionary) -> void:
	var done := solved(id)
	var gate := _gate(_c(sd["gate"]), sd["axis"], "PROOF", true)
	var plate: EchoPlate = null
	if not done:
		plate = _plate(_c(sd["trigger"]))
	_st[id] = {"gate": gate, "plate": plate, "state": "idle", "wave": 0, "foes": []}

func _spawn_wave(id: String) -> void:
	var s: Dictionary = _st[id]
	var sd: Dictionary = PrologueMap.SITES[id]
	var waves: Array = sd["waves"]
	var foes: Array = []
	for e: Array in waves[int(s["wave"])]:
		var kind: Enemy.Kind = KIND_OF.get(String(e[2]), Enemy.Kind.BARE)
		var en: Enemy = lvl._add_enemy(kind, Vector2i(int(e[0]), int(e[1])))
		en.asleep_t = 0.0
		foes.append(en)
	s["foes"] = foes

func _tick_arena(id: String) -> void:
	var s: Dictionary = _st[id]
	if solved(id):
		return
	match String(s["state"]):
		"idle":
			var plate: EchoPlate = s["plate"]
			if plate != null and plate.pressed and not lvl._player.is_falling:
				s["state"] = "fight"
				s["wave"] = 0
				(s["gate"] as StoryGate).close()
				lvl._hud.toast("The gate slams shut behind you.")
				lvl.camera_shake(0.3, 4.0)
				_spawn_wave(id)
		"fight":
			var alive := false
			for e in s["foes"]:
				if is_instance_valid(e):
					alive = true
					break
			if alive:
				return
			s["wave"] = int(s["wave"]) + 1
			var waves: Array = (PrologueMap.SITES[id] as Dictionary)["waves"]
			if int(s["wave"]) >= waves.size():
				s["state"] = "done"
				(s["gate"] as StoryGate).open()
				_finish(id, "The ring falls quiet. The gate is open.")
			else:
				lvl._hud.toast("Another wave.")
				_spawn_wave(id)

# --- crumble ---------------------------------------------------------------------------------------------
func _setup_crumble(id: String, sd: Dictionary) -> void:
	var cells: Dictionary = {}
	for c: Array in sd["cells"]:
		cells[_c(c)] = {"state": "solid", "t": 0.0}
	_st[id] = {"cells": cells}

func _tick_crumble(id: String, delta: float) -> void:
	var s: Dictionary = _st[id]
	var sd: Dictionary = PrologueMap.SITES[id]
	var cells: Dictionary = s["cells"]
	var done := solved(id)
	var pcell: Vector2i = lvl._floor.cell_at(lvl._player.position)
	if not done:
		var ch := _c(sd["chest"])
		if absi(pcell.x - ch.x) <= 1 and absi(pcell.y - ch.y) <= 1 and not lvl._player.is_falling:
			_finish(id, "Solid ground. The causeway will hold now.")
			done = true
	for c: Vector2i in cells.keys():
		var d: Dictionary = cells[c]
		match String(d["state"]):
			"solid":
				if not done and pcell == c and not lvl._player.is_falling:
					d["state"] = "cracking"
					d["t"] = 0.8
					lvl._floor.marks[c] = {"kind": "crack", "t": 0.0}
			"cracking":
				d["t"] = float(d["t"]) - delta
				if done:
					d["state"] = "solid"
					lvl._floor.marks.erase(c)
				elif float(d["t"]) <= 0.0:
					d["state"] = "gone"
					d["t"] = 5.0
					lvl._floor.marks.erase(c)
					lvl.set_cell_kind(c, "#")
			"gone":
				d["t"] = float(d["t"]) - delta
				if done or float(d["t"]) <= 0.0:
					d["state"] = "solid"
					lvl.set_cell_kind(c, ".")

# --- side dungeons ----------------------------------------------------------------------------------------
func _setup_portal(pid: String, pd: Dictionary) -> void:
	var cell := _c(pd["cell"])
	var p: Prop = lvl._add_prop(Prop.Kind.PORTAL, cell)
	var need: String = PORTAL_NEEDS.get(pid, "")
	lvl._register(p, func(): return "Enter %s" % pd["name"], func(): await _enter_portal(pid, pd, need), 90.0)

func _enter_portal(pid: String, pd: Dictionary, need: String) -> void:
	if need != "" and not GameState.has_flag(need):
		await lvl._say([Story.line("", String(pd["blurb"]), "action"), Story.line("", String(PORTAL_NEED_TEXT.get(pid, "It does not open yet.")), "action")])
		return
	GameState.spawn_cell = _c(pd["return"])
	Telemetry.log_event("puzzle", {"p": "enter_" + pid})
	Transition.go(String(pd["scene"]), Palette.CYAN.lightened(0.7))

# --- per frame ---------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if lvl == null or lvl._player == null:
		return
	for id in _st.keys():
		match String(PrologueMap.SITES[id]["type"]):
			"echo": _tick_echo(id)
			"arena": _tick_arena(id)
			"crumble": _tick_crumble(id, delta)

## The player died: any fight in progress resets (the level has already cleared the Errors).
func on_death_reset() -> void:
	for id in _st.keys():
		var sd: Dictionary = PrologueMap.SITES[id]
		if String(sd["type"]) == "arena" and not solved(id):
			var s: Dictionary = _st[id]
			s["state"] = "idle"
			s["wave"] = 0
			s["foes"] = []
			(s["gate"] as StoryGate).open()
		elif String(sd["type"]) == "crumble":
			for c: Vector2i in (_st[id]["cells"] as Dictionary).keys():
				var d: Dictionary = _st[id]["cells"][c]
				if d["state"] != "solid":
					d["state"] = "solid"
					lvl._floor.marks.erase(c)
					lvl.set_cell_kind(c, ".")
