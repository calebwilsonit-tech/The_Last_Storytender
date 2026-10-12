class_name PageCut
extends Node2D
## A sheet of paper flung by the Spoiler, edge first. It cuts. The Quill can swat one out of the air.

var vel := Vector2.ZERO
var floor_ref: IsoFloor
var hit_r := 14.0
var _age := 0.0
var _spin := randf() * TAU

func _ready() -> void:
	add_to_group("page_cuts")
	add_to_group("hittables")

func hurt(_dmg: float = 0.0, _dir: Vector2 = Vector2.ZERO) -> void:
	queue_free()

func _process(delta: float) -> void:
	_age += delta
	position += vel * delta
	_spin += delta * 9.0
	if _age > 4.5:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var z := (floor_ref.height_at(position) * Iso.LEVEL_H + 34.0) if floor_ref else 34.0
	var fade := clampf((4.5 - _age) / 0.5, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.22 * fade))
	# a sheet seen edge-on as it tumbles: it narrows and widens
	var w := 7.0 + 6.0 * absf(cos(_spin))
	var pts := PackedVector2Array([Vector2(-w, -5), Vector2(w, -5.5), Vector2(w * 0.9, 5), Vector2(-w * 0.9, 5.5)])
	draw_set_transform(Vector2(0, -z), sin(_spin) * 0.5, Vector2.ONE)
	draw_colored_polygon(pts, Color(Palette.PAGE, fade))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(Palette.OUTLINE, fade), 2.0, true)
	draw_line(Vector2(-w * 0.6, -1), Vector2(w * 0.6, -1.5), Color(Palette.SPOILER_INK, 0.5 * fade), 1.4)
	draw_line(Vector2(-w * 0.6, 2), Vector2(w * 0.3, 1.6), Color(Palette.SPOILER_INK, 0.5 * fade), 1.4)
