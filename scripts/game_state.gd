extends Node
## Global story state (autoload as GameState).

signal mnemosynth_changed(value: int)
signal renown_changed(value: int, rank: int)
signal rank_up(rank: int)
signal restoration_finished
signal inventory_changed

const RESTORE_DURATION := 5.5
const WAVE_SOFT_EDGE := 190.0     # px of ink "bleeding in" at the wave front
const SOURCE_RADIUS := 470.0      # how far one restored person recolors the town

var mnemosynth := 0
var ink := 100.0                  # carried between scenes
var spawn_cell := Vector2i(-1, -1)  # where the overworld should place the player (-1 = map start)
var last_post := ""                 # the lantern post you last rested at or arrived by: where dying sends you
var before_exit: Callable           # the overworld sets this so closing the game records the nearest post

func prepare_exit() -> void:
	if before_exit.is_valid():
		before_exit.call()
var flags: Dictionary = {}
var in_dialogue := false

# --- Levels and attributes (spent with Mnemosynth at the Index) --------------------------------
## key -> [name, what a point does (per point)]. Level = 1 + points spent.
const ATTRS := {
	"ink": ["Inkwell", "+2 maximum ink"],
	"grit": ["Thick Paper", "-0.5% damage taken"],
	"pen": ["Penmanship", "+1% Quill damage, +0.25% reach"],
	"wit": ["Wit", "+0.025 ink regen/s, -0.5% Lantern burn, and an extra try in Vault Trials every 20 points"],
	"foot": ["Footwork", "+0.3% speed, -0.5% dash cooldown"],
	"luck": ["Fortune", "+0.5% drop chances, +0.25% Mnemosynth found"],
}
const ATTR_ORDER := ["ink", "grit", "pen", "wit", "foot", "luck"]
const ATTR_CAP := 100             # each attribute goes up to 100
const LEVEL_CAP := 601            # 1 + six attributes at 100
const FREE_POINTS := 15           # handed out when the Index first shows you the system
var attrs: Dictionary = {"ink": 0, "grit": 0, "pen": 0, "wit": 0, "foot": 0, "luck": 0}
var free_points := 0               # spend these without paying

func attr(key: String) -> int:
	return int(attrs.get(key, 0))

func level() -> int:
	var n := 1
	for k in ATTR_ORDER:
		n += attr(k)
	return n

## Mnemosynth needed for the next point; it grows with every level, like a soul cost.
func level_cost() -> int:
	var p := level() - 1          # points spent so far
	return int(20.0 + 4.0 * p + 0.08 * p * p)

func spend_point(key: String) -> bool:
	if not ATTRS.has(key) or attr(key) >= ATTR_CAP or level() >= LEVEL_CAP:
		return false
	if free_points > 0:
		free_points -= 1
	elif mnemosynth >= level_cost():
		mnemosynth -= level_cost()
	else:
		return false
	attrs[key] = attr(key) + 1
	mnemosynth_changed.emit(mnemosynth)
	inventory_changed.emit()
	save_game()
	return true

## What the attributes add to the stat `key` (same names equipment uses).
func attr_stat(key: String) -> float:
	match key:
		"armor": return 0.005 * attr("grit")
		"dmg": return 0.01 * attr("pen")
		"reach": return 0.0025 * attr("pen")
		"regen": return 0.025 * attr("wit")
		"lantern_eff": return -0.005 * attr("wit")
		"speed": return 0.003 * attr("foot")
		"dash_cd": return -0.005 * attr("foot")
		"luck": return 0.005 * attr("luck")
		"mnemo": return 0.0025 * attr("luck")
	return 0.0

# --- Inventory -------------------------------------------------------------------------
var inventory: Dictionary = {}                     # item id -> count
var equipment: Dictionary = {"binding": "", "amulet": ""}
var quick_slots: Array = ["", ""]                  # two consumables share the use button; one is active
var quick_active := 0
## The consumable the use button fires right now (the active slot). Setting it fills the active slot.
var quick_slot: String:
	get:
		return str(quick_slots[quick_active])
	set(v):
		quick_slots[quick_active] = v
		for i in 2:
			if i != quick_active and v != "" and quick_slots[i] == v:
				quick_slots[i] = ""

