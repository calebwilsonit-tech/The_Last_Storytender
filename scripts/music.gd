extends Node
## The music player (autoload as Music). It is built and wired but ships EMPTY: drop a file named
## after a slot into res://assets/music/ (ogg preferred, mp3 or wav also work) and that slot starts
## playing. Slots with no file are simply silent. Tracks loop, crossfade, dip under dialogue and
## cutscenes, and obey Settings > Music volume. See assets/music/README.md for the slot list.

const DIR := "res://assets/music/"
const EXTS := ["ogg", "mp3", "wav"]
const BUS := "Music"
const DUCK_DB := -7.0

## Every slot the game asks for (the file is <slot>.ogg etc.).
const SLOTS := {
	"title": "Title screen",
	"storybook": "The New Game storybook",
	"overworld": "The Prologue overworld (default for every region)",
	"region_<id>": "Optional per-region track, e.g. region_o; falls back to overworld",
	"index": "The Index hub (workbench, stall, levelling) at a lantern post",
	"memory_forge": "Garrick's memory: The Blacksmith's Regret",
	"memory_pip": "Pip's memory: The Last Page",
	"memory_maud": "Maud's memory: The Empty Table",
	"editor_scissor": "The Scissor-Man's arena (before the fight)",
	"boss_critic": "The Critic, the remembering half",
	"boss_critic_reckoning": "The Critic's Reckoning (falls back to boss_critic)",
	"boss_spoiler": "The Spoiler, the rewriting half",
	"boss_spoiler_reckoning": "The Spoiler's Reckoning (falls back to boss_spoiler)",
	"boss_empty_table": "The Empty Table, seating the guests",
	"boss_cold_shoulder": "The Cold Shoulder (Maud's Reckoning)",
	"boss_scissor": "The Scissor-Man fight",
	"victory": "A short sting after a boss or a restoration (plays once)",
}

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _slot := ""
var _stack: Array[String] = []
var _duck := 0.0               # 0 = full, 1 = ducked
var _fade_tw: Tween
var _last_req := ""            # the last (slot|fallback) asked for, so per-frame callers cost nothing

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	_a = _make_player()
	_b = _make_player()
	_active = _a
	apply_volume()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	p.volume_db = -80.0
	add_child(p)
	return p

func apply_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Settings.music_volume, 0.0001)) + _duck * DUCK_DB)

func _process(delta: float) -> void:
	var want := 1.0 if (GameState.in_dialogue) else 0.0
	_duck = move_toward(_duck, want, delta * 2.0)
	apply_volume()

func current() -> String:
	return _slot

## Which file (if any) backs this slot.
func path_for(slot: String) -> String:
	for ext in EXTS:
		var p := "%s%s.%s" % [DIR, slot, ext]
		if ResourceLoader.exists(p):
			return p
	return ""

## Starts a slot with a crossfade. If its file is missing, `fallback` is tried; if that is missing too
## the music fades out to silence.
func play(slot: String, fallback: String = "", fade: float = 1.6) -> void:
	var req := slot + "|" + fallback
	if req == _last_req:
		return
	_last_req = req
	var use := slot
	var path := path_for(slot)
	if path == "" and fallback != "":
		use = fallback
		path = path_for(fallback)
	if use == _slot and path != "":
		return
	if path == "":
		_slot = ""
		_fade_to(null, fade)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = slot != "victory"
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if slot != "victory":
			var bytes := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / bytes
	_slot = use
	_fade_to(stream, fade)

## Plays a slot but remembers what was playing, so pop() can bring it back (the Index uses this).
func push(slot: String, fallback: String = "") -> void:
	_stack.append(_slot)
	if path_for(slot) != "" or (fallback != "" and path_for(fallback) != ""):
		play(slot, fallback)      # no file for this slot: keep whatever is already playing

func pop() -> void:
	if _stack.is_empty():
		return
	var prev: String = _stack.pop_back()
	_last_req = ""
	if prev == "":
		_fade_to(null, 1.2)
		_slot = ""
	else:
		play(prev)

func stop(fade: float = 1.2) -> void:
	_last_req = ""
	_slot = ""
	_fade_to(null, fade)

func _fade_to(stream: AudioStream, fade: float) -> void:
	if _fade_tw:
		_fade_tw.kill()
	var old := _active
	var new_player := _b if _active == _a else _a
	_fade_tw = create_tween().set_parallel(true)
	if stream != null:
		new_player.stream = stream
		new_player.volume_db = -80.0
		new_player.play()
		_fade_tw.tween_property(new_player, "volume_db", 0.0, fade)
		_active = new_player
	_fade_tw.tween_property(old, "volume_db", -80.0, fade)
	_fade_tw.chain().tween_callback(func():
		if old != _active:
			old.stop())
