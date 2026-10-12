class_name EchoPlate
extends Node2D
## A floor plate that wants someone standing on it: you, or a remembered you.

signal toggled(on: bool)

var floor_ref: IsoFloor
var player: Player
var elev := 0.0
var pressed := false
var _t := 0.0
const RADIUS := 30.0

func _held_by_player() -> bool:
	return player != null and not player.is_falling and not player.is_crumpled and _near(player.position)

func _near(p: Vector2) -> bool:
	var d := p - position
	d.y *= 2.0
	return d.length() < RADIUS and absf(floor_ref.height_at(p) - floor_ref.height_at(position)) < 0.6

func _process(delta: float) -> void:
	_t += delta
	var now := _held_by_player()
	if not now:
		for e: Echo in get_tree().get_nodes_in_group("echoes"):
			if e.state != "rec" and _near(e.position):
				now = true
				break
	if now != pressed:
		pressed = now
		toggled.emit(pressed)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var d := Iso.diamond(Vector2.ZERO, 0.9)
	var inset := Iso.diamond(Vector2.ZERO, 0.62)
	var base := Color("3a4a5e")
	draw_colored_polygon(d, base.darkened(0.2))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Palette.OUTLINE, 2.6, true)
	var glow := Palette.CYAN if pressed else Color("5f7488")
	draw_colored_polygon(inset, glow.darkened(0.35) if not pressed else glow.darkened(0.1))
	# Emblem: a ring inside a ring, the shape of something remembered.
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	var col := Color(1, 1, 1, 0.9) if pressed else Color(Palette.PAPER_LIGHT, 0.45)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, col, 2.4, true)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 14, col, 2.0, true)
	if pressed:
		draw_circle(Vector2.ZERO, 34.0 + sin(_t * 4.0) * 3.0, Color(Palette.CYAN, 0.14))
