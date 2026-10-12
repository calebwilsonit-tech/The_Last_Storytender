class_name TrialPrizes
extends RefCounted
## What a vault pays out. The harder the trial (tier 1 to 4), the better the pool.
## A vault always rolls the same prize (seeded by its cell); unique gear you already own is
## rerolled so a vault never hands over a duplicate piece.

const POOLS := {
	1: ["item:ink_vial:2", "item:eraser_crumbs:3", "mnemo:25", "item:warm_loaf:1"],
	2: ["item:warm_loaf:2", "mnemo:45", "item:highlighter:1", "item:margin_note:1", "item:index_tab:1", "item:paperback_binding:1", "item:lantern_oil:2", "item:sticky_note:2"],
	3: ["item:red_pen:1", "item:footnote:1", "item:leatherbound_binding:1", "mnemo:80", "item:ink_flask:2", "item:sticky_note:3"],
	4: ["item:gilded_binding:1", "item:bookmark_charm:1", "item:first_edition:1", "mnemo:140", "item:ink_flask:3"],
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
			if t in ["binding", "amulet"] and GameState.inventory.has(parts[1]):
				continue
		return r
	return "mnemo:%d" % (20 * tier)
