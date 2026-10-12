class_name PressurePlate
extends Node2D
## A floor plate that needs weight. A plain block is not enough (weight 1);
## a BOLD block is (weight 2).

signal toggled(on: bool)

var cell := Vector2i.ZERO
var floor_ref: IsoFloor
var required := 2
var elev := 0.0
var pressed := false
var _t := 0.0

var _gate := RedrawGate.new()

func _process(delta: float) -> void:
	_t += delta
	var w := 0
	var b = floor_ref.block_cells.get(cell)
	if b != null and is_instance_valid(b) and not b._sliding:
		w = b.weight()
	var now := w >= required
	if now != pressed:
		pressed = now
		toggled.emit(pressed)
	if _gate.ok(delta, self):
		queue_redraw()

func _draw() -> void:
	var art := Skins.art()
	if art != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if art.draw_prop(self, "prop_plate", {"t": _t, "pressed": pressed, "origin": Vector2(0, -elev), "scale": 1.0}):
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var d := Iso.diamond(Vector2.ZERO, 0.9)
	var inset := Iso.diamond(Vector2.ZERO, 0.62)
	var base := Color("5b5f70")
	draw_colored_polygon(d, base.darkened(0.2))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Palette.OUTLINE, 2.6, true)
	var glow := Palette.GOLD if pressed else Color("8a8fa3")
	draw_colored_polygon(inset, glow if pressed else glow.darkened(0.3))
	# Emblem: a bold B, because only weight will do.
	var font := ThemeDB.get_default_theme().default_font
	var col := Palette.INK if pressed else Color(Palette.PAPER_LIGHT, 0.6)
	for dx in [-0.8, 0.8]:
		draw_string(font, Vector2(-8 + dx, 8), "B", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, col)
	if pressed:
		draw_circle(Vector2.ZERO, 30.0 + sin(_t * 4.0) * 3.0, Color(Palette.GOLD, 0.12))
