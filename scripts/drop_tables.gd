class_name DropTables
extends RefCounted
## Loot tables. Each entry is [item id, chance in percent, min count, max count] and is rolled on
## its own, so one kill can drop several things (or nothing). Chances run from about 1% (artifacts)
## to 50% (common crumbs). Normal difficulty pays out more than Story, bosses most of all, and a
## Lucky Clover (fx "luck") nudges everything up. Chances are capped at 100%.

const MOBS := {
	"bare": [["paper_scrap", 45, 1, 2], ["pencil_shaving", 30, 1, 1], ["eraser_crumbs", 25, 1, 1], ["ink_blot", 15, 1, 1],
		["honey_biscuit", 8, 1, 1], ["ink_vial", 5, 1, 1], ["paper_clip", 2, 1, 1], ["clover_press", 1, 1, 1]],
	"mite": [["paper_scrap", 40, 1, 2], ["loose_thread", 30, 1, 1], ["glue_stub", 20, 1, 1], ["void_ink", 15, 1, 1],
		["herbal_tea", 6, 1, 1], ["rubber_band", 2, 1, 1], ["clover_press", 1, 1, 1]],
	"slug": [["ink_blot", 50, 1, 2], ["glue_stub", 30, 1, 1], ["void_ink", 20, 1, 1], ["clover_press", 6, 1, 1],
		["clarity_tonic", 4, 1, 1], ["bookworm_charm", 1, 1, 1]],
	"dangler": [["loose_thread", 40, 1, 2], ["quill_feather", 14, 1, 1], ["wax_seal", 10, 1, 1], ["eraser_crumbs", 20, 1, 1],
		["ghost_pepper_ink", 5, 1, 1], ["tin_bell", 2, 1, 1], ["gold_leaf", 1, 1, 1]],
	"censor": [["wax_seal", 30, 1, 1], ["ink_vial", 25, 1, 1], ["silver_thread", 12, 1, 1], ["void_pearl", 5, 1, 1],
		["reader_digest", 4, 1, 1], ["silver_ribbon", 2, 1, 1], ["censors_monocle", 1, 1, 1]],
	"ellipsis": [["marginalia_dust", 25, 1, 1], ["silver_thread", 20, 1, 2], ["void_pearl", 10, 1, 1], ["memory_jar", 4, 1, 1],
		["time_in_a_bottle", 2, 1, 1], ["hourglass_of_drafts", 1, 1, 1], ["phoenix_ember", 1, 1, 1]],
}

## Bosses: guaranteed first-win rewards live in the memory scripts; these tables are extra and
## are rolled every time the boss is beaten.
const BOSSES := {
	"pip": [["ink_flask", 100, 1, 2], ["gold_leaf", 60, 1, 2], ["margin_doodle", 35, 1, 1], ["memory_jar", 20, 1, 1],
		["reading_glasses", 15, 1, 1], ["clover_press", 40, 1, 2], ["hourglass_of_drafts", 4, 1, 1]],
	"maud": [["warm_loaf", 100, 1, 2], ["quill_feather", 60, 1, 2], ["tin_bell", 30, 1, 1], ["clarity_tonic", 25, 1, 1],
		["silver_ribbon", 12, 1, 1], ["cartographer_compass", 8, 1, 1], ["midnight_inkwell", 3, 1, 1]],
	"forge": [["phoenix_ember", 25, 1, 1], ["silver_thread", 80, 1, 3], ["lamplighter_match", 18, 1, 1], ["library_binding", 15, 1, 1],
		["ghostwriter_glove", 8, 1, 1], ["vellum_binding", 4, 1, 1], ["authors_pen", 1, 1, 1]],
	"scissor": [["wax_seal", 90, 1, 3], ["void_pearl", 45, 1, 2], ["silver_ribbon", 30, 1, 1], ["ghostwriter_glove", 20, 1, 1],
		["censors_monocle", 15, 1, 1], ["phoenix_draught", 12, 1, 1], ["blank_page", 6, 1, 1],
		["eternal_bookmark", 2, 1, 1], ["unwritten_word", 1, 1, 1]],
}

const MOB_DIFFICULTY := {"story": 1.0, "normal": 1.2}
const BOSS_DIFFICULTY := {"story": 1.0, "normal": 1.75}

static func _mult(boss: bool) -> float:
	var table: Dictionary = BOSS_DIFFICULTY if boss else MOB_DIFFICULTY
	var m: float = table["story" if GameState.is_story() else "normal"]
	return m * (1.0 + GameState.equipped_stat("luck"))

## The effective chance (percent) of one entry right now.
static func chance(entry: Array, boss: bool) -> float:
	return minf(float(entry[1]) * _mult(boss), 100.0)

## Rolls a table. `rng` is optional so tests can be deterministic. Returns [[id, count], ...].
static func roll(table: Array, boss: bool = false, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	for e: Array in table:
		var r := rng.randf() * 100.0 if rng else randf() * 100.0
		if r < chance(e, boss):
			var lo := int(e[2])
			var hi := int(e[3])
			var n := lo if hi <= lo else (rng.randi_range(lo, hi) if rng else randi_range(lo, hi))
			out.append([e[0], n])
	return out

static func roll_mob(kind_name: String, rng: RandomNumberGenerator = null) -> Array:
	return roll(MOBS.get(kind_name, []), false, rng)

static func roll_boss(id: String, rng: RandomNumberGenerator = null) -> Array:
	return roll(BOSSES.get(id, []), true, rng)
