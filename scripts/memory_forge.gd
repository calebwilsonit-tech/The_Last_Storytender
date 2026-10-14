extends LevelBase
## The Blacksmith's Regret. A forge where the fire is frozen in time.
## Garrick forgot why he forges. Hold up three memories to the Lantern to
## quiet The Critic (his own doubt), and the First Sword is waiting on the anvil.

const OVERWORLD := "res://scenes/main.tscn"
const ARENA_X := 42
## Echo gates: gate char -> the plates that hold it open.
const ROOM_GATES := [["g", ["a"]], ["h", ["b", "c"]], ["i", ["d"]], ["l", ["e"]], ["n", ["j"]]]
## Gate geometry: axis along the wall and how many cells it spans.
const GATE_SPEC := {"g": [Vector2(0, 1), 3.0], "h": [Vector2(1, 0), 3.0], "i": [Vector2(1, 0), 3.0],
	"l": [Vector2(0, 1), 3.0], "n": [Vector2(0, 1), 3.0], "D": [Vector2(0, 1), 5.0]}
const TOKENS := {"T": "hammer", "U": "tongs", "V": "bellows"}
const R_START := 0
const R_HUB := 1
const R_LOFT := 2
const R_BENCH := 3
const R_WATCH := 4
const R_FORGE := 5

var _critic: Critic
var _shards: Array[Prop] = []
var _anvil: Prop
var _sword: Prop
var _remembered := 0
var _boss_started := false
var _boss_away := false
var _finale_started := false
var _leaving := false
var _pools: Array[Dictionary] = []   # {cells, t, phase}
var _pool_tick := 0.0
var _slow_t := 0.0
var _dim_t := 0.0
var _plate_nodes: Dictionary = {}      # char -> EchoPlate
var _gate_nodes: Dictionary = {}       # char -> StoryGate
var _gate_open_seen := {}
var _guard_spawns: Array[Vector2i] = []
var _looked := {}
var _room_seen := {}
var _tokens := {}                      # kind -> true once carried
var _door: StoryGate

# --- LevelBase hooks ---------------------------------------------------------------
func _music_slot() -> String:
	return "memory_forge"

func _dungeon_extras() -> Array:
	return [
		{"kind": "post", "cell": Vector2i(36, 11)},
		{"kind": "vault", "cell": Vector2i(4, 9), "tier": 1},
		{"kind": "vault", "cell": Vector2i(21, 1), "tier": 2},
		{"kind": "vault", "cell": Vector2i(37, 15), "tier": 3},
		{"kind": "mob", "cell": Vector2i(24, 10), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(33, 12), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(26, 3), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(34, 3), "mob": Enemy.Kind.MITE},
		{"kind": "mob", "cell": Vector2i(12, 25), "mob": Enemy.Kind.BARE},
		{"kind": "mob", "cell": Vector2i(36, 15), "mob": Enemy.Kind.MITE},
	]

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
			_map_start = _start
		"a", "b", "c", "d", "e", "j":
			_floor.cells[cell] = "m"
			var plate := EchoPlate.new()
			plate.floor_ref = _floor
			plate.position = Iso.to_screen(Vector2(cell))
			plate.elev = _lift_at(cell)
			_actors.add_child(plate)
			_plate_nodes[ch] = plate
		"g", "h", "i", "l", "n", "D":
			_floor.cells[cell] = "m"
			var gate := StoryGate.new()
			gate.axis = GATE_SPEC[ch][0]
			gate.length = GATE_SPEC[ch][1]
			gate.label = "FORGOTTEN" if ch != "D" else "FORGOTTEN 0/3"
			gate.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(gate)
			if ch == "D":
				_door = gate
			else:
				_gate_nodes[ch] = gate
		"T", "U", "V":
			_floor.cells[cell] = "m"
			var key := DungeonKey.new()
			key.kind = TOKENS[ch]
			key.position = Iso.to_screen(Vector2(cell))
			key.elev = _lift_at(cell)
			_actors.add_child(key)
			_register(key, func(): return "Take the " + String(key.kind), func(): _take_token(key), 80.0)
		"R":
			_floor.cells[cell] = "m"
			var bar := _add_redactor(cell, Vector2(1, 0), 3.0, "the tongs")
			bar.revealed.connect(func(): _hud.narrate("The black bar lifts. Underneath, in a master's hand: 'Check the bench.'", false, 4.0))
		"f", "y", "z":
			_floor.cells[cell] = "m"
			var idx := "fyz".find(ch)
			var fig := _add_prop(Prop.Kind.FIGURE, cell, false, 1 if ch == "f" else 0)
			_register(fig, func(): return "" if _looked.has(idx) else "Look", func(): await _look(idx), 80.0)
		"Q":
			_floor.cells[cell] = "m"
			_guard_spawns.append(cell)
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
	echo_enabled = true
	for plate: EchoPlate in _plate_nodes.values():
		plate.player = _player
	for c in _guard_spawns:
		_add_enemy(Enemy.Kind.BARE, c)
	_hud.set_dark(true)
	_player.lantern_power = 1.7
	_critic.target = _player
	_critic.fired.connect(_on_critic_fired)
	_critic.pool_requested.connect(_on_pool)
	_critic.damaged.connect(func(frac: float): _hud.set_boss("The Critic", frac))
	_critic.defeated.connect(_on_critic_defeated)
	_hud.set_objective(Story.FORGE_OBJECTIVES[0])
	_hud.set_region("The Blacksmith's Regret")
	await get_tree().create_timer(2.6).timeout
	_hud.narrate(Story.MEMORY_INTRO, false, 4.0)
	await get_tree().create_timer(3.5).timeout
	_busy = true
	if Settings.tutorial_tips:
		await _hud.tutorial("echo")
	else:
		await _say(Story.echo_grant())
	_busy = false

