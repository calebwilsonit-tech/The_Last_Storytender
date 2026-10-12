extends LevelBase
## The overworld: the Prologue Plains and Thistledown (the first Ghost Town).
## Built from data/prologue_map.gd. Restoring Thistledown means entering
## Garrick's memory (the forge's frozen flame), then returning the First Sword.

const MEMORY_SCENE := "res://scenes/memory_forge.tscn"
const PIP_MEMORY_SCENE := "res://scenes/memory_pip.tscn"
const MAUD_MEMORY_SCENE := "res://scenes/memory_maud.tscn"
const SCISSOR_SCENE := "res://scenes/editor_scissor.tscn"
const RIFT_CELL := Vector2i(24, 13) + PrologueMap.OFFSET
const RETURN_CELL := Vector2i(30, 15) + PrologueMap.OFFSET       # where you step out of the memory

var _enemy_spawns: Array[Dictionary] = []   # {kind, cell}; enemies appear after Garrick's lesson
var _dummy: Dummy
var _redactor: Redactor
var _tutorial := 0            # 0 none, 1 strike, 2 dash, 3 lantern, 4 done
var _strikes := 0
var _lantern_time := 0.0
var _redactor_hinted := false
var _enemies_out := false
var _respawn_t := 0.0
var _spawn_kinds: Array[Dictionary] = []
var _forge: Prop
var _garrick: Npc
var _pip_npc: Npc
var _book: Prop
var _maud_npc: Npc
var _oven: Prop
var _entered_town := false
var _gate_prop: Prop
var _posts: Dictionary = {}               # waypoint id -> Prop
var _spawn_state: Array[Dictionary] = []

func _got_key(tag: String, cell: Vector2i) -> String:
	return "got_%s_%d_%d" % [tag, cell.x, cell.y]

func _lore_id_at(cell: Vector2i) -> String:
	for id in PrologueMap.LORE.keys():
		var c: Array = PrologueMap.LORE[id]
		if Vector2i(int(c[0]), int(c[1])) == cell:
			return id
	return ""

func _crystal_collected(c: Node2D) -> void:
	if c.has_meta("got_key"):
		GameState.set_flag(c.get_meta("got_key"))

# --- Chests and riddle gates ---------------------------------------------------------------
var _riddle_stones: Dictionary = {}       # riddle id -> SentenceStone
var _riddle_gates: Dictionary = {}        # riddle id -> StoryGate

func _riddle_for(kind: String, cell: Vector2i) -> String:
	for id in PrologueMap.RIDDLES.keys():
		var r: Dictionary = PrologueMap.RIDDLES[id]
		var c: Array = r[kind]
		if Vector2i(int(c[0]), int(c[1])) == cell:
			return id
	return ""

func _spawn_chest(cell: Vector2i) -> void:
	var key := _got_key("chest", cell)
	var chest := _add_prop(Prop.Kind.CHEST, cell, false, 1 if GameState.has_flag(key) else 0)
	chest.set_meta("got_key", key)
	_floor.blockers[cell] = true
	_register(chest, func(): return "" if GameState.has_flag(key) else "Open the chest", func(): await _open_chest(chest, cell), 90.0)

func _open_chest(chest: Prop, cell: Vector2i) -> void:
	var key: String = chest.get_meta("got_key")
	if GameState.has_flag(key):
		return
	GameState.set_flag(key)
	GameState.add_renown(5)
	chest.variant = 1
	var reward: String = PrologueMap.CHESTS.get("%d,%d" % [cell.x, cell.y], "mnemo:20")
	if reward.begins_with("tier:"):
		reward = TrialPrizes.roll(int(reward.substr(5)), cell)
	_grant_reward(reward)
	_hud.narrate(Story.CHEST_LINES[randi() % Story.CHEST_LINES.size()], false, 4.0)
	Telemetry.log_event("chest", {"at": "%d,%d" % [cell.x, cell.y]})

