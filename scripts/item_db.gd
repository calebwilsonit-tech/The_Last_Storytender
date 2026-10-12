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