func _room_for(cell: Vector2i) -> int:
	if cell.x >= ARENA_X:
		return R_FORGE
	if cell.x <= 16:
		return R_START
	if cell.y <= 5:
		return R_LOFT
	if cell.y >= 16:
		return R_BENCH if cell.x <= 23 else R_WATCH
	return R_HUB

func _level_process(delta: float) -> void:
	var room := _room_for(_floor.cell_at(_player.position))
	if not _room_seen.has(room):
		_room_seen[room] = true
		if room > R_START and room < R_FORGE:
			_hud.set_objective(Story.FORGE_OBJECTIVES[room] if not _all_tokens() else Story.FORGE_DOOR_OPEN)
	_tick_gates()
	# Stepping into the forge hall wakes The Critic.
	if not _boss_started and _floor.cell_at(_player.position).x >= ARENA_X and not GameState.in_dialogue:
		_start_boss()
	_tick_boss_presence()
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

## The Critic waits while you are out of the forge (after crumpling you wake at the lantern by the door).
func _tick_boss_presence() -> void:
	if not _boss_started or _finale_started or _busy:
		return
	var inside := _floor.cell_at(_player.position).x >= ARENA_X
	if not inside and _critic.active:
		_critic.active = false
		_boss_away = true
		_clear_bolts()
		_clear_pools()
	elif inside and _boss_away:
		_boss_away = false
		_critic.active = true

func travel_blocked() -> String:
	return "Not while the Critic is watching. Finish this first." if (_boss_started and not _finale_started) else ""

# --- Boss flow ------------------------------------------------------------------------
func _start_boss() -> void:
	_boss_started = true
	_busy = true
	Music.play("boss_critic")
	await cinematic([{"at": _critic.position, "zoom": ZOOM * 1.25, "pan": 1.5, "hold": 0.5, "lines": Story.boss_intro()}])
	_critic.active = true
	_busy = false

func _on_critic_fired(word: String, fx: String, origin: Vector2, dir: Vector2) -> void:
	var b := WordBolt.new()
	b.word = word
	b.fx = fx
	b.floor_ref = _floor
	b.position = origin
	b.vel = dir * _critic.bolt_speed()
	if _critic.reckoning:
		b.reflectable = true
		b.reflect_to = _critic
	_actors.add_child(b)

func _check_bolts() -> void:
	if _player.is_falling or _player.is_crumpled:
		return
	for b: WordBolt in get_tree().get_nodes_in_group("bolts"):
		if b.friendly:
			# A rewritten word flies home and lands on the Critic.
			if is_instance_valid(_critic) and _dist(b.position, _critic.position) < 46.0:
				_critic.hurt(18.0)
				camera_shake(0.2, 3.0)
				b.queue_free()
			continue
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
		_begin_reckoning()
	else:
		await get_tree().create_timer(1.6).timeout
		_critic.active = true

