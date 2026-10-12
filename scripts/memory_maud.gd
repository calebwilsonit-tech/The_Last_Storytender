extends LevelBase
## Maud's memory: "The Empty Table". A warm kitchen gone cold. This memory's verb is
## FORMAT: strike words with the Quill after picking a style (keys 1/2/3), and
## typography behaves like physics.
##  1. The Pantry   - UNDERLINE a floating word and it becomes a bridge.
##  2. The Kitchen  - BOLD + ITALIC: send heavy SALT sliding onto a pressure plate.
##  3. The Cellar   - dough cannot be rushed. Wait for it (and sneak past what patrols).
##  4. The Hall     - The Empty Table: lead warm guests to chairs between cold waves,
##                    sheltering behind heavy words.

const OVERWORLD := "res://scenes/main.tscn"
const RETURN_CELL := Vector2i(26, 19) + PrologueMap.OFFSET
const TABLE_CELL := Vector2i(35, 4)
const TABLE_LEN := 5
const GUESTS := 6
const WAVE_DIRS := {"WEST": Vector2i(1, 0), "EAST": Vector2i(-1, 0), "NORTH": Vector2i(0, 1), "SOUTH": Vector2i(0, -1)}

var _enemy_spawns: Array[Dictionary] = []
var _bread: TextBlock
var _salt: TextBlock
var _dough: TextBlock
var _plate: PressurePlate
var _gate: StoryGate
var _table: Prop
var _chairs: Array[Prop] = []
var _serve_blocks: Array[TextBlock] = []
var _maud_fig: Prop
var _guests: Array[Guest] = []
var _arena_cells: Array[Vector2i] = []
var _arena_min := Vector2i.ZERO
var _arena_max := Vector2i.ZERO
var _room_seen := {}
var _boss_started := false
var _finale_done := false
var _leaving := false
var _guest_timer := 0.0
var _seated := 0
var _wave: Dictionary = {}
var _wave_cd := 8.0
var _wipes: Dictionary = {}
var _serve_i := 0
var _dough_hinted := false

# --- LevelBase hooks ---------------------------------------------------------------------------------
func _music_slot() -> String:
	return "memory_maud"

func _dungeon_extras() -> Array:
	return [
		{"kind": "post", "cell": Vector2i(6, 17)},
		{"kind": "vault", "cell": Vector2i(8, 16), "tier": 1},
		{"kind": "vault", "cell": Vector2i(22, 15), "tier": 2},
		{"kind": "vault", "cell": Vector2i(39, 16), "tier": 3},
		{"kind": "post", "cell": Vector2i(38, 12)},
	]

func _map_rows() -> Array[String]:
	return MemoryMaudMap.ROWS

func _map_heights() -> Array[String]:
	return MemoryMaudMap.HEIGHTS

func _paper_params() -> Dictionary:
	# Warm, amber, a little dim: a kitchen in late afternoon.
	return {"paper_light": Color(0.80, 0.62, 0.40), "paper_dark": Color(0.52, 0.36, 0.22),
		"script_color": Color(0.35, 0.2, 0.1), "script_strength": 0.08, "vignette": 0.6}

func _make_block(cell: Vector2i, word: String, length: int, lean: Vector2i, rise: float = 0.0) -> TextBlock:
	var b := TextBlock.new()
	b.rise_time = rise   # must be set before it enters the scene
	b.word = word
	b.cell = cell
	b.length = length
	b.lean = lean
	b.floor_ref = _floor
	b.elev = _lift_at(cell)
	b.player_cell = func() -> Vector2i: return _floor.cell_at(_player.position)
	_actors.add_child(b)
	_register(b, func(): return "Format (%s)" % GameState.format_style, func(): b.hurt(), 90.0)
	return b

