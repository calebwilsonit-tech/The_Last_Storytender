extends Node
## Global story state (autoload as GameState).

signal mnemosynth_changed(value: int)
signal restoration_finished

const RESTORE_DURATION := 7.0
const WAVE_SOFT_EDGE := 190.0     # px of ink "bleeding in" at the wave front

var mnemosynth := 0
var ink := 100.0                  # carried between scenes
var spawn_cell := Vector2i(-1, -1)  # where the overworld should place the player (-1 = map start)
var flags: Dictionary = {}
var in_dialogue := false

var wave_origin := Vector2.ZERO
var wave_radius := 0.0            # px; 0 = ghost town, >= FULL = restored
var town_restored := false

const FULL := 100000.0

func has_flag(f: String) -> bool:
	return flags.has(f)

func set_flag(f: String) -> void:
	flags[f] = true

func add_mnemosynth(n: int) -> void:
	mnemosynth += n
	mnemosynth_changed.emit(mnemosynth)

## 0..1 how "written" the world is at a position (iso-corrected circular wave).
func restored_at(pos: Vector2) -> float:
	if wave_radius >= FULL:
		return 1.0
	if wave_radius <= 0.0:
		return 0.0
	var d := pos - wave_origin
	d.y *= 2.0
	return clampf((wave_radius - d.length()) / WAVE_SOFT_EDGE, 0.0, 1.0)

func start_restoration(origin: Vector2) -> void:
	wave_origin = origin
	wave_radius = 1.0
	var tw := create_tween()
	tw.tween_property(self, "wave_radius", 2600.0, RESTORE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	wave_radius = FULL
	town_restored = true
	restoration_finished.emit()
