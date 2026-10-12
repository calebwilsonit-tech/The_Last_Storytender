class_name TrialPrizes
extends RefCounted
## What a vault pays out. The harder the trial (tier 1 to 4), the better the pool.
## A vault always rolls the same prize (seeded by its cell); unique gear you already own is
## rerolled so a vault never hands over a duplicate piece.

const POOLS := {
	1: ["item:ink_vial:2", "item:eraser_crumbs:3", "mnemo:25", "item:warm_loaf:1", "item:herbal_tea:2", "item:honey_biscuit:3",
		"item:paper_scrap:4", "item:ink_blot:3", "item:loose_thread:3", "item:paper_clip:1", "item:rubber_band:1", "item:cloth_binding:1"],
	2: ["item:warm_loaf:2", "mnemo:45", "item:highlighter:1", "item:margin_note:1", "item:index_tab:1", "item:paperback_binding:1", "item:lantern_oil:2",
		"item:sticky_note:2", "item:clarity_tonic:1", "item:ghost_pepper_ink:2", "item:tin_bell:1", "item:reading_glasses:1", "item:bookworm_charm:1",
		"item:margin_doodle:1", "item:dust_jacket:1", "item:clover_press:2", "item:gold_leaf:2", "item:wax_seal:2", "item:quill_feather:2", "item:reader_digest:1"],
	3: ["item:red_pen:1", "item:footnote:1", "item:leatherbound_binding:1", "mnemo:80", "item:ink_flask:2", "item:sticky_note:3",
		"item:cartographer_compass:1", "item:silver_ribbon:1", "item:lamplighter_match:1", "item:ghostwriter_glove:1", "item:library_binding:1",
		"item:memory_jar:1", "item:silver_thread:3", "item:marginalia_dust:2", "item:void_pearl:1"],
	4: ["item:gilded_binding:1", "item:bookmark_charm:1", "item:first_edition:1", "mnemo:140", "item:ink_flask:3",
		"item:hourglass_of_drafts:1", "item:censors_monocle:1", "item:midnight_inkwell:1", "item:vellum_binding:1", "item:phoenix_draught:1",
		"item:time_in_a_bottle:1", "item:phoenix_ember:1", "item:blank_page:1", "item:illuminated_binding:1", "item:authors_pen:1",
		"item:eternal_bookmark:1", "item:golden_ratio:1", "item:unwritten_word:1"],
}

static func roll(tier: int, cell: Vector2i) -> String:
	var pool: Array = (POOLS[clampi(tier, 1, 4)] as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 31337 + cell.y * 7 + tier
	var start := rng.randi() % pool.size()
	for k in pool.size():
		var r: String = pool[(start + k) % pool.size()]
		var parts := r.split(":")
		if parts[0] == "item":
			var t: String = ItemDB.info(parts[1]).get("type", "")
			if (t in ["binding", "amulet"] or ItemDB.rarity(parts[1]) == "legendary") and GameState.inventory.has(parts[1]):
				continue
		return r
	return "mnemo:%d" % (20 * tier)
