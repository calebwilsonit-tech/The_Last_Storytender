extends LevelBase
## The Blacksmith's Regret. A forge where the fire is frozen in time.
## Garrick forgot why he forges. Hold up three memories to the Lantern to
## quiet The Critic (his own doubt), and the First Sword is waiting on the anvil.

const OVERWORLD := "res://scenes/main.tscn"
const ARENA_X := 13

var _critic: Critic
var _shards: Array[Prop] = []
var _anvil: Prop
var _sword: Prop
var _remembered := 0
var _boss_started := false
var _finale_started := false
var _leaving := false
var _pools: Array[Dictionary] = []   # {cells, t, phase}
var _pool_tick := 0.0
var _slow_t := 0.0
var _dim_t := 0.0

# --- LevelBase hooks ---------------------------------------------------------------
func _map_rows() -> Array[String]:
	return MemoryForgeMap.ROWS

func _map_heights() -> Array[String]:
	return MemoryForgeMap.HEIGHTS

func _paper_params() -> Dictionary:
	# A colder, darker page: the inside of a held breath.
	return {
		"paper_light": Color(0.20, 0.25, 0.34),
		"paper_dark": Color(0.08, 0.11, 0.18),
		"script_color": Color(0.30, 0.70, 0.85),
		"script_strength": 0.10,
		"vignette": 0.7,
	}

func _spawn_char(ch: String, cell: Vector2i, consumed: Dictionary) -> bool:
	match ch:
		"P":
			_floor.cells[cell] = "m"
			_start = Iso.to_screen(Vector2(cell))
		"E":
			_floor.cells[cell] = "m"
			var portal := _add_prop(Prop.Kind.PORTAL, cell)
			_register(portal, _portal_prompt, _leave_early, 70.0)
		"O":
			for dx in 2:
				for dy in 2:
					var c2 := cell + Vector2i(dx, dy)
					consumed[c2] = true
					_floor.cells[c2] = "m"
			var hp := Prop.new()
			hp.kind = Prop.Kind.FORGE
			hp.variant = 99          # full-color furnace, frozen flame
			hp.lift = _lift_at(cell)
			hp.position = Iso.to_screen(Vector2(cell) + Vector2(0.5, 0.5))
			_actors.add_child(hp)
		"A":
			_floor.cells[cell] = "m"
			_anvil = _add_prop(Prop.Kind.ANVIL, cell)
		"Y", "w":
			_floor.cells[cell] = "m"
			_add_prop(Prop.Kind.FIGURE, cell, false, 0 if ch == "Y" else 1)
		"1", "2", "3":
			_floor.cells[cell] = "m"
			var idx := int(ch)
			var sh := _add_prop(Prop.Kind.SHARD, cell, false, idx)
			_shards.append(sh)
			_register(sh, func(): return "Hold up the memory" if (_boss_started and not sh.done and not _busy) else "", func(): await _remember(sh))
		"Z":
			_floor.cells[cell] = "m"
			_critic = Critic.new()
			_critic.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(_critic)
		"k":
			_floor.cells[cell] = "m"
			_add_pickup(cell, "oxford_comma")
		"B":
			_floor.cells[cell] = "m"
			_floor.blockers[cell] = true
			var b := IsoBlock.new()
			b.position = Iso.to_screen(Vector2(cell))
			b.tint = Color("56627a")
			b.height = 30.0
			_actors.add_child(b)
		_:
			return false
	return true

func _level_ready() -> void:
	_hud.set_dark(true)
	_player.lantern_power = 1.7
	_critic.target = _player
	_critic.fired.connect(_on_critic_fired)
	_critic.pool_requested.connect(_on_pool)
	_hud.set_objective(Story.MEMORY_OBJECTIVE % 0)
	_hud.set_region("The Blacksmith's Regret")
	await get_tree().create_timer(2.6).timeout
	_hud.narrate(Story.MEMORY_INTRO, false, 4.0)

func _level_process(delta: float) -> void:
	# Stepping into the forge hall wakes The Critic.
	if not _boss_started and _floor.cell_at(_player.position).x >= ARENA_X and not GameState.in_dialogue:
		_start_boss()
	_check_bolts()
	_tick_pools(delta)
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_player.speed_mult = 1.0
	if _dim_t > 0.0:
		_dim_t -= delta
		_hud.set_dim(clampf(_dim_t / 0.6, 0.0, 1.0) * 0.55)
	else:
		_hud.set_dim(0.0)

# --- Boss flow ------------------------------------------------------------------------
func _start_boss() -> void:
	_boss_started = true
	_busy = true
	await _say(Story.boss_intro())
	_critic.active = true
	_busy = false

func _on_critic_fired(word: String, fx: String, origin: Vector2, dir: Vector2) -> void:
	var b := WordBolt.new()
	b.word = word
	b.fx = fx
	b.floor_ref = _floor
	b.position = origin
	b.vel = dir * _critic.bolt_speed()
	_actors.add_child(b)