func _spawn_char(ch: String, cell: Vector2i, _consumed: Dictionary) -> bool:
	if ch in "wPELGdgxCBMhYeqa":
		_floor.cells[cell] = "#" if (ch == "a" or ch == "d") else "w"
	match ch:
		"P":
			_start = Iso.to_screen(Vector2(cell))
			_map_start = _start
		"E":
			var portal := _add_prop(Prop.Kind.PORTAL, cell)
			_register(portal, func(): return "" if _leaving else "Leave the memory", _leave, 70.0)
		"a":
			_bread = _make_block(cell, "BREAD", 3, Vector2i(1, 0))
		"q":
			_salt = _make_block(cell, "SALT", 1, Vector2i(1, 0))
		"d":
			_dough = _make_block(cell, "DOUGH", 3, Vector2i(1, 0), 28.0 if GameState.is_story() else 36.0)
		"e":
			var leans := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
			var lean_v: Vector2i = leans[_serve_i % 3]
			_serve_i += 1
			_serve_blocks.append(_make_block(cell, "SERVE", 2, lean_v))
		"L":
			_plate = PressurePlate.new()
			_plate.cell = cell
			_plate.floor_ref = _floor
			_plate.position = Iso.to_screen(Vector2(cell))
			_plate.elev = _lift_at(cell)
			_actors.add_child(_plate)
			_plate.toggled.connect(_on_plate)
		"G":
			_gate = StoryGate.new()
			_gate.axis = Vector2(0, 1)
			_gate.length = 3.0
			_gate.label = "COLD"
			_gate.position = Iso.to_screen(Vector2(cell))
			_actors.add_child(_gate)
		"C":
			_crystals.append(_add_prop(Prop.Kind.CRYSTAL, cell))
		"B":
			_floor.blockers[cell] = true
			var b := IsoBlock.new()
			b.position = Iso.to_screen(Vector2(cell))
			b.tint = Color("8a5a35")
			b.height = 30.0
			_actors.add_child(b)
		"M":
			_table = _add_prop(Prop.Kind.TABLE, cell)
			_table.table_len = TABLE_LEN
			for i in TABLE_LEN:
				_floor.blockers[cell + Vector2i(i - 2, 0)] = true
		"h":
			var chair := _add_prop(Prop.Kind.CHAIR, cell, false, 0 if cell.y < TABLE_CELL.y else 1)
			_chairs.append(chair)
		"Y":
			_maud_fig = _add_prop(Prop.Kind.FIGURE, cell, false, 3)
			_register(_maud_fig, func(): return "Sit with Maud" if (_finale_done and not _leaving) else "", _sit_with_maud, 100.0)
		"g", "x":
			_enemy_spawns.append({"kind": Enemy.Kind.BARE if ch == "g" else Enemy.Kind.MITE, "cell": cell})
		_:
			return false
	return true

func _level_ready() -> void:
	for cell: Vector2i in _floor.cells.keys():
		if cell.y <= 9 and cell.x >= 28 and _floor.cells[cell] == "w" and not _floor.stairs.has(cell):
			_arena_cells.append(cell)
	_arena_min = Vector2i(999, 999)
	_arena_max = Vector2i(-999, -999)
	for c in _arena_cells:
		_arena_min = Vector2i(mini(_arena_min.x, c.x), mini(_arena_min.y, c.y))
		_arena_max = Vector2i(maxi(_arena_max.x, c.x), maxi(_arena_max.y, c.y))
	for sp in _enemy_spawns:
		_add_enemy(sp["kind"], sp["cell"])
	_bread.changed.connect(_on_bread)
	_salt.slid.connect(func(_b): _hud.narrate(Story.MAUD_SLID, false, 4.0); Telemetry.log_event("puzzle", {"p": "salt_slid"}))
	_dough.burned.connect(_on_dough_burned)
	_dough.ready_to_use.connect(func(_b): _hud.narrate(Story.MAUD_DOUGH_READY, false, 3.0); Telemetry.log_event("puzzle", {"p": "dough_ready"}))
	_hud.set_region("The Empty Table")
	_hud.set_objective(Story.MAUD_OBJECTIVES[0])
	await get_tree().create_timer(1.6).timeout
	GameState.set_flag("format_mark")
	_hud.show_toolbar(true)
	_busy = true
	await _say(Story.maud_format_grant())
	await _hud.tutorial("format")
	_busy = false
	_hud.narrate(Story.MAUD_INTRO, false, 4.0)

