class_name ItemCatalog
extends RefCounted
## The big list: crafting materials, extra consumables, bindings and artifacts of every rarity.
## ItemDB.info() looks here after its own table. Fields: name, type, rarity, price (what a shop
## would ask, in Mnemosynth), desc/flavor, optional fx (equipment stats), use (consumable effect),
## icon {s: shape, c: colour, c2: second colour}. Rarity: common, uncommon, rare, epic, legendary.
## Where each one turns up is in SOURCES (chests, vaults, enemy drops, a later shop).

const ITEMS := {
	# --- Crafting materials -------------------------------------------------------------------------
	"paper_scrap": {"name": "Paper Scrap", "type": "material", "rarity": "common", "price": 4,
		"desc": "A torn corner of something that used to matter.", "flavor": "Every book is made of these, eventually.",
		"icon": {"s": "scrap", "c": "f1e7c9", "c2": "c9b98a"}},
	"ink_blot": {"name": "Ink Blot", "type": "material", "rarity": "common", "price": 5,
		"desc": "A droplet of ink that never dried.", "flavor": "It looks a little like a face. Do not look too long.",
		"icon": {"s": "drop", "c": "26324a", "c2": "56688a"}},
	"pencil_shaving": {"name": "Pencil Shaving", "type": "material", "rarity": "common", "price": 3,
		"desc": "A curl of cedar that still smells like a first draft.", "flavor": "Sharpened, then forgotten.",
		"icon": {"s": "curl", "c": "d9a65a", "c2": "8a5a28"}},
	"loose_thread": {"name": "Loose Thread", "type": "material", "rarity": "common", "price": 4,
		"desc": "Pull it and a whole sentence unravels. Useful for binding.", "flavor": "Do not pull it. Everyone pulls it.",
		"icon": {"s": "spool", "c": "c85a5a", "c2": "f1e7c9"}},
	"glue_stub": {"name": "Glue Stub", "type": "material", "rarity": "common", "price": 5,
		"desc": "The dried end of a paste stick. Holds things together, mostly.", "flavor": "The sticky truth.",
		"icon": {"s": "tube", "c": "e8e0b8", "c2": "8aa0c8"}},
	"clover_press": {"name": "Pressed Clover", "type": "material", "rarity": "uncommon", "price": 12,
		"desc": "A flat four-leaf clover from between two pages.", "flavor": "Found at page 212. Kept for luck.",
		"icon": {"s": "leaf", "c": "5aa85a", "c2": "2f6a3a"}},
	"gold_leaf": {"name": "Gold Leaf", "type": "material", "rarity": "uncommon", "price": 18,
		"desc": "A whisper-thin sheet of gold for illuminating things.", "flavor": "Do not sneeze.",
		"icon": {"s": "scrap", "c": "f2c24b", "c2": "c9922b"}},
	"wax_seal": {"name": "Wax Seal", "type": "material", "rarity": "uncommon", "price": 15,
		"desc": "A red seal that once closed an important letter.", "flavor": "It was not that important.",
		"icon": {"s": "seal", "c": "b8402f", "c2": "7a2a22"}},
	"quill_feather": {"name": "Quill Feather", "type": "material", "rarity": "uncommon", "price": 16,
		"desc": "A long primary feather, cut for writing.", "flavor": "From a bird that had a lot to say.",
		"icon": {"s": "feather", "c": "f4f0e6", "c2": "9aa0b0"}},
	"silver_thread": {"name": "Silver Thread", "type": "material", "rarity": "rare", "price": 34,
		"desc": "Thread spun from moonlit margins. Strong and bright.", "flavor": "It hums when you hold it.",
		"icon": {"s": "spool", "c": "c8d0e0", "c2": "8a96b0"}},
	"marginalia_dust": {"name": "Marginalia Dust", "type": "material", "rarity": "rare", "price": 40,
		"desc": "Glittering dust brushed from forgotten notes.", "flavor": "Someone wrote 'yes!!' here and no one remembers why.",
		"icon": {"s": "dust", "c": "d8b4f0", "c2": "9a6ac8"}},
	"void_pearl": {"name": "Void Pearl", "type": "material", "rarity": "rare", "price": 48,
		"desc": "A pearl of pure redaction. Cold and perfectly round.", "flavor": "It swallows light, and a little bit of you.",
		"icon": {"s": "gem", "c": "2a2438", "c2": "6a5a8a"}},
	"phoenix_ember": {"name": "Phoenix Ember", "type": "material", "rarity": "epic", "price": 90,
		"desc": "A coal from a story that kept getting rewritten.", "flavor": "It always starts again.",
		"icon": {"s": "flame", "c": "f08a3a", "c2": "d8503a"}},
	"blank_page": {"name": "Perfect Blank Page", "type": "material", "rarity": "epic", "price": 110,
		"desc": "Untouched, unfolded and unafraid. The rarest thing a Storytender can find.", "flavor": "Nothing has ever gone wrong on this page.",
		"icon": {"s": "scrap", "c": "ffffff", "c2": "d8d4c0"}},
	"unwritten_word": {"name": "The Unwritten Word", "type": "material", "rarity": "legendary", "price": 300,
		"desc": "A single word nobody has used yet. Heavier than it looks.", "flavor": "It is on the tip of the world's tongue.",
		"icon": {"s": "star", "c": "f2d88a", "c2": "ffffff"}},

	# --- Consumables ---------------------------------------------------------------------------------
	"herbal_tea": {"name": "Herbal Tea", "type": "consumable", "rarity": "common", "price": 10,
		"desc": "Restores a little ink and a little Lantern.", "flavor": "Steeped in the margins of a quiet chapter.",
		"use": {"ink": 25.0, "lantern": 25.0, "msg": "Warm tea. You feel looked after."},
		"icon": {"s": "cup", "c": "d9a65a", "c2": "f4f0e6"}},
	"honey_biscuit": {"name": "Honey Biscuit", "type": "consumable", "rarity": "common", "price": 8,
		"desc": "Restores some ink.", "flavor": "Pip hid these in every pocket.",
		"use": {"ink": 30.0, "msg": "Sweet, crumbly, and exactly enough."},
		"icon": {"s": "biscuit", "c": "e0b060", "c2": "a8742a"}},
	"clarity_tonic": {"name": "Clarity Tonic", "type": "consumable", "rarity": "uncommon", "price": 28,
		"desc": "Refills the Lantern and restores some ink.", "flavor": "Tastes like clean punctuation.",
		"use": {"ink": 40.0, "lantern": 100.0, "msg": "Everything is suddenly very clear."},
		"icon": {"s": "bottle", "c": "7ac8e8", "c2": "f4f0e6"}},
	"ghost_pepper_ink": {"name": "Ghost Pepper Ink", "type": "consumable", "rarity": "uncommon", "price": 26,
		"desc": "Scares nearby Errors into freezing for a few seconds.", "flavor": "Do not taste it. We mean it.",
		"use": {"sleep": 4.0, "radius": 280.0, "msg": "Nearby Errors forget how to move."},
		"icon": {"s": "bottle", "c": "d8503a", "c2": "f08a3a"}},
	"reader_digest": {"name": "Reader's Digest", "type": "consumable", "rarity": "uncommon", "price": 40,
		"desc": "A pocket summary of your deeds. Grants 12 Renown.", "flavor": "Condensed, with notes.",
		"use": {"renown": 12, "msg": "You skim your own legend and feel a bit taller."},
		"icon": {"s": "book", "c": "5a7ab8", "c2": "f4f0e6"}},
	"memory_jar": {"name": "Memory Jar", "type": "consumable", "rarity": "rare", "price": 55,
		"desc": "Break it open for 60 Mnemosynth.", "flavor": "Someone kept these on a shelf for a rainy day.",
		"use": {"mnemo": 60, "msg": "The jar opens. Someone's afternoon floats out."},
		"icon": {"s": "jar", "c": "f2d88a", "c2": "c9a04a"}},
	"phoenix_draught": {"name": "Phoenix Draught", "type": "consumable", "rarity": "epic", "price": 120,
		"desc": "Restores all ink and fully refuels the Lantern.", "flavor": "Burns going down. Starts you over.",
		"use": {"ink": 999.0, "lantern": 100.0, "msg": "You burn bright and begin again."},
		"icon": {"s": "bottle", "c": "f08a3a", "c2": "f2d88a"}},
	"time_in_a_bottle": {"name": "Time in a Bottle", "type": "consumable", "rarity": "epic", "price": 150,
		"desc": "Freezes every nearby Error for a long breath.", "flavor": "Stopped at 4:17, a Tuesday.",
		"use": {"sleep": 9.0, "radius": 360.0, "msg": "The page holds its breath."},
		"icon": {"s": "bottle", "c": "9a6ac8", "c2": "f4f0e6"}},

	# --- Bindings (armor) -----------------------------------------------------------------------------
	"cloth_binding": {"name": "Cloth Binding", "type": "binding", "rarity": "common", "price": 20,
		"flavor": "Plain, sturdy, quietly hopeful.", "fx": {"armor": 0.06, "speed": 0.05},
		"icon": {"s": "cover", "c": "a8b0c0", "c2": "6a7488"}},
	"dust_jacket": {"name": "Dust Jacket", "type": "binding", "rarity": "uncommon", "price": 45,
		"flavor": "Slides off easily. So do you.", "fx": {"armor": 0.04, "speed": 0.15, "dash_cd": -0.20},
		"icon": {"s": "cover", "c": "7ac8a0", "c2": "3a8a6a"}},
	"library_binding": {"name": "Library Binding", "type": "binding", "rarity": "rare", "price": 90,
		"flavor": "Reinforced to survive a thousand borrowers.", "fx": {"armor": 0.22, "invuln": 0.3},
		"icon": {"s": "cover", "c": "4a6a9a", "c2": "2a3a5a"}},
	"vellum_binding": {"name": "Vellum Binding", "type": "binding", "rarity": "epic", "price": 160,
		"flavor": "Older than the story it holds.", "fx": {"armor": 0.18, "speed": 0.10, "regen": 0.5},
		"icon": {"s": "cover", "c": "e8d8a8", "c2": "b89a58"}},
	"illuminated_binding": {"name": "Illuminated Binding", "type": "binding", "rarity": "legendary", "price": 400,
		"flavor": "Every margin glows with someone's patience.", "fx": {"armor": 0.25, "speed": 0.08, "dmg": 0.15, "regen": 0.6, "invuln": 0.4},
		"icon": {"s": "cover", "c": "f2c24b", "c2": "b8402f"}},

	# --- Artifacts (amulets) ---------------------------------------------------------------------------
	"paper_clip": {"name": "Paper Clip", "type": "amulet", "rarity": "common", "price": 15,
		"flavor": "Holds it all together, barely.", "fx": {"armor": 0.05, "dash_cd": -0.05},
		"icon": {"s": "clip", "c": "b8c0d0", "c2": "6a7488"}},
	"rubber_band": {"name": "Rubber Band", "type": "amulet", "rarity": "common", "price": 15,
		"flavor": "Snaps back. Mostly.", "fx": {"speed": 0.07},
		"icon": {"s": "ring", "c": "d8503a", "c2": "8a2a22"}},
	"tin_bell": {"name": "Tin Bell", "type": "amulet", "rarity": "uncommon", "price": 35,
		"flavor": "Rings when trouble is polite enough to knock.", "fx": {"invuln": 0.35},
		"icon": {"s": "bell", "c": "c8a05a", "c2": "8a6a28"}},
	"reading_glasses": {"name": "Reading Glasses", "type": "amulet", "rarity": "uncommon", "price": 38,
		"flavor": "Now you can see the small print. And the big threats.", "fx": {"reach": 0.12},
		"icon": {"s": "glasses", "c": "3a3a4a", "c2": "9ad8f0"}},
	"bookworm_charm": {"name": "Bookworm Charm", "type": "amulet", "rarity": "uncommon", "price": 36,
		"flavor": "He eats the boring parts for you.", "fx": {"regen": 0.35},
		"icon": {"s": "worm", "c": "8aca5a", "c2": "3a6a2a"}},
	"margin_doodle": {"name": "Margin Doodle", "type": "amulet", "rarity": "uncommon", "price": 40,
		"flavor": "A small sword, drawn with enthusiasm.", "fx": {"dmg": 0.09},
		"icon": {"s": "star", "c": "5a7ab8", "c2": "f4f0e6"}},
	"cartographer_compass": {"name": "Cartographer's Compass", "type": "amulet", "rarity": "rare", "price": 80,
		"flavor": "Always points to the next interesting thing.", "fx": {"speed": 0.10, "mnemo": 0.15},
		"icon": {"s": "compass", "c": "d8b45e", "c2": "6a4a1c"}},
	"silver_ribbon": {"name": "Silver Ribbon", "type": "amulet", "rarity": "rare", "price": 85,
		"flavor": "Tied around the last page of a love letter.", "fx": {"armor": 0.12, "invuln": 0.3},
		"icon": {"s": "ribbon", "c": "c8d0e0", "c2": "8a96b0"}},
	"lamplighter_match": {"name": "Lamplighter's Match", "type": "amulet", "rarity": "rare", "price": 82,
		"flavor": "Never goes out. Never asks for credit.", "fx": {"lantern_eff": -0.35},
		"icon": {"s": "match", "c": "d8503a", "c2": "d9a65a"}},
	"ghostwriter_glove": {"name": "Ghostwriter's Glove", "type": "amulet", "rarity": "rare", "price": 95,
		"flavor": "It wrote this item description.", "fx": {"dmg": 0.15, "reach": 0.10},
		"icon": {"s": "glove", "c": "f4f0e6", "c2": "9aa0b0"}},
	"hourglass_of_drafts": {"name": "Hourglass of Drafts", "type": "amulet", "rarity": "epic", "price": 170,
		"flavor": "Every grain is a version you did not publish.", "fx": {"dash_cd": -0.30, "speed": 0.08},
		"icon": {"s": "hourglass", "c": "e8d8a8", "c2": "9a6ac8"}},
	"censors_monocle": {"name": "Censor's Monocle", "type": "amulet", "rarity": "epic", "price": 175,
		"flavor": "Confiscated, then polished.", "fx": {"armor": 0.15, "dmg": 0.12},
		"icon": {"s": "monocle", "c": "d8b45e", "c2": "b8402f"}},
	"midnight_inkwell": {"name": "Midnight Inkwell", "type": "amulet", "rarity": "epic", "price": 180,
		"flavor": "Never empties while you are still writing.", "fx": {"regen": 1.1, "renown": 0.15},
		"icon": {"s": "inkwell", "c": "26324a", "c2": "56688a"}},
	"lucky_clover": {"name": "Lucky Clover", "type": "amulet", "rarity": "rare", "price": 90,
		"flavor": "Four leaves. Someone got to the fifth and stopped.", "fx": {"luck": 0.30},
		"icon": {"s": "leaf", "c": "5aca6a", "c2": "2f7a3a"}},
	"pocket_workbench": {"name": "Pocket Workbench", "type": "key", "rarity": "uncommon", "price": 150,
		"desc": "A folding bench, a tiny vice and a surprising number of pliers. Use it from the Binder to craft anywhere.", "flavor": "Every lantern post has a bench. This one has legs.",
		"icon": {"s": "bench", "c": "b8a07a", "c2": "6a4a30"}},
	"authors_pen": {"name": "The Author's Pen", "type": "amulet", "rarity": "legendary", "price": 500,
		"flavor": "It still remembers how it all began.", "fx": {"dmg": 0.30, "reach": 0.20, "regen": 0.8},
		"icon": {"s": "pen", "c": "f2c24b", "c2": "26324a"}},
	"eternal_bookmark": {"name": "The Eternal Bookmark", "type": "amulet", "rarity": "legendary", "price": 500,
		"flavor": "Marks the place where you decided to keep going.", "fx": {"armor": 0.20, "invuln": 0.6, "renown": 0.25, "mnemo": 0.25},
		"icon": {"s": "bookmark", "c": "b8402f", "c2": "f2c24b"}},
	"golden_ratio": {"name": "The Golden Ratio", "type": "amulet", "rarity": "legendary", "price": 480,
		"flavor": "Perfectly proportioned. Perfectly smug.", "fx": {"armor": 0.10, "speed": 0.10, "dmg": 0.10, "reach": 0.10, "dash_cd": -0.10, "regen": 0.4},
		"icon": {"s": "spiral", "c": "f2c24b", "c2": "c9922b"}},
}