func quick_other() -> String:
	return str(quick_slots[1 - quick_active])

func switch_quick() -> void:
	quick_active = 1 - quick_active
	inventory_changed.emit()
	save_game()
var format_style := "underline"                    # selected Quill style: underline | bold | italic
var difficulty := "normal"                        # "story" (gentle) or "normal"

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

# --- Renown: how well the page knows your name -------------------------------------------------
# Every kind of deed earns it (beating Errors, side quests, mini-dungeons, exploring, chests,
# riddles, restoring people). Story gates ask for a minimum, so you can pick how to earn it.
const RANK_STEPS := [0, 40, 100, 180, 280, 400, 560, 760, 1000, 1300, 1650]
const GATE_RENOWN := {"margin_gate": 220}
var renown := 0

func rank() -> int:
	var r := 1
	for i in RANK_STEPS.size():
		if renown >= RANK_STEPS[i]:
			r = i + 1
	return r

func rank_floor() -> int:
	return RANK_STEPS[mini(rank(), RANK_STEPS.size()) - 1]

func rank_next() -> int:
	var r := rank()
	return RANK_STEPS[r] if r < RANK_STEPS.size() else RANK_STEPS[RANK_STEPS.size() - 1]

## Each rank widens the ink bottle a little.
func max_ink_bonus() -> float:
	return 10.0 * (rank() - 1) + 2.0 * attr("ink")

func add_renown(n: int) -> void:
	if n > 0:
		n = roundi(n * (1.0 + equipped_stat("renown")))
	var before := rank()
	renown += n
	renown_changed.emit(renown, rank())
	if rank() > before:
		rank_up.emit(rank())

func add_mnemosynth(n: int) -> void:
	if n > 0:
		n = roundi(n * (1.0 + equipped_stat("mnemo")))
	mnemosynth += n
	mnemosynth_changed.emit(mnemosynth)

func is_restored(id: String) -> bool:
	return has_flag("restored_" + id)

func _source_value(src: Dictionary, pos: Vector2) -> float:
	var d: Vector2 = pos - Vector2(src["origin"])
	d.y *= 2.0
	return clampf((float(src["radius"]) - d.length()) / WAVE_SOFT_EDGE, 0.0, 1.0)

## 0..1 how "written" the world is at a position (max over every restored person).
# --- Lantern posts (waypoints) and discovery ---------------------------------------------------
func waypoint_lit(id: String) -> bool:
	return has_flag("wp_" + id)

func region_seen(r: String) -> bool:
	return has_flag("seen_" + r)

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

var _restore_until_ms := 0

## True while a restoration wave is spreading (the ground has to repaint every frame).
func restore_active() -> bool:
	return Time.get_ticks_msec() < _restore_until_ms