# --- Frame loop -------------------------------------------------------------------------------------------
func _room_for(cell: Vector2i) -> int:
	if cell.x <= 13:
		return 0
	if cell.x <= 30 and cell.y >= 10:
		return 1
	if cell.y <= 9:
		return 3
	return 2

func _level_process(delta: float) -> void:
	var cell := _floor.cell_at(_player.position)
	var room := _room_for(cell)
	if not _room_seen.has(room):
		_room_seen[room] = true
		_on_room(room)
	if room == 3 and not _boss_started and not GameState.in_dialogue:
		_start_boss()
	if _boss_started and not _finale_done:
		_tick_boss(delta)
	_tick_wipes(delta)

func _on_room(room: int) -> void:
	match room:
		1:
			_hud.set_objective(Story.MAUD_OBJECTIVES[1])
		2:
			_hud.set_objective(Story.MAUD_OBJECTIVES[2])
			if not _dough_hinted:
				_dough_hinted = true
				_hud.narrate(Story.MAUD_DOUGH_HINT, false, 5.0)
		3:
			pass

func _room_name(cell: Vector2i) -> String:
	return ["The Pantry", "The Kitchen", "The Cellar", "The Hall"][_room_for(cell)]

func _checkpoint_for(cell: Vector2i) -> Vector2:
	match _room_for(cell):
		0: return _map_start
		1: return Iso.to_screen(Vector2(14, 16))
		2: return Iso.to_screen(Vector2(31, 12))
		_: return Iso.to_screen(Vector2(38, 9))

# --- Puzzles -------------------------------------------------------------------------------------------------
func _on_bread(b: TextBlock) -> void:
	if b.underline:
		_hud.narrate(Story.MAUD_BREAD_DONE, false, 4.0)
		Telemetry.log_event("puzzle", {"p": "bread_underlined"})

func _on_plate(on: bool) -> void:
	if on:
		_gate.open()
		_hud.narrate(Story.MAUD_PLATE, false, 3.5)
		Telemetry.log_event("puzzle", {"p": "plate_pressed"})

func _on_dough_burned(_b: TextBlock) -> void:
	_hud.narrate(Story.MAUD_DOUGH_BURNED, false, 4.0)
	Telemetry.log_event("puzzle", {"p": "dough_burned"})

# --- The Empty Table (boss) ------------------------------------------------------------------------------------
func _start_boss() -> void:
	_boss_started = true
	_busy = true
	Music.play("boss_empty_table")
	await cinematic([{"at": _table.position, "zoom": ZOOM * 1.15, "pan": 1.8, "hold": 0.5, "lines": Story.maud_boss_intro()}])
	_hud.set_objective(Story.MAUD_OBJECTIVES[3] % 0)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "start"})
	_wave_cd = 9.0 if not GameState.is_story() else 13.0
	_guest_timer = 0.5
	_busy = false

func _edge_cell() -> Vector2i:
	var pool: Array[Vector2i] = []
	for c in _arena_cells:
		if c.x <= _arena_min.x + 1 or c.x >= _arena_max.x - 1 or c.y >= _arena_max.y - 1:
			pool.append(c)
	return pool[randi() % pool.size()]

func _spawn_guest() -> void:
	var g := Guest.new()
	g.floor_ref = _floor
	g.target = _player
	g.walkable = _arena_cells
	g.chairs = _chairs
	g.variant = _guests.size()
	g.position = Iso.to_screen(Vector2(_edge_cell()))
	g.elev = _lift_at(Vector2i(30, 5))
	_actors.add_child(g)
	_guests.append(g)
	g.seated.connect(_on_seated)
	g.unseated.connect(func(_g): _seated = maxi(_seated - 1, 0); _hud.set_objective(Story.MAUD_OBJECTIVES[3] % _seated))

func _on_seated(_g: Guest) -> void:
	_seated += 1
	_hud.set_objective(Story.MAUD_OBJECTIVES[3] % _seated)
	_hud.narrate(Story.MAUD_SEATED[mini(_seated, GUESTS) - 1], false, 3.0)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "seated", "n": _seated})
	if _seated >= GUESTS and not _reckoning:
		_begin_reckoning()

