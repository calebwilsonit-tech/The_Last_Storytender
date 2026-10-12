class_name ArtStyles
extends RefCounted
## The registry of art styles. "default" is the original procedural art (no style object).

const ORDER := ["default", "cel", "collage", "pixel"]
const NAMES := {
	"default": "Original (procedural)",
	"cel": "Ink Cel",
	"collage": "Paper Collage",
	"pixel": "Pixel",
}

static var _cache: Dictionary = {}

static func get_style(id: String) -> ArtStyle:
	if id == "default" or not NAMES.has(id):
		return null
	if not _cache.has(id):
		match id:
			"cel": _cache[id] = load("res://scripts/art/style_cel.gd").new()
			"collage": _cache[id] = load("res://scripts/art/style_collage.gd").new()
			"pixel": _cache[id] = load("res://scripts/art/style_pixel.gd").new()
	return _cache.get(id)

static func index_of(id: String) -> int:
	return maxi(ORDER.find(id), 0)
