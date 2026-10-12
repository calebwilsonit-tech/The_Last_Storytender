extends Node
## Playtest log (autoload as Telemetry). Records what actually happens (damage by
## source, deaths per room, time per scene, boss events, item use) and writes it
## to a JSON file you can send back. Press F10 in game to save and show the path.

const DIR := "user://playtest"
var enabled := true
var events: Array[Dictionary] = []
var scene_name := ""
var room_name := ""
var _session := ""
var _t0 := 0.0
var _scene_start := 0.0
var _scene_time: Dictionary = {}
var _flush_t := 0.0

func _ready() -> void:
	# Tests and headless runs set this so they don't write logs.
	if OS.get_environment("STORYTENDER_NOSAVE") != "":
		enabled = false
	_session = Time.get_datetime_string_from_system().replace(":", "-")
	_t0 = Time.get_ticks_msec() / 1000.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func log_event(kind: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var e := {"t": snappedf(_now(), 0.1), "e": kind, "scene": scene_name, "room": room_name}
	e.merge(data)
	events.append(e)

func enter_scene(name: String) -> void:
	if not enabled:
		return
	_close_scene()
	scene_name = name
	room_name = ""
	_scene_start = _now()
	log_event("scene", {"difficulty": GameState.difficulty})

func enter_room(name: String) -> void:
	if room_name == name:
		return
	room_name = name
	log_event("room")

func _close_scene() -> void:
	if scene_name != "":
		_scene_time[scene_name] = float(_scene_time.get(scene_name, 0.0)) + (_now() - _scene_start)

var _perf: Dictionary = {}       # "scene / room" -> frame-time stats
var _perf_t := 0.0

## Frame-time stats per place, so a report shows where the game runs badly (and in which art style).
func _sample_perf(delta: float) -> void:
	var key := "%s / %s [%s]" % [scene_name, room_name, Settings.art_style]
	var p: Dictionary = _perf.get(key, {"secs": 0.0, "fps_sum": 0.0, "fps_min": 9999.0, "slow_secs": 0, "spikes": 0, "worst_ms": 0.0, "draw_calls": 0.0, "nodes": 0.0, "n": 0})
	var ms := delta * 1000.0
	p["worst_ms"] = maxf(float(p["worst_ms"]), ms)
	if ms > 60.0:
		p["spikes"] = int(p["spikes"]) + 1
	_perf_t += delta
	if _perf_t >= 1.0:
		_perf_t = 0.0
		var fps := Engine.get_frames_per_second()
		var dc := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var nodes := float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		p["n"] = int(p["n"]) + 1
		p["fps_sum"] = float(p["fps_sum"]) + fps
		p["fps_min"] = minf(float(p["fps_min"]), fps)
		p["draw_calls"] = float(p["draw_calls"]) + dc
		p["nodes"] = float(p["nodes"]) + nodes
		if fps < 30.0:
			p["slow_secs"] = int(p["slow_secs"]) + 1
			if events.size() < 4000:
				log_event("perf_dip", {"fps": fps, "draw_calls": dc, "nodes": nodes, "art": Settings.art_style})
	_perf[key] = p

func perf_summary() -> Dictionary:
	var out := {}
	for k in _perf:
		var p: Dictionary = _perf[k]
		var n := maxi(int(p["n"]), 1)
		out[k] = {"seconds": int(p["n"]), "avg_fps": snappedf(float(p["fps_sum"]) / n, 0.1), "min_fps": snappedf(float(p["fps_min"]), 0.1),
			"seconds_under_30fps": p["slow_secs"], "frame_spikes_over_60ms": p["spikes"], "worst_frame_ms": snappedf(float(p["worst_ms"]), 0.1),
			"avg_draw_calls": snappedf(float(p["draw_calls"]) / n, 1.0), "avg_nodes": snappedf(float(p["nodes"]) / n, 1.0)}
	return out

func _process(delta: float) -> void:
	if not enabled:
		return
	_sample_perf(delta)
	_flush_t += delta
	if _flush_t > 20.0:
		_flush_t = 0.0
		flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()

## Aggregate numbers: where players die, what hurts, how long each place takes.
func summary() -> Dictionary:
	var dmg := {}
	var hits := {}
	var deaths := {}
	var falls := 0
	var items := {}
	var bosses := []
	for e in events:
		match e["e"]:
			"damage":
				var src: String = e.get("src", "?")
				dmg[src] = float(dmg.get(src, 0.0)) + float(e.get("amt", 0.0))
				hits[src] = int(hits.get(src, 0)) + 1
			"death":
				var key := "%s / %s" % [e["scene"], e["room"]]
				deaths[key] = int(deaths.get(key, 0)) + 1
			"fall":
				falls += 1
			"item":
				items[e.get("id", "?")] = int(items.get(e.get("id", "?"), 0)) + 1
			"boss":
				bosses.append(e)
	var times := _scene_time.duplicate()
	if scene_name != "":
		times[scene_name] = float(times.get(scene_name, 0.0)) + (_now() - _scene_start)
	for k in times:
		times[k] = snappedf(float(times[k]) / 60.0, 0.1)
	for k in dmg:
		dmg[k] = snappedf(float(dmg[k]), 0.1)
	return {
		"session": _session, "minutes_total": snappedf(_now() / 60.0, 0.1), "difficulty": GameState.difficulty,
		"minutes_by_scene": times, "damage_by_source": dmg, "hits_by_source": hits,
		"deaths_by_room": deaths, "falls": falls, "items_used": items, "boss_events": bosses, "performance": perf_summary(),
	}

func report_path() -> String:
	return ProjectSettings.globalize_path("%s/playtest_%s.json" % [DIR, _session])

func flush() -> void:
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open("%s/playtest_%s.json" % [DIR, _session], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"summary": summary(), "events": events}, "  "))
