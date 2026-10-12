extends LevelBase
## The overworld: the Prologue Plains and Thistledown (the first Ghost Town).
## Built from data/prologue_map.gd. Restoring Thistledown means entering
## Garrick's memory (the forge's frozen flame), then returning the First Sword.

const MEMORY_SCENE := "res://scenes/memory_forge.tscn"
const PIP_MEMORY_SCENE := "res://scenes/memory_pip.tscn"
const MAUD_MEMORY_SCENE := "res://scenes/memory_maud.tscn"
const RETURN_CELL := Vector2i(30, 15)       # where you step out of the memory

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
			_crystals.append(_add_prop(Prop.Kind.CRYSTAL, cell))
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
		"k":
			_floor.cells[cell] = "."
			_add_pickup(cell, "softcover_binding")
		"V":
			_floor.cells[cell] = ","
			_floor.blockers[cell] = true
			_oven = _add_prop(Prop.Kind.OVEN, cell)
			_register(_oven, _oven_prompt, _touch_oven, 110.0)
		"Q":
			_floor.cells[cell] = ","
			_book = _add_prop(Prop.Kind.BOOK, cell)
			_register(_book, _book_prompt, _touch_book, 90.0)
		"g", "x":
			_floor.cells[cell] = "."
			_enemy_spawns.append({"kind": Enemy.Kind.BARE if ch == "g" else Enemy.Kind.MITE, "cell": cell})
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
	_player.dashed.connect(_on_dashed)
	if GameState.has_flag("maud_memory_done") and is_instance_valid(_oven):
		pass   # the oven stays; Maud is baking in it now
	if GameState.has_flag("pip_memory_done") and is_instance_valid(_book):
		_book.queue_free()   # the storybook has done its job
	if GameState.has_flag("lesson_done"):
		_spawn_enemies()
	if GameState.has_flag("memory_done") and not GameState.is_restored("garrick"):
		_hud.narrate(Story.RETURNED, false, 5.0)
	elif not GameState.has_flag("intro_done"):
		GameState.set_flag("intro_done")
		_start_intro()

func _start_intro() -> void:
	await get_tree().create_timer(1.2).timeout
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

# --- Frame helpers ---------------------------------------------------------------------
func _update_region() -> void:
	var cell := _floor.cell_at(_player.position)
	if cell.x >= IsoFloor.PLAINS_X_LIMIT:
		_hud.set_region("Thistledown — Published Chapter" if GameState.town_published else "Thistledown (Draft)")
		if not _entered_town:
			_entered_town = true
			_hud.narrate(Story.SILENCE_WHISPER, true, 5.0)
	else:
		_hud.set_region("The Prologue Plains")

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
		elif _tutorial >= 1 and _tutorial <= 3:
			await _say(Story.garrick_lesson_hint(_tutorial))
		else:
			await _say(Story.garrick_restored())
	elif GameState.has_flag("memory_done"):
		await _say(Story.garrick_restoration())
		GameState.add_mnemosynth(25)
		_hud.toast("Restored: Garrick")
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
			_hud.set_objective("Strike the training dummy: %d / 3   (click or J)" % _strikes)
		2:
			_hud.set_objective("Dash with Shift")
		3:
			_lantern_time = 0.0
			_hud.set_objective("Hold Q or right mouse: shine your Lantern")
		_:
			_hud.set_objective("")

func _on_dummy_struck() -> void:
	if _tutorial != 1:
		return
	_strikes += 1
	_hud.set_objective("Strike the training dummy: %d / 3   (click or J)" % mini(_strikes, 3))
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
	_spawn_enemies()

func _spawn_enemies(avoid: Vector2 = Vector2(INF, INF)) -> void:
	if _enemies_out:
		return
	_enemies_out = true
	for sp in _enemy_spawns:
		# After a death, nothing re-appears right on top of where you wake up.
		if avoid.x != INF and _dist(Iso.to_screen(Vector2(sp["cell"])), avoid) < 520.0:
			continue
		_add_enemy(sp["kind"], sp["cell"])

# Areas for the playtest log, and where you wake up after being crumpled.
func _room_name(cell: Vector2i) -> String:
	if cell.x < IsoFloor.PLAINS_X_LIMIT:
		return "Glade" if (cell.x <= 8 and cell.y >= 18) else "Prologue Plains"
	return "Garrick's Terrace" if (cell.x >= 28 and cell.y >= 13) else "Thistledown"

func _checkpoint_for(cell: Vector2i) -> Vector2:
	if cell.x < IsoFloor.PLAINS_X_LIMIT:
		return _map_start
	return Iso.to_screen(Vector2(23, 13))

func _on_death_reset() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	_enemies_out = false
	if GameState.has_flag("lesson_done"):
		_spawn_enemies(_player.position)

# Errors drift back in over time, so the Plains never stay empty.
func _tick_respawns(delta: float) -> void:
	if not _enemies_out:
		return
	_respawn_t += delta
	if _respawn_t < 75.0:
		return
	_respawn_t = 0.0
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= _enemy_spawns.size() * 0.6:
		return
	var pool := _enemy_spawns.duplicate()
	pool.shuffle()
	for sp in pool:
		if _dist(Iso.to_screen(Vector2(sp["cell"])), _player.position) > 550.0:
			_add_enemy(sp["kind"], sp["cell"])
			return

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
