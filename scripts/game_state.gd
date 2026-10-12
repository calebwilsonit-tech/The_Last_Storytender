extends Node
## Global story state (autoload as GameState).

signal mnemosynth_changed(value: int)
signal restoration_finished
signal inventory_changed

const RESTORE_DURATION := 7.0
const WAVE_SOFT_EDGE := 190.0     # px of ink "bleeding in" at the wave front

var mnemosynth := 0
var ink := 100.0                  # carried between scenes
var spawn_cell := Vector2i(-1, -1)  # where the overworld should place the player (-1 = map start)
var flags: Dictionary = {}
var in_dialogue := false

# --- Inventory -------------------------------------------------------------------------
var inventory: Dictionary = {}                     # item id -> count
var equipment: Dictionary = {"binding": "", "amulet": ""}
var quick_slot := ""                               # consumable bound to the F key

const SAVE_PATH := "user://savegame.json"
var autosave_enabled := true

var wave_origin := Vector2.ZERO
var wave_radius := 0.0            # px; 0 = ghost town, >= FULL = restored
var town_restored := false

const FULL := 100000.0

func has_flag(f: String) -> bool:
	return flags.has(f)

func set_flag(f: String) -> void:
	flags[f] = true
	save_game()

func add_mnemosynth(n: int) -> void:
	mnemosynth += n
	mnemosynth_changed.emit(mnemosynth)

## 0..1 how "written" the world is at a position (iso-corrected circular wave).
func restored_at(pos: Vector2) -> float:
	if wave_radius >= FULL:
		return 1.0
	if wave_radius <= 0.0:
		return 0.0
	var d := pos - wave_origin
	d.y *= 2.0
	return clampf((wave_radius - d.length()) / WAVE_SOFT_EDGE, 0.0, 1.0)

func start_restoration(origin: Vector2) -> void:
	wave_origin = origin
	wave_radius = 1.0
	var tw := create_tween()
	tw.tween_property(self, "wave_radius", 2600.0, RESTORE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	wave_radius = FULL
	town_restored = true
	save_game()
	restoration_finished.emit()

# --- Items ---------------------------------------------------------------------------------
func count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n
	if ItemDB.info(id)["type"] == "consumable" and quick_slot == "":
		quick_slot = id
	inventory_changed.emit()
	save_game()

func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
		if quick_slot == id:
			quick_slot = ""
		# Gear stays equipped even though it leaves the grid; only consumables are consumed.
	inventory_changed.emit()
	save_game()
	return true

func is_equipped(id: String) -> bool:
	return equipment["binding"] == id or equipment["amulet"] == id

## Equip or (if already worn) unequip a binding / amulet.
func toggle_equip(id: String) -> void:
	var slot := ""
	match ItemDB.info(id)["type"]:
		"binding": slot = "binding"
		"amulet": slot = "amulet"
		_: return
	equipment[slot] = "" if equipment[slot] == id else id
	inventory_changed.emit()
	save_game()

## Sum of a stat across everything equipped (armor, speed, dash_cd, invuln).
func equipped_stat(key: String) -> float:
	var total := 0.0
	for slot in equipment:
		var id: String = equipment[slot]
		if id != "":
			total += float(ItemDB.info(id).get("fx", {}).get(key, 0.0))
	return total

# --- Saving --------------------------------------------------------------------------------
func save_game() -> void:
	if not autosave_enabled:
		return
	var data := {
		"v": 1, "mnemosynth": mnemosynth, "ink": ink, "flags": flags.keys(),
		"inventory": inventory, "equipment": equipment, "quick_slot": quick_slot,
		"town_restored": town_restored,
		"spawn": [spawn_cell.x, spawn_cell.y],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	mnemosynth = int(data.get("mnemosynth", 0))
	ink = float(data.get("ink", 100.0))
	flags.clear()
	for k in data.get("flags", []):
		flags[str(k)] = true
	inventory = {}
	for k in data.get("inventory", {}):
		inventory[str(k)] = int(data["inventory"][k])
	var eq: Dictionary = data.get("equipment", {})
	equipment = {"binding": str(eq.get("binding", "")), "amulet": str(eq.get("amulet", ""))}
	quick_slot = str(data.get("quick_slot", ""))
	town_restored = bool(data.get("town_restored", false))
	if town_restored:
		wave_radius = FULL
	var sp: Array = data.get("spawn", [-1, -1])
	spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _ready() -> void:
	if OS.get_environment("STORYTENDER_NOSAVE") != "":
		autosave_enabled = false
	elif load_game():
		print("Loaded save.")

## Wipe everything (development: F12). Restarts from a fresh game.
func reset_all() -> void:
	delete_save()
	mnemosynth = 0
	ink = 100.0
	flags.clear()
	inventory.clear()
	equipment = {"binding": "", "amulet": ""}
	quick_slot = ""
	town_restored = false
	wave_radius = 0.0
	spawn_cell = Vector2i(-1, -1)
	in_dialogue = false
