class_name ArtStyle
extends RefCounted
## One complete art direction for the characters (and later props and tiles). Styles are plain code:
## each one decides how every figure is drawn from the same description of what it is doing (the ctx).
## The game asks the active style first and falls back to the original procedural art when a style
## does not draw something yet, so styles can be built up piece by piece and compared in the Art Lab.
##
## Drawing contract for draw_character(ci, kind, ctx):
##  - The origin is the figure's feet, centred, on the ground. +y is down. One unit is one world pixel.
##  - The caller has already set the canvas transform for elevation; the style does its own mirroring.
##  - Return true if the figure was drawn, false to let the original art draw it.
## ctx (all keys optional, read with .get): t (seconds), moving, phase (walk cycle radians), facing_right,
## facing_back, swing (0..1 strike), combo (1..3), sneaking, crumpled, invuln, lantern_on, flick,
## weapon ("stub" | "sword" | "quill"), binding / amulet (item ids), restored (0..1 for NPCs),
## state (enemy: "idle" | "windup" | "lunge" | "stunned" ...), proof (0..1 enemy proofread),
## flash (hit flash), hp (0..1), seed (stable per-individual random).

var id := ""
var title := ""
var blurb := ""

## Figures this style knows how to draw (used by the Art Lab to show gaps).
func kinds() -> Array:
	return []

func draw_character(_ci: CanvasItem, _kind: String, _ctx: Dictionary) -> bool:
	return false

func draw_prop(_ci: CanvasItem, _kind: String, _ctx: Dictionary) -> bool:
	return false
