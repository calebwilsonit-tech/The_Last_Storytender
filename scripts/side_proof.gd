class_name SideProof
extends SideDungeon
## The Proof Room: where text is checked before it is allowed out. Dark, and full of black redaction bars.
## Hold the Lantern on a bar and what is written under it is revealed. Three plaques in the galley hold the
## words that three sentence stones need (Pip's rewriting); the press beyond is full of Censors; the last
## proof is guarded by Ellipses that blink in and out.

const INTRO := "Proofs, galleys, red pencil. Every wall has a mark on it, and every mark is a question."
const PLAQUES := [
	{"cell": Vector2i(8, 4), "text": "COLOPHON: 'Set in a living hand. The author is ALIVE, whatever the cover says.'"},
	{"cell": Vector2i(12, 4), "text": "ERRATA: 'The ending is UNWRITTEN. Anyone who tells you otherwise is guessing.'"},
	{"cell": Vector2i(16, 4), "text": "DEDICATION: 'For the reader, who is always WELCOME, even when late.'"},
]
const STONES := [
	{"ch": "s", "prefix": "The author is", "options": ["DEAD", "ALIVE", "ABSENT"], "good": 1},
	{"ch": "t", "prefix": "The ending is", "options": ["KNOWN", "TRAGIC", "UNWRITTEN"], "good": 2},
	{"ch": "u", "prefix": "The reader is", "options": ["BORED", "WELCOME", "LATE"], "good": 1},
]
const FINALE := "Approved for release, the stamp says. It is the first approval you have ever seen that did not feel like a verdict."

var _gate: StoryGate
var _stones: Array[SentenceStone] = []
var _revealed := [false, false, false]
var _plaque_props: Array[Prop] = []
var _solved := false

func dungeon_id() -> String:
	return "proof"

func _room_edges() -> Array:
	return [20, 37, 40]

func _room_names() -> Array:
	return ["The Galley", "The Press", "The Corridor of Marks", "The Last Proof"]

func _room_starts() -> Array:
	return [Vector2i(5, 9), Vector2i(22, 9), Vector2i(38, 9), Vector2i(41, 9)]

func _reward_item() -> String:
	return "censors_monocle"

func _map_rows() -> Array[String]:
	return SideProofMap.ROWS

func _map_heights() -> Array[String]:
	return SideProofMap.HEIGHTS

func _paper_params() -> Dictionary:
	return {"paper_light": Color(0.22, 0.20, 0.26), "paper_dark": Color(0.08, 0.07, 0.11), "script_color": Color(0.80, 0.30, 0.34),
		"script_strength": 0.10, "vignette": 0.7}

func _dungeon_extras() -> Array:
	return [
		{"kind": "post", "cell": Vector2i(43, 6)},
		{"kind": "mob", "cell": Vector2i(25, 6), "mob": Enemy.Kind.CENSOR},
		{"kind": "mob", "cell": Vector2i(25, 12), "mob": Enemy.Kind.CENSOR},
		{"kind": "mob", "cell": Vector2i(34, 6), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(34, 9), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(34, 12), "mob": Enemy.Kind.DANGLER},
		{"kind": "mob", "cell": Vector2i(45, 7), "mob": Enemy.Kind.ELLIPSIS},
		{"kind": "mob", "cell": Vector2i(47, 12), "mob": Enemy.Kind.ELLIPSIS},
		{"kind": "mob", "cell": Vector2i(52, 6), "mob": Enemy.Kind.ELLIPSIS},
	]

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	match ch:
		"x", "y", "z":
			_floor.cells[cell] = "m"
			var idx := "xyz".find(ch)
			var plaque := _add_prop(Prop.Kind.SIGN, cell)
			_plaque_props.append(plaque)
			_register(plaque, func(): return "Read" if _revealed[idx] else "", func(): await _say([Story.line("", PLAQUES[idx]["text"], "action")]))
			var bar := _add_redactor(cell + Vector2i(0, 1), Vector2(1, 0), 2.0, "██████")
			bar.revealed.connect(func():
				_revealed[idx] = true
				_hud.toast("Revealed: read the plaque."))
		"s", "t", "u":
			_floor.cells[cell] = "m"
			var i := "stu".find(ch)
			var d: Dictionary = STONES[i]
			var st := SentenceStone.new()
			st.prefix = d["prefix"]
			st.options = PackedStringArray(d["options"])
			st.suffix = "."
			st.position = Iso.to_screen(Vector2(cell))
			st.elev = _lift_at(cell)
			_actors.add_child(st)
			_register(st, func(): return "Rewrite" if not st.locked else "", func(): st.rewrite(), 80.0)
			st.rewritten.connect(func(_s, _i): _check_stones())
			_stones.append(st)
		"g":
			_floor.cells[cell] = "m"
			_gate = StoryGate.new()
			_gate.axis = Vector2(0, 1)
			_gate.length = 3.0
			_gate.label = "PROOFING"
			_gate.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(_gate)
		"R":
			_floor.cells[cell] = "m"
			var bar := _add_redactor(cell, Vector2(0, 1), 3.0, "the way on")
			bar.revealed.connect(func(): _hud.narrate("The black bar lifts. Underneath, in red pencil: 'fine.'", false, 4.0))
		_:
			return super._spawn_char(ch, cell, consumed)
	return true

func _level_ready() -> void:
	_hud.set_dark(true)
	_player.lantern_power = 1.7
	_hud.set_region("The Proof Room")
	_hud.set_objective("Hold the Lantern on the black bars to read what is under them")
	await get_tree().create_timer(2.0).timeout
	_hud.narrate(INTRO, false, 5.0)

func _on_room_entered(room: int) -> void:
	match room:
		1:
			_hud.set_objective("Clear the press, then read the bar across the corridor")
		3:
			_hud.set_objective("Take what the proofreader was guarding")

func _check_stones() -> void:
	if _solved:
		return
	for i in _stones.size():
		if _stones[i].index != int(STONES[i]["good"]):
			return
	_solved = true
	for st in _stones:
		st.locked = true
	if _gate != null:
		_gate.open()
	_hud.toast("Approved. The gate lifts.")
	Telemetry.log_event("puzzle", {"p": "proof_stones"})

func _on_reward_taken() -> void:
	_hud.narrate(FINALE, false, 5.0)