func start_restoration(id: String, origin: Vector2, radius: float = SOURCE_RADIUS) -> void:
	_restore_until_ms = Time.get_ticks_msec() + int(RESTORE_DURATION * 1000.0) + 800
	var src := {"id": id, "origin": origin, "radius": 1.0}
	sources.append(src)
	set_flag("restored_" + id)
	var target := radius + WAVE_SOFT_EDGE
	var tw := create_tween()
	tw.tween_method(func(v: float): src["radius"] = v, 1.0, target, RESTORE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	save_game()
	restoration_finished.emit()

func publish_town() -> void:
	_restore_until_ms = Time.get_ticks_msec() + 800
	town_published = true
	set_flag("town_published")

# --- Difficulty ------------------------------------------------------------------------------
func is_story() -> bool:
	return difficulty == "story"

func enemy_dmg_mult() -> float:
	return 0.6 if is_story() else 1.0

func crumple_ink() -> float:
	return 100.0 if is_story() else 50.0

func bolt_speed_mult() -> float:
	return 0.85 if is_story() else 1.0

func spoiler_window_bonus() -> float:
	return 1.5 if is_story() else 0.0

func fall_damage() -> float:
	return 8.0 if is_story() else 15.0

## Begin a fresh save with the chosen difficulty (fixed for that save).
func new_game(diff: String) -> void:
	reset_all()
	difficulty = diff
	save_game()
	Telemetry.log_event("new_game", {"difficulty": diff})

# --- Items ---------------------------------------------------------------------------------
func count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n
	if ItemDB.info(id)["type"] == "consumable" and not quick_slots.has(id):
		if quick_slots[quick_active] == "":
			quick_slots[quick_active] = id
		elif quick_slots[1 - quick_active] == "":
			quick_slots[1 - quick_active] = id
	inventory_changed.emit()
	save_game()

func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
		for i in 2:
			if quick_slots[i] == id:
				quick_slots[i] = ""
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
	var total := attr_stat(key)
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
		"v": 2, "renown": renown, "mnemosynth": mnemosynth, "ink": ink, "flags": flags.keys(),
		"inventory": inventory, "equipment": equipment, "quick_slots": quick_slots, "quick_active": quick_active,
		"sources": sources.map(func(src): return {"id": src["id"], "x": src["origin"].x, "y": src["origin"].y, "r": src["radius"]}),
		"town_published": town_published, "difficulty": difficulty,
		"spawn": [spawn_cell.x, spawn_cell.y], "last_post": last_post, "attrs": attrs, "free_points": free_points,
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
	renown = int(data.get("renown", 0))
	ink = float(data.get("ink", 100.0))
	flags.clear()
	for k in data.get("flags", []):
		flags[str(k)] = true
	inventory = {}
	for k in data.get("inventory", {}):
		inventory[str(k)] = int(data["inventory"][k])
	var eq: Dictionary = data.get("equipment", {})
	equipment = {"binding": str(eq.get("binding", "")), "amulet": str(eq.get("amulet", ""))}
	quick_slots = ["", ""]
	if data.has("quick_slots"):
		var qs: Array = data["quick_slots"]
		for i in mini(qs.size(), 2):
			quick_slots[i] = str(qs[i])
	else:
		quick_slots[0] = str(data.get("quick_slot", ""))      # older saves had one slot
	quick_active = clampi(int(data.get("quick_active", 0)), 0, 1)
	sources.clear()
	for sd in data.get("sources", []):
		sources.append({"id": str(sd["id"]), "origin": Vector2(float(sd["x"]), float(sd["y"])), "radius": float(sd["r"])})
	town_published = bool(data.get("town_published", false))
	difficulty = str(data.get("difficulty", "normal"))
	free_points = int(data.get("free_points", 0))
	attrs = {"ink": 0, "grit": 0, "pen": 0, "wit": 0, "foot": 0, "luck": 0}
	for k in data.get("attrs", {}):
		attrs[str(k)] = int(data["attrs"][k])
	var sp: Array = data.get("spawn", [-1, -1])
	spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
	last_post = str(data.get("last_post", ""))
	if int(data.get("v", 1)) < 2:
		# The overworld grew: the old 40x26 map now sits at an offset inside the larger one.
		if spawn_cell.x >= 0:
			spawn_cell += PrologueMap.OFFSET
		var shift := Iso.to_screen(Vector2(PrologueMap.OFFSET))
		for src in sources:
			src["origin"] = Vector2(src["origin"]) + shift
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
	renown = 0
	ink = 100.0
	flags.clear()
	inventory.clear()
	equipment = {"binding": "", "amulet": ""}
	attrs = {"ink": 0, "grit": 0, "pen": 0, "wit": 0, "foot": 0, "luck": 0}
	free_points = 0
	quick_slots = ["", ""]
	quick_active = 0
	sources.clear()
	town_published = false
	spawn_cell = Vector2i(-1, -1)
	last_post = ""
	in_dialogue = false