## Crafting: result -> {needs: {id: n}, gives: n}. (A workbench will use this; they are listed here
## so loot tables and shops can be balanced against them now.)
const RECIPES := {
	"ink_vial": {"needs": {"ink_blot": 3}, "gives": 1},
	"clarity_tonic": {"needs": {"ink_vial": 1, "clover_press": 1}, "gives": 1},
	"ghost_pepper_ink": {"needs": {"ink_blot": 2, "pencil_shaving": 2}, "gives": 1},
	"cloth_binding": {"needs": {"paper_scrap": 4, "loose_thread": 2}, "gives": 1},
	"dust_jacket": {"needs": {"paper_scrap": 6, "glue_stub": 2, "loose_thread": 2}, "gives": 1},
	"library_binding": {"needs": {"cloth_binding": 1, "silver_thread": 2, "wax_seal": 1}, "gives": 1},
	"vellum_binding": {"needs": {"library_binding": 1, "gold_leaf": 3, "blank_page": 1}, "gives": 1},
	"illuminated_binding": {"needs": {"vellum_binding": 1, "phoenix_ember": 1, "marginalia_dust": 3, "gold_leaf": 4}, "gives": 1},
	"pocket_workbench": {"needs": {"paper_scrap": 8, "glue_stub": 3, "loose_thread": 4, "wax_seal": 1}, "gives": 1},
	"warm_loaf": {"needs": {"honey_biscuit": 2, "herbal_tea": 1}, "gives": 1},
	"memory_jar": {"needs": {"marginalia_dust": 2, "gold_leaf": 1}, "gives": 1},
	"lucky_clover": {"needs": {"clover_press": 4, "silver_thread": 1}, "gives": 1},
	"lamplighter_match": {"needs": {"pencil_shaving": 6, "phoenix_ember": 1}, "gives": 1},
	"time_in_a_bottle": {"needs": {"marginalia_dust": 3, "void_pearl": 1, "clarity_tonic": 1}, "gives": 1},
	"tin_bell": {"needs": {"paper_clip": 1, "wax_seal": 1}, "gives": 1},
	"silver_ribbon": {"needs": {"silver_thread": 3, "loose_thread": 2}, "gives": 1},
	"phoenix_draught": {"needs": {"phoenix_ember": 1, "clarity_tonic": 1}, "gives": 1},
	"authors_pen": {"needs": {"quill_feather": 3, "unwritten_word": 1, "gold_leaf": 2}, "gives": 1},
}