var _reckoning := false
var _cold: ColdShoulder

## Every chair is filled: the cold stops being weather and turns up as a figure you can fight.
func _begin_reckoning() -> void:
	_reckoning = true
	_busy = true
	_wave = {}
	for c in _arena_cells:
		_floor.marks.erase(c)
	await get_tree().create_timer(1.2).timeout
	await cinematic([{"at": _table.position + Vector2(0, 40), "zoom": ZOOM * 1.2, "pan": 1.2, "hold": 0.6, "lines": Story.maud_reckoning()}])
	_cold = ColdShoulder.new()
	_cold.target = _player
	_cold.floor_ref = _floor
	var mid := Vector2i((_arena_min.x + _arena_max.x) / 2, (_arena_min.y + _arena_max.y) / 2 + 1)
	_cold.position = Iso.to_screen(Vector2(mid))
	_cold.elev = _lift_at(mid)
	_cold.slam_hit = _on_slam
	_actors.add_child(_cold)
	_cold.damaged.connect(func(frac: float): _hud.set_boss("The Cold Shoulder", frac))
	_cold.defeated.connect(_on_cold_beaten)
	_cold.begin()
	Music.play("boss_cold_shoulder", "boss_empty_table")
	_wave_cd = 12.0
	_hud.set_objective(Story.MAUD_FIGHT_OBJECTIVE)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "reckoning"})
	_busy = false

func _on_slam(at: Vector2) -> void:
	camera_shake(0.35, 5.0)
	if _dist(at, _player.position) < _cold.slam_radius() * 1.0 and not _player.is_falling:
		_player.take_damage(14.0 * GameState.enemy_dmg_mult(), true, "cold_slam")

func _on_cold_beaten() -> void:
	_hud.set_boss("", 0.0)
	Music.play("victory", "memory_maud", 0.8)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "defeated"})
	camera_shake(0.7, 9.0)
	_finale()

func _tick_boss(delta: float) -> void:
	if _reckoning and is_instance_valid(_cold):
		_cold.warmed = _player.lantern_on and _dist(_cold.position, _player.position) < 320.0
	if _guests.size() < GUESTS:
		_guest_timer -= delta
		if _guest_timer <= 0.0:
			_guest_timer = 3.5
			_spawn_guest()
	_table.warmth = lerpf(_table.warmth, float(_seated) / GUESTS, 1.0 - exp(-2.0 * delta))
	_tick_wave(delta)

# The Clearing: a telegraphed cold that sweeps the hall. Heavy (bold) words shelter what is behind them.
func _line_index(c: Vector2i, dir: Vector2i) -> int:
	if dir.x == 1: return c.x - _arena_min.x
	if dir.x == -1: return _arena_max.x - c.x
	if dir.y == 1: return c.y - _arena_min.y
	return _arena_max.y - c.y

func _wave_dim(dir: Vector2i) -> int:
	return (_arena_max.x - _arena_min.x + 1) if dir.x != 0 else (_arena_max.y - _arena_min.y + 1)

func _start_wave() -> void:
	var names := WAVE_DIRS.keys()
	var wname: String = names[randi() % names.size()]
	var dir: Vector2i = WAVE_DIRS[wname]
	_wave = {"name": wname, "dir": dir, "t": 0.0, "phase": "warn", "line": -1}
	for c in _arena_cells:
		if _line_index(c, dir) == 0:
			_floor.marks[c] = {"kind": "crack", "t": 0.0}
	_hud.narrate("The cold comes from the %s. Get behind something heavy." % wname, false, 3.0)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "wave", "from": wname})

