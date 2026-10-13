class_name SideWeighing
extends SideDungeon
## The Weighing Room: a counting-house that weighs everything and finds it wanting. Three rooms of weighing
## plates. You can only stand on one plate, but you can remember yourself standing on another: press {echo}
## to record a ghost of your walk, press it again to stop, and the ghost plays it back and STANDS where it
## ended. Two ghosts at a time, so room 1 asks for both of them. Room 2 has three plates: the Locket of Second
## Thoughts, lying just inside it, lets you keep a third.

const ROOM_GATES := [["g", ["a", "b"]], ["h", ["c", "d", "e"]], ["i", ["f", "j"]]]
const INTRO := "A counting-house that has weighed every word ever spoken in it and found each one a little short. The scales are still swinging."
const ROOM_HINTS := [
	"Two plates. One gate. Weigh in as two.",
	"Three plates, in three places. A locket lies in the room: it lets you remember three times.",
	"A bridge, a pit, and guards who weigh everything. Your Echo may lure them while you hold the far plate.",
]
const FINALE := "The scales settle at last. Whatever you weighed, it was worth the weight."

var _plate_nodes: Dictionary = {}
var _gate_nodes: Dictionary = {}
var _gate_seen := {}

func dungeon_id() -> String:
	return "weighing"

func _room_edges() -> Array:
	return [14, 31, 48]

func _room_names() -> Array:
	return ["The Tare Room", "The Balance Hall", "The Bridge of Scales", "The Counting-House Vault"]

func _room_starts() -> Array:
	return [Vector2i(5, 10), Vector2i(18, 10), Vector2i(35, 10), Vector2i(52, 10)]

func _reward_item() -> String:
	return "hourglass_of_drafts"

func _map_rows() -> Array[String]:
	return SideWeighingMap.ROWS

func _map_heights() -> Array[String]:
	return SideWeighingMap.HEIGHTS

func _paper_params() -> Dictionary:
	return {"paper_light": Color(0.30, 0.27, 0.22), "paper_dark": Color(0.11, 0.10, 0.09), "script_color": Color(0.85, 0.72, 0.40),
		"script_strength": 0.08, "vignette": 0.6}

func _dungeon_extras() -> Array:
	return [
		{"kind": "post", "cell": Vector2i(54, 8)},
		{"kind": "mob", "cell": Vector2i(22, 8), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(27, 12), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(37, 7), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(37, 13), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(46, 8), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(46, 12), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(44, 10), "mob": Enemy.Kind.CENSOR},
	]

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	match ch:
		"a", "b", "c", "d", "e", "f", "j":
			_floor.cells[cell] = "m"
			var plate := EchoPlate.new()
			plate.floor_ref = _floor
			plate.position = Iso.to_screen(Vector2(cell))
			plate.elev = _lift_at(cell)
			_actors.add_child(plate)
			_plate_nodes[ch] = plate
		"g", "h", "i":
			_floor.cells[cell] = "m"
			var gate := StoryGate.new()
			gate.axis = Vector2(0, 1)
			gate.length = 3.0
			gate.label = "WEIGHED"
			gate.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(gate)
			_gate_nodes[ch] = gate
		"L":
			_floor.cells[cell] = "m"
			if not GameState.has_flag("echo_third"):
				var key := DungeonKey.new()
				key.kind = "locket"
				key.position = Iso.to_screen(Vector2(cell))
				key.elev = _lift_at(cell)
				_actors.add_child(key)
				_register(key, func(): return "Take the Locket of Second Thoughts", func(): _take_locket(key), 80.0)
		_:
			return super._spawn_char(ch, cell, consumed)
	return true

func _level_ready() -> void:
	echo_enabled = true
	for plate: EchoPlate in _plate_nodes.values():
		plate.player = _player
	_hud.set_region("The Weighing Room")
	_hud.set_objective(ROOM_HINTS[0])
	await get_tree().create_timer(2.0).timeout
	_hud.narrate(INTRO, false, 5.0)
	if not GameState.has_flag("tut_echo"):
		GameState.set_flag("tut_echo")
		if Settings.tutorial_tips:
			_busy = true
			await _hud.tutorial("echo")
			_busy = false

func _on_room_entered(room: int) -> void:
	if room > 0 and room < ROOM_HINTS.size():
		_hud.set_objective(ROOM_HINTS[room])
	elif room == 3:
		_hud.set_objective("Take what the scales were guarding")

func _level_process(delta: float) -> void:
	super._level_process(delta)
	for pair in ROOM_GATES:
		var gk: String = pair[0]
		if not _gate_nodes.has(gk):
			continue
		var gate: StoryGate = _gate_nodes[gk]
		var want := true
		for pk: String in pair[1]:
			if not _plate_nodes.has(pk) or not (_plate_nodes[pk] as EchoPlate).pressed:
				want = false
		if want and not gate.is_open:
			gate.open()
			if not _gate_seen.has(gk):
				_gate_seen[gk] = true
				_hud.toast("The scales balance. The gate swings open.")
				Telemetry.log_event("puzzle", {"p": "weighing_gate_" + gk})
		elif not want and gate.is_open and _dist(_player.position, gate.position) > 90.0:
			gate.close()

func _take_locket(key: DungeonKey) -> void:
	GameState.set_flag("echo_third")
	Telemetry.log_event("puzzle", {"p": "echo_locket"})
	create_tween().tween_property(key, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(key.queue_free)
	_hud.toast("Found: the Locket of Second Thoughts. You can keep three Echoes.")
	_hud.narrate("A locket on a thin chain. Inside, three tiny portraits of the same person, none of them quite agreeing.", false, 6.0)

func _on_reward_taken() -> void:
	_hud.narrate(FINALE, false, 5.0)

func _on_death_reset() -> void:
	_clear_echoes()
