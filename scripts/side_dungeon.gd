class_name SideDungeon
extends LevelBase
## Shared plumbing for the prologue's small side dungeons (entered from doorways out in the wild, see
## PrologueMap.PORTALS). Each is a few rooms long, built around ONE skill learned elsewhere, and ends in a
## reward. Subclasses supply the map, the rooms and the puzzles.

const OVERWORLD := "res://scenes/main.tscn"

var _leaving := false
var _looked_at := {}
var _reward_taken := false
var _reward: Prop
var _reward_spawned := false

## Which doorway this is (a key of PrologueMap.PORTALS).
func dungeon_id() -> String:
	return ""

## x cells where room N ends (room 0 is x <= edges[0], and so on); names and respawn cells per room.
func _room_edges() -> Array:
	return []

func _room_names() -> Array:
	return []

func _room_starts() -> Array:
	return []

func _reward_item() -> String:
	return ""

func _room_for(cell: Vector2i) -> int:
	var edges := _room_edges()
	for i in edges.size():
		if cell.x <= int(edges[i]):
			return i
	return edges.size()

func _room_name(cell: Vector2i) -> String:
	var names := _room_names()
	return String(names[mini(_room_for(cell), names.size() - 1)])

func _checkpoint_for(cell: Vector2i) -> Vector2:
	var starts := _room_starts()
	var i := mini(_room_for(cell), starts.size() - 1)
	return Iso.to_screen(Vector2(starts[i]))

func _music_slot() -> String:
	return "side_dungeon"

func _spawn_char(ch: String, cell: Vector2i, _consumed: Dictionary) -> bool:
	match ch:
		"P":
			_floor.cells[cell] = "m"
			_start = Iso.to_screen(Vector2(cell))
			_map_start = _start
		"E":
			_floor.cells[cell] = "m"
			var portal := _add_prop(Prop.Kind.PORTAL, cell)
			_register(portal, func(): return "" if _leaving else "Leave this place", _leave, 70.0)
		"k":
			_floor.cells[cell] = "m"
			_reward = _add_pickup(cell, _reward_item())
			_reward_spawned = true
		_:
			return false
	return true

func _level_process(_delta: float) -> void:
	if not _reward_taken and _reward_spawned and not is_instance_valid(_reward):
		_reward_taken = true
		GameState.set_flag("side_" + dungeon_id() + "_done")
		GameState.add_renown(15)
		Telemetry.log_event("puzzle", {"p": "side_done_" + dungeon_id()})
		_on_reward_taken()
	var r := _room_for(_floor.cell_at(_player.position))
	if not _looked_at.has(r):
		_looked_at[r] = true
		_on_room_entered(r)

func _on_room_entered(_room: int) -> void:
	pass

func _on_reward_taken() -> void:
	pass

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var pd: Dictionary = PrologueMap.PORTALS.get(dungeon_id(), {})
	if not pd.is_empty():
		GameState.spawn_cell = Vector2i(int(pd["return"][0]), int(pd["return"][1]))
	GameState.save_game()
	Transition.go(OVERWORLD, Palette.CYAN.lightened(0.7))
	await get_tree().create_timer(30.0).timeout
	_leaving = false