func _tick_wave(delta: float) -> void:
	if _wave.is_empty():
		_wave_cd -= delta
		if _wave_cd <= 0.0:
			_start_wave()
		return
	_wave["t"] = float(_wave["t"]) + delta
	var dir: Vector2i = _wave["dir"]
	if _wave["phase"] == "warn":
		if _wave["t"] >= 2.6:
			_wave["phase"] = "sweep"
			_wave["t"] = 0.0
			for c in _arena_cells:
				if _floor.marks.has(c) and _floor.marks[c]["kind"] == "crack":
					_floor.marks.erase(c)
	else:
		var dim := _wave_dim(dir)
		var line := mini(int(float(_wave["t"]) / 2.4 * dim), dim - 1)
		while int(_wave["line"]) < line:
			_wave["line"] = int(_wave["line"]) + 1
			_apply_line(int(_wave["line"]), dir)
		if _wave["t"] >= 2.8:
			_wave = {}
			_wave_cd = 11.0 if not GameState.is_story() else 15.0

func _shielded(c: Vector2i, dir: Vector2i) -> bool:
	for k in range(1, 4):
		var b = _floor.block_cells.get(c - dir * k)
		if b is TextBlock and b.bold and not b._sliding:
			return true
	return false

func _apply_line(idx: int, dir: Vector2i) -> void:
	for c in _arena_cells:
		if _line_index(c, dir) != idx:
			continue
		_floor.marks[c] = {"kind": "wipe", "t": 0.0}
		_wipes[c] = 0.35
		var safe := _shielded(c, dir)
		if _floor.cell_at(_player.position) == c and not safe and not _player.is_falling:
			_player.take_damage(14.0 * GameState.enemy_dmg_mult(), true, "cold_wave")
		for g in _guests:
			if _floor.cell_at(g.position) != c or safe or g.state == "erased":
				continue
			if g.state == "seated":
				g.unseat()
			else:
				g.erase(Iso.to_screen(Vector2(_edge_cell())))

func _tick_wipes(delta: float) -> void:
	for c in _wipes.keys():
		_wipes[c] = float(_wipes[c]) - delta
		if _wipes[c] <= 0.0:
			if _floor.marks.has(c) and _floor.marks[c]["kind"] == "wipe":
				_floor.marks.erase(c)
			_wipes.erase(c)

func _finale() -> void:
	if _finale_done:
		return
	_finale_done = true
	_busy = true
	_wave = {}
	for c in _arena_cells:
		_floor.marks.erase(c)
	Telemetry.log_event("boss", {"boss": "empty_table", "what": "won"})
	await get_tree().create_timer(1.2).timeout
	_table.warmth = 1.0
	await cinematic([{"at": _table.position, "zoom": ZOOM * 1.25, "pan": 1.4, "hold": 1.2, "lines": Story.maud_finale()}])
	_hud.set_objective(Story.MAUD_OBJECTIVES[4])
	_busy = false

func _handle_cue(cue: String) -> void:
	if cue == "dissolve_table":
		camera_shake(0.5, 4.0)

func _sit_with_maud() -> void:
	await cinematic([{"at": _maud_fig.position, "zoom": ZOOM * 1.45, "pan": 1.3, "hold": 1.2, "lines": Story.maud_resolution()}])
	GameState.set_flag("maud_memory_done")
	award_boss_drops("maud")
	GameState.add_mnemosynth(40)
	_hud.set_objective("")
	await get_tree().create_timer(3.0).timeout
	_leave()

func _on_death_reset() -> void:
	if is_instance_valid(_cold):
		_cold.reset_fight()
	_wave = {}
	_wave_cd = 8.0
	for c in _arena_cells:
		_floor.marks.erase(c)
	_wipes.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _room_for(_floor.cell_at(e.position)) == _room_for(_floor.cell_at(_player.position)):
			e.queue_free()
	for sp in _enemy_spawns:
		if _room_for(sp["cell"]) == _room_for(_floor.cell_at(_player.position)) and _dist(Iso.to_screen(Vector2(sp["cell"])), _player.position) > 380.0:
			_add_enemy(sp["kind"], sp["cell"])

# --- Leaving -----------------------------------------------------------------------------------------------------
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.spawn_cell = RETURN_CELL
	Transition.go(OVERWORLD, Palette.GOLD.lightened(0.7))
	await get_tree().create_timer(30.0).timeout