func _check_bolts() -> void:
	if _player.is_falling or _player.is_crumpled:
		return
	for b: WordBolt in get_tree().get_nodes_in_group("bolts"):
		if _dist(b.position, _player.position) > 20.0:
			continue
		if absf(_floor.height_at(b.position) - _floor.height_at(_player.position)) > 0.7:
			continue
		_player.take_damage(9.0 * GameState.enemy_dmg_mult(), true, "critic_word")
		_hud.debuff(b.word)
		match b.fx:
			"slow":
				_slow_t = 3.0
				_player.speed_mult = 0.55
			"dim":
				_dim_t = 2.5
		camera_shake(0.25, 3.0)
		b.queue_free()

func _clear_bolts() -> void:
	for b in get_tree().get_nodes_in_group("bolts"):
		b.queue_free()

func _remember(shard: Prop) -> void:
	Telemetry.log_event("boss", {"boss": "critic", "what": "remembered", "n": _remembered + 1})
	_critic.active = false
	_clear_bolts()
	_clear_pools()
	_slow_t = 0.0
	_player.speed_mult = 1.0
	await _say(Story.shard_memory(shard.variant))
	shard.done = true
	_remembered += 1
	_critic.layers -= 1
	_critic.recoil()
	camera_shake(0.6, 8.0)
	_hud.set_objective(Story.MEMORY_OBJECTIVE % _remembered)
	_hud.narrate(Story.MEMORY_SHARD_NARRATION[_remembered - 1], false, 3.5)
	if _critic.layers <= 0:
		_finale()
	else:
		await get_tree().create_timer(1.6).timeout
		_critic.active = true

func _finale() -> void:
	if _finale_started:
		return
	_finale_started = true
	_busy = true
	await get_tree().create_timer(1.8).timeout
	await _say(Story.critic_finale())
	await get_tree().create_timer(2.6).timeout
	_critic.queue_free()
	_hud.set_objective("")
	_sword = _add_prop(Prop.Kind.SWORD, _floor.cell_at(_anvil.position))
	_sword.lift = _anvil.lift + 26.0
	_register(_sword, func(): return "Take the First Sword", _take_sword, 90.0)
	_hud.narrate("On the anvil, something small is waiting.", false, 4.0)
	_busy = false

func _handle_cue(cue: String) -> void:
	if cue == "dissolve":
		_critic.dissolve()

func _take_sword() -> void:
	await _say(Story.memory_sword())
	GameState.set_flag("has_sword")
	GameState.set_flag("memory_done")
	_hud.toast("Found: The First Sword")
	_hud.narrate(Story.MEMORY_SWORD_NARRATION, false, 4.0)
	if is_instance_valid(_sword):
		create_tween().tween_property(_sword, "modulate:a", 0.0, 0.8)
	await get_tree().create_timer(3.4).timeout
	_leave()

# --- Red ink pools: the Critic's "cuts" on the floor ---------------------------------------------
func _on_pool(at: Vector2) -> void:
	var center := _floor.cell_at(at)
	var cells: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := center + Vector2i(dx, dy)
			if _floor.cells.get(c, "") == "m" and not _floor.stairs.has(c) and _floor.level(c) == 0:
				cells.append(c)
	if cells.is_empty():
		return
	for c in cells:
		_floor.marks[c] = {"kind": "crack", "t": 0.0}
	_pools.append({"cells": cells, "t": 1.3, "phase": "warn"})

func _tick_pools(delta: float) -> void:
	_pool_tick = maxf(_pool_tick - delta, 0.0)
	for pool in _pools.duplicate():
		pool["t"] = float(pool["t"]) - delta
		if pool["phase"] == "warn" and pool["t"] <= 0.0:
			pool["phase"] = "active"
			pool["t"] = 4.0
			for c in pool["cells"]:
				_floor.marks[c] = {"kind": "ink", "t": 0.0}
		elif pool["phase"] == "active":
			if _pool_tick <= 0.0 and not _player.is_falling and pool["cells"].has(_floor.cell_at(_player.position)):
				_pool_tick = 0.6
				_player.take_damage(6.0 * GameState.enemy_dmg_mult(), true, "ink_pool")
			if pool["t"] <= 0.0:
				for c in pool["cells"]:
					_floor.marks.erase(c)
				_pools.erase(pool)

func _clear_pools() -> void:
	for pool in _pools:
		for c in pool["cells"]:
			_floor.marks.erase(c)
	_pools.clear()

func _room_name(cell: Vector2i) -> String:
	return "The Forge" if cell.x >= ARENA_X else "Antechamber"

func _checkpoint_for(cell: Vector2i) -> Vector2:
	return Iso.to_screen(Vector2(13, 12)) if cell.x >= ARENA_X else _map_start

func _on_death_reset() -> void:
	_clear_bolts()
	_clear_pools()
	_slow_t = 0.0
	_player.speed_mult = 1.0

# --- Leaving --------------------------------------------------------------------------
func _portal_prompt() -> String:
	return "" if _leaving else "Leave the memory"

func _leave_early() -> void:
	_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Transition.go(OVERWORLD, Palette.CYAN.lightened(0.7))
	await get_tree().create_timer(30.0).timeout
