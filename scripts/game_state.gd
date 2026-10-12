extends Node
## Global story state (autoload as GameState).

signal mnemosynth_changed(value: int)
signal restoration_finished
signal inventory_changed

const RESTORE_DURATION := 5.5
const WAVE_SOFT_EDGE := 190.0     # px of ink "bleeding in" at the wave front
const SOURCE_RADIUS := 470.0      # how far one restored person recolors the town

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

# Each restored NPC becomes a "source": color blooms outward from them.
var sources: Array[Dictionary] = []   # {id: String, origin: Vector2, radius: float}
var town_published := false           # the Editor has fallen: the whole chapter is written

func has_flag(f: String) -> bool:
	return flags.has(f)

func set_flag(f: String) -> void:
	flags[f] = true
	save_game()

func add_mnemosynth(n: int) -> void:
	mnemosynth += n
	mnemosynth_changed.emit(mnemosynth)

func is_restored(id: String) -> bool:
	return has_flag("restored_" + id)

func _source_value(src: Dictionary, pos: Vector2) -> float:
	var d: Vector2 = pos - Vector2(src["origin"])
	d.y *= 2.0
	return clampf((float(src["radius"]) - d.length()) / WAVE_SOFT_EDGE, 0.0, 1.0)

## 0..1 how "written" the world is at a position (max over every restored person).
func restored_at(pos: Vector2) -> float:
	if town_published:
		return 1.0
	var best := 0.0
	for src in sources:
		best = maxf(best, _source_value(src, pos))
	return best

## How restored a *specific* NPC is: only their own wave counts.
func restored_for(id: String, pos: Vector2) -> float:
	if town_published and is_restored(id):
		return 1.0
	for src in sources:
		if src["id"] == id:
			return _source_value(src, pos)
	return 0.0

func start_restoration(id: String, origin: Vector2) -> void:
	var src := {"id": id, "origin": origin, "radius": 1.0}
	sources.append(src)
	set_flag("restored_" + id)
	var target := SOURCE_RADIUS + WAVE_SOFT_EDGE
	var tw := create_tween()
	tw.tween_method(func(v: float): src["radius"] = v, 1.0, target, RESTORE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	save_game()
	restoration_finished.emit()

func publish_town() -> void:
	town_published = true
	set_flag("town_published")

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
		"sources": sources.map(func(src): return {"id": src["id"], "x": src["origin"].x, "y": src["origin"].y, "r": src["radius"]}),
		"town_published": town_published,
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
	sources.clear()
	for sd in data.get("sources", []):
		sources.append({"id": str(sd["id"]), "origin": Vector2(float(sd["x"]), float(sd["y"])), "radius": float(sd["r"])})
	town_published = bool(data.get("town_published", false))
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
	sources.clear()
	town_published = false
	spawn_cell = Vector2i(-1, -1)
	in_dialogue = false
