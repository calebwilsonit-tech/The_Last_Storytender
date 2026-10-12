extends LevelBase
## The overworld: the Prologue Plains and Thistledown (the first Ghost Town).
## Built from data/prologue_map.gd. Restoring Thistledown means entering
## Garrick's memory (the forge's frozen flame), then returning the First Sword.

const MEMORY_SCENE := "res://scenes/memory_forge.tscn"
const RETURN_CELL := Vector2i(30, 15)       # where you step out of the memory

var _crystals: Array[Prop] = []
var _forge: Prop
var _garrick: Npc
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
			_garrick = n
			_register(n, func(): return "Speak", _talk_garrick)
		"K":
			n.kind = Npc.Kind.CHILD
			_register(n, func(): return "Speak", func(): await _say(Story.pip_restored() if GameState.town_restored else Story.pip_ghost()))
		"B":
			n.kind = Npc.Kind.BAKER
			_register(n, func(): return "Speak", func(): await _say(Story.maud_restored() if GameState.town_restored else Story.maud_ghost()))

func _level_ready() -> void:
	if GameState.has_flag("memory_done") and not GameState.town_restored:
		_hud.narrate(Story.RETURNED, false, 5.0)
	elif not GameState.has_flag("intro_done"):
		GameState.set_flag("intro_done")
		_start_intro()

func _start_intro() -> void:
	await get_tree().create_timer(1.2).timeout
	for t in Story.INTRO:
		_hud.narrate(t, false, 3.2)
		await get_tree().create_timer(5.6).timeout

func _level_process(_delta: float) -> void:
	_collect_crystals()
	_update_region()

# --- Frame helpers ---------------------------------------------------------------------
func _collect_crystals() -> void:
	for c in _crystals.duplicate():
		if _dist(c.position, _player.position) < 30.0 and absf(c.lift - _player.elev) < 20.0:
			_crystals.erase(c)
			GameState.add_mnemosynth(5)
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
			tw.tween_callback(c.queue_free)

func _update_region() -> void:
	var cell := _floor.cell_at(_player.position)
	if cell.x >= IsoFloor.PLAINS_X_LIMIT:
		_hud.set_region("Thistledown — Published Chapter" if GameState.town_restored else "Thistledown (Draft)")
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
			await _restoration_scene()

# --- Story beats -----------------------------------------------------------------------
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
	if GameState.town_restored:
		await _say(Story.garrick_restored())
	elif GameState.has_flag("memory_done"):
		await _say(Story.garrick_restoration())
		GameState.add_mnemosynth(25)
		_hud.toast("Chapter Restored: Thistledown")
		_garrick.tearful = false
		GameState.set_flag("town_restored")
	elif GameState.has_flag("met_garrick"):
		await _say(Story.garrick_ghost_repeat())
	else:
		GameState.set_flag("met_garrick")
		await _say(Story.garrick_ghost())

func _restoration_scene() -> void:
	_dialogue.hold(true)
	_hud.set_prompt("")
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_camera, "zoom", Vector2(ZOOM * 1.18, ZOOM * 1.18), 2.0).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.8).timeout
	_hud.narrate(Story.RESTORED_NARRATION, false, 3.0)
	GameState.start_restoration(_garrick.position)
	await get_tree().create_timer(GameState.RESTORE_DURATION * 0.75).timeout
	var back := create_tween()
	back.tween_property(_camera, "zoom", Vector2(ZOOM, ZOOM), 2.5).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.2).timeout
	_dialogue.hold(false)