func _spawn_riddle_stone(cell: Vector2i) -> void:
	var id := _riddle_for("stone", cell)
	if id == "":
		return
	var rd: Dictionary = PrologueMap.RIDDLES[id]
	var st := SentenceStone.new()
	st.prefix = rd["prefix"]
	st.options = PackedStringArray(rd["options"])
	st.suffix = rd["suffix"]
	st.position = Iso.to_screen(Vector2(cell))
	st.elev = _lift_at(cell)
	_actors.add_child(st)
	var tier := int(rd.get("tier", 1))
	_register(st, func(): return ("Attempt the trial  " + "★".repeat(tier)) if not st.locked else "", func(): _attempt_trial(id, st, cell, tier), 80.0)
	_riddle_stones[id] = st
	if GameState.has_flag("riddle_" + id):
		st.index = st.options.size() - 1
		st.locked = true

func _spawn_riddle_gate(cell: Vector2i) -> void:
	var id := _riddle_for("gate", cell)
	if id == "":
		return
	var rd: Dictionary = PrologueMap.RIDDLES[id]
	var gate := StoryGate.new()
	gate.axis = Vector2(float(rd["axis"][0]), float(rd["axis"][1]))
	gate.length = 3.0
	gate.label = "SENTENCE"
	gate.position = Iso.to_screen(Vector2(cell))
	gate.elev = _lift_at(cell)
	_actors.add_child(gate)
	_riddle_gates[id] = gate
	if GameState.has_flag("riddle_" + id):
		gate.open()

func _attempt_trial(id: String, stone: SentenceStone, cell: Vector2i, tier: int) -> void:
	if stone.locked:
		return
	if await _run_trial(id, cell, tier):
		_on_riddle(id, stone, stone.options.size() - 1)

func _on_riddle(id: String, stone: SentenceStone, idx: int) -> void:
	if idx != stone.options.size() - 1:
		return
	stone.index = stone.options.size() - 1
	stone.locked = true
	GameState.add_renown(4 + 4 * int((PrologueMap.RIDDLES[id] as Dictionary).get("tier", 1)))
	GameState.set_flag("riddle_" + id)
	if _riddle_gates.has(id):
		_riddle_gates[id].open()
	_hud.narrate(Story.RIDDLE_OPEN, false, 4.0)
	Telemetry.log_event("puzzle", {"p": "riddle_" + id})

# --- Lantern posts and the Margin Gate -------------------------------------------------
func _waypoint_at(cell: Vector2i) -> Dictionary:
	for wp: Dictionary in PrologueMap.WAYPOINTS:
		if Vector2i(int(wp["cell"][0]), int(wp["cell"][1])) == cell:
			return wp
	return {}

func _spawn_post(cell: Vector2i) -> void:
	var wp := _waypoint_at(cell)
	if wp.is_empty():
		return
	var id: String = wp["id"]
	var post := _add_prop(Prop.Kind.POST, cell, false, 1 if GameState.waypoint_lit(id) else 0)
	_posts[id] = post
	_register(post, func(): return "Rest at the post" if GameState.waypoint_lit(id) else "Light the post", func(): await _touch_post(id), 100.0)

func _touch_post(id: String) -> void:
	var wp: Dictionary = {}
	for w: Dictionary in PrologueMap.WAYPOINTS:
		if w["id"] == id:
			wp = w
	if not GameState.waypoint_lit(id):
		GameState.set_flag("wp_" + id)
		_posts[id].variant = 1
		GameState.add_mnemosynth(10)
		GameState.add_renown(3)
		_hud.toast("Waypoint lit: %s" % wp["name"])
		Telemetry.log_event("waypoint", {"id": id})
	else:
		_hud.toast("You rest by the lantern. The page resets: the Errors return.")
	_respawn_world()
	_player.restore_ink(100.0)
	_player.refuel(100.0)
	GameState.save_game()
	if not GameState.has_flag("index_seen"):
		GameState.set_flag("index_seen")
		_hud.narrate(Story.INDEX_FIRST, false, 5.0)
		await get_tree().create_timer(1.0).timeout
	_index.open_hub()

func _touch_gate() -> void:
	var need: int = GameState.GATE_RENOWN["margin_gate"]
	if not GameState.town_published:
		await _say(Story.gate_locked())
	elif GameState.renown < need:
		await _say(Story.gate_renown(GameState.renown, need))
	else:
		_gate_prop.variant = 1
		await _say(Story.gate_open())

func _map_available() -> bool:
	return true