## Every memory is held up: the Critic loses its plates and becomes something you can hit.
func _begin_reckoning() -> void:
	_busy = true
	await get_tree().create_timer(1.4).timeout
	await cinematic([{"at": _critic.position, "zoom": ZOOM * 1.35, "pan": 0.9, "hold": 0.6, "lines": Story.critic_reckoning()}])
	_hud.set_objective(Story.CRITIC_FIGHT_OBJECTIVE)
	_critic.begin_reckoning()
	Music.play("boss_critic_reckoning", "boss_critic")
	Telemetry.log_event("boss", {"boss": "critic", "what": "reckoning"})
	_busy = false

func _on_critic_defeated() -> void:
	_clear_bolts()
	_clear_pools()
	_slow_t = 0.0
	_player.speed_mult = 1.0
	_hud.set_boss("", 0.0)
	Music.play("victory", "memory_forge", 0.8)
	Telemetry.log_event("boss", {"boss": "critic", "what": "defeated"})
	camera_shake(0.7, 9.0)
	_finale()

func _finale() -> void:
	if _finale_started:
		return
	_finale_started = true
	_busy = true
	await get_tree().create_timer(1.8).timeout
	await cinematic([{"at": _critic.position, "zoom": ZOOM * 1.3, "pan": 1.0, "hold": 1.2, "lines": Story.critic_finale()}])
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
	var at := _sword.position if is_instance_valid(_sword) else _player.position
	await cinematic([{"at": at, "zoom": ZOOM * 1.5, "pan": 1.3, "hold": 1.0, "lines": Story.memory_sword()}])
	GameState.set_flag("has_sword")
	GameState.set_flag("memory_done")
	award_boss_drops("forge")
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
	return ["The Cold Hearth", "The Long Hall", "The Bellows Loft", "The Apprentice's Bench", "The Night Watch", "The Forge"][_room_for(cell)]

func _checkpoint_for(cell: Vector2i) -> Vector2:
	match _room_for(cell):
		R_START: return _map_start
		R_FORGE: return Iso.to_screen(Vector2(ARENA_X, 11))
		R_LOFT: return Iso.to_screen(Vector2(28, 6))
		R_BENCH: return Iso.to_screen(Vector2(20, 16))
		R_WATCH: return Iso.to_screen(Vector2(32, 16))
		_: return Iso.to_screen(Vector2(19, 10))

# --- Tokens and the forge door ----------------------------------------------------------
func _all_tokens() -> bool:
	return _tokens.size() >= TOKENS.size()

func _take_token(key: DungeonKey) -> void:
	_tokens[key.kind] = true
	Telemetry.log_event("puzzle", {"p": "forge_token_" + key.kind})
	create_tween().tween_property(key, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(key.queue_free)
	_hud.toast("Found: Garrick's %s (%d/3)" % [key.kind, _tokens.size()])
	if is_instance_valid(_door):
		_door.label = "FORGOTTEN %d/3" % _tokens.size()
		_door.queue_redraw()
	if _all_tokens():
		_door.open()
		_hud.set_objective(Story.FORGE_DOOR_OPEN)
		_hud.narrate(Story.FORGE_DOOR_NARRATION, false, 5.0)
		Telemetry.log_event("puzzle", {"p": "forge_door"})
	else:
		_hud.narrate(Story.FORGE_TOKEN_NARRATION[_tokens.size() - 1], false, 4.0)

func _tick_gates() -> void:
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
			if not _gate_open_seen.has(gk):
				_gate_open_seen[gk] = true
				_hud.narrate(Story.FORGE_GATE_OPEN, false, 4.0)
				Telemetry.log_event("puzzle", {"p": "echo_gate_" + gk})
		elif not want and gate.is_open and _dist(_player.position, gate.position) > 90.0:
			gate.close()

func _look(idx: int) -> void:
	_looked[idx] = true
	await _say(Story.forge_look(idx))

func _on_death_reset() -> void:
	_critic.reset_fight()
	_clear_echoes()
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
