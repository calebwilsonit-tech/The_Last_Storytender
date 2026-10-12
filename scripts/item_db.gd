class_name ItemDB
extends RefCounted
## All items in one table. Flavor text comes from the design document.
## type: consumable | binding | amulet | material | key

const ITEMS := {
	"eraser_crumbs": {
		"name": "Eraser Crumbs", "type": "consumable",
		"desc": "Throw it. Rubs out Errors in a small radius (5 damage).",
		"flavor": "Everything starts as a mistake someone rubbed out.",
	},
	"ink_vial": {
		"name": "Ink Vial", "type": "consumable",
		"desc": "Restores a good measure of ink.",
		"flavor": "Still wet.",
	},
	"warm_loaf": {
		"name": "Warm Loaf", "type": "consumable",
		"desc": "Restores a good deal of ink.",
		"flavor": "Still warm. Someone made it for you.",
	},
	"hardcover_binding": {
		"name": "Hardcover Binding", "type": "binding",
		"desc": "Heavy plates cut from book covers. -30% damage taken, but slower.",
		"flavor": "You can judge it by its cover. Everyone does.",
		"fx": {"armor": 0.30, "speed": -0.10},
	},
	"softcover_binding": {
		"name": "Softcover Binding", "type": "binding",
		"desc": "Light, flexible leather. +12% speed, faster dash, -10% damage taken.",
		"flavor": "Dog-eared. Loved.",
		"fx": {"armor": 0.10, "speed": 0.12, "dash_cd": -0.25},
	},
	"oxford_comma": {
		"name": "The Oxford Comma", "type": "amulet",
		"desc": "A pause before you take the next hit: a little extra grace after being struck.",
		"flavor": "A small pause, and all the difference.",
		"fx": {"invuln": 0.5},
	},
	"thimble": {
		"name": "The Tailor's Thimble", "type": "amulet",
		"desc": "A small, dented thimble. -8% damage taken and a faster dash.",
		"flavor": "Made to push the needle through, so the sewing could keep going.",
		"fx": {"armor": 0.08, "dash_cd": -0.15},
	},
	# --- Trial prizes: better the harder the vault ------------------------------------------------
	"ink_flask": {
		"name": "Ink Flask", "type": "consumable",
		"desc": "Restores all of your ink.",
		"flavor": "Bottled by someone who knew you would need it.",
	},
	"lantern_oil": {
		"name": "Lantern Oil", "type": "consumable",
		"desc": "Refills the Lantern completely.",
		"flavor": "Smells like warm paper and good intentions.",
	},
	"sticky_note": {
		"name": "Sticky Note", "type": "consumable",
		"desc": "Sticks every Error nearby to the page for a few seconds. They cannot move, and a hit on one counts as a sneak attack.",
		"flavor": "Reminder: do not be eaten.",
	},
	"paperback_binding": {
		"name": "Paperback Binding", "type": "binding",
		"desc": "Cheap, light and quick. +20% speed, but -5% protection.",
		"flavor": "Read it until the spine cracks.",
		"fx": {"speed": 0.20, "armor": -0.05},
	},
	"leatherbound_binding": {
		"name": "Leatherbound Binding", "type": "binding",
		"desc": "Fine leather, gold edges. -20% damage taken and +10% Quill damage.",
		"flavor": "It smells like an old library and a good decision.",
		"fx": {"armor": 0.20, "dmg": 0.10},
	},
	"gilded_binding": {
		"name": "Gilded Binding", "type": "binding",
		"desc": "A collector's binding. -15% damage taken, +10% speed, faster dash, +15% Quill damage.",
		"flavor": "Too nice to read. You read it anyway.",
		"fx": {"armor": 0.15, "speed": 0.10, "dash_cd": -0.20, "dmg": 0.15},
	},
	"highlighter": {
		"name": "The Highlighter", "type": "amulet",
		"desc": "The Lantern burns 35% slower.",
		"flavor": "It makes the important parts glow, and the rest less important.",
		"fx": {"lantern_eff": -0.35},
	},
	"margin_note": {
		"name": "Margin Note", "type": "amulet",
		"desc": "-10% damage taken.",
		"flavor": "'Be careful here.'  (Underlined twice.)",
		"fx": {"armor": 0.10},
	},
	"index_tab": {
		"name": "Index Tab", "type": "amulet",
		"desc": "Your dash recovers 20% faster.",
		"flavor": "Always one flick from the page you need.",
		"fx": {"dash_cd": -0.20},
	},
	"red_pen": {
		"name": "The Red Pen", "type": "amulet",
		"desc": "+25% Quill damage.",
		"flavor": "Strike it out. Strike it all out.",
		"fx": {"dmg": 0.25},
	},
	"footnote": {
		"name": "The Footnote", "type": "amulet",
		"desc": "Your Quill reaches 20% further.",
		"flavor": "Small, numbered, and surprisingly far-reaching.",
		"fx": {"reach": 0.20},
	},
	"bookmark_charm": {
		"name": "Bookmark Charm", "type": "amulet",
		"desc": "Your ink slowly refills on its own (0.8 per second).",
		"flavor": "Wherever you stopped, it keeps your place.",
		"fx": {"regen": 0.8},
	},
	"first_edition": {
		"name": "The First Edition", "type": "amulet",
		"desc": "-10% damage taken, +10% Quill damage, a little ink regeneration and extra grace after a hit.",
		"flavor": "Every story starts as someone's first try. This one got it nearly right.",
		"fx": {"armor": 0.10, "dmg": 0.10, "regen": 0.4, "invuln": 0.3},
	},
	"void_ink": {
		"name": "Void Ink", "type": "material",
		"desc": "A crafting material scraped from the Redaction.",
		"flavor": "It stains your fingers with bad memories.",
	},
	"torn_page": {
		"name": "The Torn Page", "type": "key",
		"desc": "The last page of Pip's storybook, torn out and hidden. It fits the door to the final room.",
		"flavor": "He tore it out so no one could spoil it. Then he spoiled it himself.",
	},
	"bookmark": {
		"name": "The Bookmark", "type": "key",
		"desc": "Lets you return to a place you have restored.",
		"flavor": "A promise to return to this moment.",
	},
}

static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "type": "key", "desc": "", "flavor": ""})

static func type_label(id: String) -> String:
	match info(id)["type"]:
		"consumable": return "Consumable"
		"binding": return "Binding (armor)"
		"amulet": return "Amulet"
		"material": return "Material"
		_: return "Key item"