func _on_travel_requested(id: String) -> void:
	travel_to(id)

## Fast travel: only to lantern posts you have lit.
func travel_to(id: String) -> void:
	for wp: Dictionary in PrologueMap.WAYPOINTS:
		if wp["id"] == id and GameState.waypoint_lit(id):
			GameState.spawn_cell = Vector2i(int(wp["cell"][0]), int(wp["cell"][1])) + Vector2i(0, 1)
			Transition.go("res://scenes/main.tscn", Palette.PAPER_LIGHT)
			return

# --- LevelBase hooks ---------------------------------------------------------------
func _map_rows() -> Array[String]:
	return PrologueMap.ROWS

func _map_heights() -> Array[String]:
	return PrologueMap.HEIGHTS

func _spawn_override() -> Vector2i:
	return GameState.spawn_cell

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	match ch:
		"T":
			_floor.cells[cell] = "."
			_add_prop(Prop.Kind.TREE, cell, false, cell.x + cell.y)
		"C":
			_floor.cells[cell] = "."
			if not GameState.has_flag(_got_key("C", cell)):
				var cr := _add_prop(Prop.Kind.CRYSTAL, cell)
				cr.set_meta("got_key", _got_key("C", cell))
				_crystals.append(cr)
		"L":
			_floor.cells[cell] = "."
			var lore_id := _lore_id_at(cell)
			var stone := _add_prop(Prop.Kind.SIGN, cell)
			_register(stone, func(): return "Read", func(): await _say(Story.lore(lore_id)))
		"Y":
			_floor.cells[cell] = "."
			_spawn_post(cell)
		"q":
			_floor.cells[cell] = "."
			_spawn_chest(cell)
		"S":
			_floor.cells[cell] = "."
			_spawn_riddle_stone(cell)
		"U":
			_floor.cells[cell] = "."
			_spawn_riddle_gate(cell)
		"G":
			_floor.cells[cell] = ","
			_floor.blockers[cell] = true
			_gate_prop = _add_prop(Prop.Kind.GATE, cell, false, 1 if (GameState.town_published and GameState.renown >= GameState.GATE_RENOWN["margin_gate"]) else 0)
			_register(_gate_prop, func(): return "Examine the gate", _touch_gate, 120.0)
		"W":
			_floor.cells[cell] = "."
			var p := _add_prop(Prop.Kind.SIGN, cell)
			_register(p, func(): return "Read", func(): await _say(Story.tutorial_sign()))
		"X":
			_floor.cells[cell] = ","
			var p2 := _add_prop(Prop.Kind.SIGN, cell, true)
			_register(p2, func(): return "Read", func(): await _say(Story.town_sign()))
		"H", "F":
			for dx in 2:
				for dy in 2:
					var c2 := cell + Vector2i(dx, dy)
					consumed[c2] = true
					_floor.cells[c2] = ","
					_floor.blockers[c2] = true
			var kind := Prop.Kind.HOUSE if ch == "H" else Prop.Kind.FORGE
			var hp := Prop.new()
			hp.kind = kind
			hp.ghost = true
			hp.variant = cell.x + cell.y
			hp.lift = _lift_at(cell)
			hp.position = Iso.to_screen(Vector2(cell) + Vector2(0.5, 0.5))
			_actors.add_child(hp)
			if kind == Prop.Kind.FORGE:
				_forge = hp
				_register(hp, _forge_prompt, _touch_flame, 120.0)
		"N", "K", "B":
			_floor.cells[cell] = ","
			_add_npc(ch, cell)
		"k", "o", "e", "v":
			_floor.cells[cell] = "."
			var pick_id: String = {"k": "softcover_binding", "o": "oxford_comma", "e": "eraser_crumbs", "v": "void_ink"}[ch]
			if not GameState.has_flag(_got_key("k", cell)):
				var pk := _add_pickup(cell, pick_id)
				pk.set_meta("got_key", _got_key("k", cell))
		"V":
			_floor.cells[cell] = ","
			_floor.blockers[cell] = true
			_oven = _add_prop(Prop.Kind.OVEN, cell)
			_register(_oven, _oven_prompt, _touch_oven, 110.0)
		"Q":
			_floor.cells[cell] = ","
			_book = _add_prop(Prop.Kind.BOOK, cell)
			_register(_book, _book_prompt, _touch_book, 90.0)
		"g", "x", "l", "d", "n", "z":
			_floor.cells[cell] = "."
			var ek: Enemy.Kind = {"g": Enemy.Kind.BARE, "x": Enemy.Kind.MITE, "l": Enemy.Kind.SLUG, "d": Enemy.Kind.DANGLER, "n": Enemy.Kind.CENSOR, "z": Enemy.Kind.ELLIPSIS}[ch]
			_enemy_spawns.append({"kind": ek, "cell": cell})
		"R":
			_floor.cells[cell] = "."
			_redactor = _add_redactor(cell, Vector2(1, 0), 3.0, "the way up")
			_redactor.revealed.connect(func(): _hud.narrate(Story.REDACTOR_OPEN, false, 4.0))
		"D":
			_floor.cells[cell] = ","
			_dummy = Dummy.new()
			_dummy.position = Iso.to_screen(Vector2(cell))
			_dummy.elev = _lift_at(cell)
			_actors.add_child(_dummy)
			_dummy.struck.connect(_on_dummy_struck)
		_:
			return false
	return true

