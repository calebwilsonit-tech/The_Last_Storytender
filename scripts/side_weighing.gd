class_name SideWeighing
extends SideDungeon
## The Weighing Room: a counting-house that weighs everything and finds it wanting. Every room asks a different
## question about Echoes (see docs/dungeon_plans/side_weighing_room.png):
##  The Tare Room     - one Echo holds a door.
##  The Relay         - an Echo holds the cage while the next is recorded inside it. The Locket (a third Echo) lies here.
##  Night Shift       - two guards watch the plates; Echoes get there for you.
##  The Pan Room      - an Echo holds a bridge up; a second draws the far guard off.
##  The Counterweights - three guarded rooms in a row; each Echo's plate holds open the door to the next room.
## Three weights on the hub's scale open the Vault.

## Echo gates: gate char -> the plates that hold it open.
const ECHO_GATES := [["A", ["a"]], ["x", ["b"]], ["y", ["c"]], ["B", ["d", "e"]], ["s", ["p"]], ["t", ["q"]], ["W", ["p", "q", "r"]]]
## Gates that stay open once opened: the Tare Room's gate is behind you for good, so the first Echo is free to be reused
## (before the Locket you can only keep two Echoes, and the Relay needs both).
const LATCHED := ["A"]
const GATE_AXIS := {"A": Vector2(1, 0), "x": Vector2(1, 0), "y": Vector2(0, 1), "B": Vector2(1, 0), "s": Vector2(0, 1),
	"t": Vector2(0, 1), "W": Vector2(1, 0), "D": Vector2(1, 0)}
const WEIGHTS := {"T": "weight_one", "U": "weight_two", "V": "weight_three"}
const R_HUB := 0
const R_TARE := 1
const R_RELAY := 2
const R_NIGHT := 3
const R_PAN := 4
const R_COUNTER := 5
const R_PLUMB := 6
const R_VAULT := 7
const INTRO := "A counting-house that has weighed every word ever spoken in it and found each one a little short. The scales are still swinging."
const ROOM_HINTS := [
	"Three weights hang in three wings. Bring them to the scale.",
	"A plate on a ledge. You cannot stand on it and walk away. Something that remembers you can.",
	"One plate opens the cage. Another is inside it. Remember twice, in order.",
	"The guards watch the plates. Send something that they will not shoot at.",
	"The bridge is only there while the pan is weighed down. Something has to stay.",
	"Three plates, each in a room behind a door that the plate before it holds open. Guards watch every room.",
	"The last weight, and no one to guard it.",
	"What the scales were guarding.",
]
const FINALE := "The scales settle at last. Whatever you weighed, it was worth the weight."

var _plate_nodes: Dictionary = {}
var _gate_nodes: Dictionary = {}
var _gate_seen := {}
var _enemy_cells: Array[Vector2i] = []
var _weights := {}
var _scale: StoryGate
var _pan_on := false

func dungeon_id() -> String:
	return "weighing"

func _room_for(cell: Vector2i) -> int:
	if cell.x >= 44:
		return R_PLUMB if (cell.y <= 15 and cell.x >= 54) else R_COUNTER
	if cell.y >= 27 and cell.x >= 24 and cell.x <= 40:
		return R_VAULT
	if cell.x <= 22:
		return R_RELAY if cell.y <= 17 else R_TARE
	if cell.y <= 4 and cell.x >= 24 and cell.x <= 40:
		return R_PAN
	if cell.y <= 16 and cell.x >= 24 and cell.x <= 40:
		return R_NIGHT
	return R_HUB

func _room_names() -> Array:
	return ["The Counting House", "The Tare Room", "The Relay", "Night Shift", "The Pan Room", "The Counterweights", "The Plumb Room", "The Vault"]

func _room_starts() -> Array:
	return [Vector2i(26, 22), Vector2i(14, 24), Vector2i(14, 15), Vector2i(32, 14), Vector2i(27, 4), Vector2i(45, 24), Vector2i(58, 15), Vector2i(32, 30)]

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
	return []

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	match ch:
		"a", "b", "c", "d", "e", "f", "p", "q", "r":
			_floor.cells[cell] = "m"
			var plate := EchoPlate.new()
			plate.floor_ref = _floor
			plate.position = Iso.to_screen(Vector2(cell))
			plate.elev = _lift_at(cell)
			_actors.add_child(plate)
			_plate_nodes[ch] = plate
		"A", "x", "y", "B", "s", "t", "W", "D":
			_floor.cells[cell] = "m"
			var gate := StoryGate.new()
			gate.axis = GATE_AXIS[ch]
			gate.length = 3.0
			gate.label = "WEIGHED" if ch != "D" else "WEIGHED 0/3"
			gate.position = Iso.to_screen(Vector2(cell))
			gate.elev = _lift_at(cell)
			_actors.add_child(gate)
			if ch == "D":
				_scale = gate
			else:
				_gate_nodes[ch] = gate
		"T", "U", "V":
			_floor.cells[cell] = "m"
			var key := DungeonKey.new()
			key.kind = "weight"
			key.position = Iso.to_screen(Vector2(cell))
			key.elev = _lift_at(cell)
			_actors.add_child(key)
			_register(key, func(): return "Take the weight", func(): _take_weight(key, ch), 80.0)
		"g":
			_floor.cells[cell] = "m"
			_enemy_cells.append(cell)
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
	for c in _enemy_cells:
		_add_enemy(Enemy.Kind.BARE, c)
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
	if room != R_HUB and room < ROOM_HINTS.size():
		_hud.set_objective(ROOM_HINTS[room])

func _level_process(delta: float) -> void:
	super._level_process(delta)
	for pair in ECHO_GATES:
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
				_hud.toast("The scales balance. The way opens.")
				Telemetry.log_event("puzzle", {"p": "weighing_gate_" + gk})
		elif not want and gate.is_open and not LATCHED.has(gk) and _dist(_player.position, gate.position) > 90.0:
			gate.close()
	_tick_pan()

## The Pan Room's bridge exists only while the pan plate is weighed down. It will not drop you into the pit.
func _tick_pan() -> void:
	if not _plate_nodes.has("f"):
		return
	var want: bool = (_plate_nodes["f"] as EchoPlate).pressed
	if want == _pan_on:
		return
	if not want:
		var here := _floor.cell_at(_player.position)
		if SideWeighingMap.PAN_CELLS.has(here) and not _player.is_falling:
			return
	_pan_on = want
	for c: Vector2i in SideWeighingMap.PAN_CELLS:
		_floor.cells[c] = "b" if want else "#"
	if want:
		_hud.toast("The pan sinks. A bridge of page edges slides out.")

func _take_weight(key: DungeonKey, ch: String) -> void:
	_weights[ch] = true
	Telemetry.log_event("puzzle", {"p": "weighing_weight_" + ch})
	create_tween().tween_property(key, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(key.queue_free)
	_hud.toast("Found: a weight (%d/3)" % _weights.size())
	if is_instance_valid(_scale):
		_scale.label = "WEIGHED %d/3" % _weights.size()
		_scale.queue_redraw()
		if _weights.size() >= WEIGHTS.size():
			_scale.open()
			_hud.set_objective("The scale tips. The vault is open.")
			_hud.narrate("Three weights on the scale. It sighs, and for once it is satisfied.", false, 5.0)

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