## What the later-game shop would stock (drop chances live in DropTables).
## The Narrator's Stall: [item id, minimum Rank]. Better stock opens up as your Rank rises.
const SHOP_STOCK := [
	["ink_vial", 1], ["honey_biscuit", 1], ["herbal_tea", 1], ["eraser_crumbs", 1], ["paper_clip", 1], ["rubber_band", 1], ["pocket_workbench", 1],
	["warm_loaf", 2], ["clarity_tonic", 2], ["ghost_pepper_ink", 2], ["tin_bell", 2], ["cloth_binding", 2], ["lantern_oil", 2],
	["reading_glasses", 3], ["bookworm_charm", 3], ["margin_doodle", 3], ["dust_jacket", 3], ["reader_digest", 3], ["sticky_note", 3],
	["ink_flask", 4], ["memory_jar", 4], ["lucky_clover", 4], ["library_binding", 4], ["silver_ribbon", 4], ["cartographer_compass", 4],
	["vellum_binding", 5], ["hourglass_of_drafts", 5], ["censors_monocle", 5], ["phoenix_draught", 5], ["time_in_a_bottle", 5],
]

## What the Narrator will pay for something you carry, in Mnemosynth.
static func sell_price(id: String) -> int:
	return maxi(1, int(buy_price(id) * 0.4))