func _add_npc(ch: String, cell: Vector2i) -> void:
	var n := Npc.new()
	n.lift = _lift_at(cell)
	n.position = Iso.to_screen(Vector2(cell))
	_actors.add_child(n)
	match ch:
		"N":
			n.kind = Npc.Kind.BLACKSMITH
			n.npc_id = "garrick"
			_garrick = n
			_register(n, func(): return "Speak", _talk_garrick)
		"K":
			n.kind = Npc.Kind.CHILD
			n.npc_id = "pip"
			_pip_npc = n
			_register(n, func(): return "Speak", _talk_pip)
		"B":
			n.kind = Npc.Kind.BAKER
			n.npc_id = "maud"
			_maud_npc = n
			_register(n, func(): return "Speak", _talk_maud)

func _notification(what: int) -> void:
	# Remember where you were if the game is closed mid-walk.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _player and is_instance_valid(_player):
		GameState.spawn_cell = _floor.cell_at(_player.position)
		GameState.save_game()

func _level_ready() -> void:
	_floor.static_world = true      # the overworld ground never changes: no safety repaints
	_setup_chunks()
	Settings.quality_changed.connect(_setup_chunks)
	_player.dashed.connect(_on_dashed)
	_check_rift()
	if GameState.has_flag("scissor_done") and not GameState.town_published:
		_publish_scene()
	if GameState.has_flag("maud_memory_done") and is_instance_valid(_oven):
		pass   # the oven stays; Maud is baking in it now
	if GameState.has_flag("pip_memory_done") and is_instance_valid(_book):
		_book.queue_free()   # the storybook has done its job
	_spawn_enemies()      # the Errors roam from the start; you begin with a pencil stub
	if GameState.has_flag("memory_done") and not GameState.is_restored("garrick"):
		_hud.narrate(Story.RETURNED, false, 5.0)
	elif not GameState.has_flag("intro_done"):
		GameState.set_flag("intro_done")
		_start_intro()

## After the storybook: the doodle is inked in, stretches up off the page and stands.
func _wake_up() -> void:
	GameState.in_dialogue = true
	_player.scale = Vector2(1.7, 0.04)
	_player.modulate.a = 0.0
	_hud.narrate(Story.INTRO_WAKE, false, 3.0)
	await get_tree().create_timer(1.6).timeout
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_player, "modulate:a", 1.0, 0.9)
	tw.tween_property(_player, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	camera_shake(0.25, 3.0)
	await get_tree().create_timer(0.5).timeout
	GameState.in_dialogue = false

func _start_intro() -> void:
	if GameState.has_flag("book_seen"):
		await _wake_up()
	await get_tree().create_timer(1.2).timeout
	await _hud.tutorial("move")
	await _hud.tutorial("quill")
	for t in Story.INTRO:
		_hud.narrate(t, false, 3.2)
		await get_tree().create_timer(5.6).timeout

func _level_process(delta: float) -> void:
	_tick_respawns(delta)
	_update_region()
	_hint_redactor()
	if _tutorial == 3 and _player.lantern_on:
		_lantern_time += delta
		if _lantern_time >= 1.2:
			_finish_lesson()

# --- The Editor's tear ---------------------------------------------------------------------
var _rift: Prop

func _check_rift() -> void:
	if is_instance_valid(_rift) or GameState.has_flag("scissor_done"):
		return
	for id in ["garrick", "pip", "maud"]:
		if not GameState.is_restored(id):
			return
	_rift = _add_prop(Prop.Kind.RIFT, RIFT_CELL)
	_register(_rift, func(): return "Step into the tear", _enter_rift, 110.0)
	_hud.narrate(Story.RIFT_NARRATION, false, 6.0)

func _enter_rift() -> void:
	await cinematic([{"at": _rift.position, "zoom": ZOOM * 1.3, "pan": 1.2, "hold": 0.4, "lines": Story.scissor_rift_enter()}])
	Transition.go(SCISSOR_SCENE, Color("f6f3ea"))

func _publish_scene() -> void:
	await get_tree().create_timer(1.5).timeout
	var center := Iso.to_screen(Vector2(RIFT_CELL))
	_hud.narrate(Story.PUBLISHED, false, 5.0)
	GameState.start_restoration("town", center, 2600.0)
	await get_tree().create_timer(GameState.RESTORE_DURATION * 0.8).timeout
	GameState.publish_town()
	GameState.save_game()

# --- Frame helpers ---------------------------------------------------------------------
func _update_region() -> void:
	var cell := _floor.cell_at(_player.position)
	var r := PrologueMap.region_at(cell)
	if r == "t":
		_hud.set_region("Thistledown — Prologue complete" if GameState.town_published else "Thistledown (Draft)")
		if not _entered_town:
			_entered_town = true
			_hud.narrate(Story.SILENCE_WHISPER, true, 5.0)
	else:
		_hud.set_region(PrologueMap.REGIONS.get(r, "The Prologue Plains"))
	if r != " " and not GameState.region_seen(r):
		GameState.set_flag("seen_" + r)
		if r not in ["m", "s", "o"]:
			GameState.add_mnemosynth(10)
			GameState.add_renown(6)
			_hud.toast("Discovered: %s" % PrologueMap.REGIONS.get(r, ""))
		Telemetry.log_event("region", {"r": r})

# --- Cues ------------------------------------------------------------------------------
func _handle_cue(cue: String) -> void:
	match cue:
		"name_reveal":
			_garrick.named = true
			_garrick.display_name = "Garrick"
		"tear":
			_garrick.tearful = true
		"restore":
			await _restoration_scene("garrick", _garrick)
		"restore_pip":
			await _restoration_scene("pip", _pip_npc)
		"restore_maud":
			await _restoration_scene("maud", _maud_npc)
			_check_rift()

# --- Story beats -----------------------------------------------------------------------
func _book_prompt() -> String:
	if GameState.has_flag("pip_memory_done"):
		return ""
	return "Read Pip's storybook" if GameState.has_flag("has_quill") else "Look at the storybook"

func _touch_book() -> void:
	if not GameState.has_flag("has_quill"):
		await _say([Story.line("", Story.PIP_BOOK_HINT, "action")])
		return
	await _say(Story.pip_book_enter())
	Transition.go(PIP_MEMORY_SCENE, Palette.CYAN.lightened(0.7))
	await get_tree().create_timer(30.0).timeout

func _talk_pip() -> void:
	if GameState.is_restored("pip"):
		await _say(Story.pip_restored())
	elif GameState.has_flag("pip_memory_done"):
		await _say(Story.pip_restoration())
		GameState.add_mnemosynth(30)
		_hud.toast("Restored: Pip")
		GameState.add_renown(35)
	else:
		await _say(Story.pip_ghost())

func _oven_prompt() -> String:
	if GameState.has_flag("maud_memory_done"):
		return ""
	return "Reach into the cold oven" if GameState.has_flag("pip_memory_done") else "Look at the oven"

func _touch_oven() -> void:
	if not GameState.has_flag("pip_memory_done"):
		await _say([Story.line("", Story.MAUD_OVEN_HINT, "action")])
		return
	await _say(Story.maud_oven_enter())
	Transition.go(MAUD_MEMORY_SCENE, Palette.GOLD.lightened(0.7))
	await get_tree().create_timer(30.0).timeout

func _talk_maud() -> void:
	if GameState.is_restored("maud"):
		await _say(Story.maud_restored())
	elif GameState.has_flag("maud_memory_done"):
		await _say(Story.maud_restoration())
		GameState.add_mnemosynth(30)
		_give_item("warm_loaf", 3)
		_hud.toast("Restored: Maud")
		GameState.add_renown(35)
	else:
		await _say(Story.maud_ghost())

func _forge_prompt() -> String:
	if GameState.has_flag("met_garrick") and not GameState.has_flag("memory_done"):
		return "Touch the frozen flame"
	return ""

func _touch_flame() -> void:
	await _say(Story.forge_flame())
	GameState.spawn_cell = RETURN_CELL
	Transition.go(MEMORY_SCENE, Palette.CYAN.lightened(0.7))
	await get_tree().create_timer(30.0).timeout   # the scene is replaced during the fade

func _talk_garrick() -> void:
	if GameState.is_restored("garrick"):
		if not GameState.has_flag("has_quill"):
			await _say(Story.garrick_lesson_start())
			GameState.set_flag("has_quill")
			_hud.toast("Received: Garrick's Quill")
			_hud.set_controls(true)
			_set_tutorial(1)
			await _hud.tutorial("quill")
		elif _tutorial >= 1 and _tutorial <= 3:
			await _say(Story.garrick_lesson_hint(_tutorial))
		else:
			await _say(Story.garrick_restored())
	elif GameState.has_flag("memory_done"):
		await _say(Story.garrick_restoration())
		GameState.add_mnemosynth(25)
		_hud.toast("Restored: Garrick")
		GameState.add_renown(35)
		_garrick.tearful = false
	elif GameState.has_flag("met_garrick"):
		await _say(Story.garrick_ghost_repeat())
	else:
		GameState.set_flag("met_garrick")
		await _say(Story.garrick_ghost())

# --- Combat lesson -------------------------------------------------------------------------
func _set_tutorial(step: int) -> void:
	_tutorial = step
	match step:
		1:
			_hud.set_objective("Strike the training dummy: %d / 3   ({attack})" % _strikes)
		2:
			_hud.set_objective("Dash with {dash}")
		3:
			_lantern_time = 0.0
			_hud.set_objective("Hold {lantern}: shine your Lantern")
			_hud.tutorial("lantern")
		_:
			_hud.set_objective("")

func _on_dummy_struck() -> void:
	if _tutorial != 1:
		return
	_strikes += 1
	_hud.set_objective("Strike the training dummy: %d / 3   ({attack})" % mini(_strikes, 3))
	if _strikes >= 3:
		_set_tutorial(2)

func _on_dashed() -> void:
	if _tutorial == 2:
		_set_tutorial(3)

func _finish_lesson() -> void:
	_set_tutorial(4)
	GameState.set_flag("lesson_done")
	GameState.add_mnemosynth(20)
	_hud.toast("Lesson complete")
	_busy = true
	await _say(Story.garrick_lesson_end())
	_busy = false
	_give_item("hardcover_binding")
	_give_item("eraser_crumbs", 2)
	_hud.narrate(Story.BINDER_HINT, false, 5.0)
	_hud.narrate(Story.REDACTION_NOTICED, false, 4.5)
	await _hud.tutorial("binder")
	await _hud.tutorial("stealth")
	_spawn_enemies()

# Which kinds of Error have shown up yet depends on how far the story has gone: the Prologue starts
# with the Bare and the Mite, and Pip's and Maud's restorations let more of the Redaction seep in.
func _kind_unlocked(k: Enemy.Kind) -> bool:
	match k:
		Enemy.Kind.SLUG, Enemy.Kind.DANGLER:
			return GameState.is_restored("pip")
		Enemy.Kind.CENSOR, Enemy.Kind.ELLIPSIS:
			return GameState.is_restored("maud")
	return true

# Enemies are streamed by distance: they wake when you come within about 900 px (never right on
# top of you) and fade out far behind you. A defeated one stays away for a couple of minutes.
var _stream_t := 0.0
func _spawn_enemies(_avoid: Vector2 = Vector2(INF, INF)) -> void:
	if _enemies_out:
		return
	_enemies_out = true
	for sp in _enemy_spawns:
		_spawn_state.append({"kind": sp["kind"], "cell": sp["cell"], "node": null, "wake": 0.0})

# Areas for the playtest log, and where you wake up after being crumpled.
func _room_name(cell: Vector2i) -> String:
	if PrologueMap.region_at(cell) == "t" and cell.x >= 28 + PrologueMap.OFFSET.x and cell.y >= 13 + PrologueMap.OFFSET.y:
		return "Garrick's Terrace"
	return PrologueMap.region_name(cell)

## You wake at the nearest lit lantern post, or at the start if you have not lit one.
func _checkpoint_for(cell: Vector2i) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for wp: Dictionary in PrologueMap.WAYPOINTS:
		if not GameState.waypoint_lit(wp["id"]):
			continue
		var c := Vector2i(int(wp["cell"][0]), int(wp["cell"][1]))
		var dd := Vector2(c - cell).length()
		if dd < best_d:
			best_d = dd
			best = Iso.to_screen(Vector2(c) + Vector2(0, 1))
	if best_d < INF:
		return best
	if PrologueMap.region_at(cell) == "t":
		return Iso.to_screen(Vector2(23, 13) + Vector2(PrologueMap.OFFSET))
	return _map_start

## Resting at a lantern post resets the page: every Error you beat comes back (they reappear as
## you walk away from the post, so nothing pops in on top of you).
func _respawn_world() -> void:
	if not _enemies_out:
		return
	_on_death_reset()
	for sp in _spawn_state:
		sp["wake"] = 0.0
	_stream_t = 0.0
	Telemetry.log_event("rest_respawn", {})

func _on_death_reset() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for sp in _spawn_state:
		sp["node"] = null

func _introduce_enemy(k: Enemy.Kind) -> void:
	var flag := "met_enemy_%d" % int(k)
	if GameState.has_flag(flag) or not Story.ENEMY_INTRO.has(int(k)):
		return
	GameState.set_flag(flag)
	_hud.narrate(Story.ENEMY_INTRO[int(k)], false, 6.0)

func _tick_respawns(delta: float) -> void:
	if not _enemies_out:
		return
	_stream_t -= delta
	if _stream_t > 0.0:
		return
	_stream_t = 0.5
	var now := Time.get_ticks_msec() / 1000.0
	for sp in _spawn_state:
		var pos := Iso.to_screen(Vector2(sp["cell"]))
		var dist := _dist(pos, _player.position)
		var node = sp["node"]
		if node != null and is_instance_valid(node):
			if dist > 1500.0:
				node.queue_free()
				sp["node"] = null
		elif dist < 900.0 and dist > 560.0 and now >= float(sp["wake"]) and _kind_unlocked(sp["kind"]):
			var e := _add_enemy(sp["kind"], sp["cell"])
			_introduce_enemy(sp["kind"])
			sp["node"] = e
			e.died.connect(func(_en): sp["wake"] = Time.get_ticks_msec() / 1000.0 + 120.0)

func _hint_redactor() -> void:
	if _redactor_hinted or _redactor == null or not is_instance_valid(_redactor):
		return
	if _dist(_redactor.position, _player.position) < 150.0 and not GameState.in_dialogue:
		_redactor_hinted = true
		_hud.narrate(Story.REDACTOR_HINT, false, 6.0)

func _restoration_scene(id: String, npc: Npc) -> void:
	_dialogue.hold(true)
	_hud.set_prompt("")
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_camera, "zoom", Vector2(ZOOM * 1.18, ZOOM * 1.18), 2.0).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.8).timeout
	_hud.narrate(Story.RESTORED_NARRATION, false, 3.0)
	GameState.start_restoration(id, npc.position)
	await get_tree().create_timer(GameState.RESTORE_DURATION * 0.75).timeout
	var back := create_tween()
	back.tween_property(_camera, "zoom", Vector2(ZOOM, ZOOM), 2.5).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.2).timeout
	_dialogue.hold(false)