static func buy_price(id: String) -> int:
	var d := ItemDB.info(id)
	if d.has("price"):
		return int(d["price"])
	return {"consumable": 12, "binding": 40, "amulet": 35, "material": 6}.get(d["type"], 20)

static func can_craft(id: String) -> bool:
	for need: String in RECIPES[id]["needs"]:
		if GameState.count(need) < int(RECIPES[id]["needs"][need]):
			return false
	return true

## Spends the ingredients and gives the result. Returns false if something is missing.
static func craft(id: String) -> bool:
	if not RECIPES.has(id) or not can_craft(id):
		return false
	for need: String in RECIPES[id]["needs"]:
		GameState.remove_item(need, int(RECIPES[id]["needs"][need]))
		if GameState.is_equipped(need) and GameState.count(need) <= 0:
			GameState.toggle_equip(need)
	GameState.add_item(id, int(RECIPES[id].get("gives", 1)))
	return true

const RARITY_COLORS := {
	"common": Color("8a8070"), "uncommon": Color("4a9a5a"), "rare": Color("4a7ac8"),
	"epic": Color("9a5ac8"), "legendary": Color("e0a020"),
}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

const STAT_NAMES := {
	"armor": "damage taken", "speed": "speed", "dash_cd": "dash cooldown", "invuln": "grace after a hit",
	"dmg": "Quill damage", "reach": "Quill reach", "lantern_eff": "Lantern burn", "regen": "ink regen",
	"mnemo": "Mnemosynth found", "luck": "drop chances", "renown": "Renown earned",
}

## Plain-English line for an fx dictionary ("-5% damage taken, +7% speed ...").
static func fx_text(fx: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in fx.keys():
		var v: float = fx[k]
		var name: String = STAT_NAMES.get(k, k)
		match k:
			"armor": parts.append("%+d%% %s" % [roundi(-v * 100.0), name])
			"dash_cd", "lantern_eff": parts.append("%+d%% %s" % [roundi(v * 100.0), name])
			"invuln": parts.append("+%.1fs %s" % [v, name])
			"regen": parts.append("+%.1f/s %s" % [v, name])
			_: parts.append("%+d%% %s" % [roundi(v * 100.0), name])
	return ", ".join(parts)
