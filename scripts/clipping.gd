class_name Clipping
extends Node2D
## A piece of the world the Scissor-Man cut out. Pick it up with the Quill (or E);
## it goes on your clipboard. Press V to paste it back where you are aiming.

signal picked(clipping: Clipping)

var shape: Array[Vector2i] = [Vector2i.ZERO]
var floor_ref: IsoFloor
var elev := 0.0
var hit_r := 26.0
var _t := 0.0
var _seed := 0.0
var _flash := 0.0

func _ready() -> void:
	_seed = position.x * 0.013 + position.y * 0.021
	_t = _seed * 5.0
	add_to_group("hittables")

## The Quill picks it up.
func hurt(_d: float = 0.0, _dir: Vector2 = Vector2.ZERO) -> void:
	picked.emit(self)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var bob := sin(_t * 2.2) * 3.0
	# The shape of the cut-out, as little paper tiles, floating.
	var lo := Vector2(1e9, 1e9)
	for o in shape:
		lo = Vector2(minf(lo.x, o.x), minf(lo.y, o.y))
	var mid := Vector2.ZERO
	for o in shape:
		mid += Vector2(o)
	mid /= float(shape.size())
	for o in shape:
		var ctr := Iso.to_screen(Vector2(o) - mid) * 0.55 + Vector2(0, -26 + bob)
		var d := Iso.diamond(ctr, 0.5)
		draw_colored_polygon(d, Palette.PAGE)
		var loop := d.duplicate()
		loop.append(d[0])
		draw_polyline(loop, Palette.OUTLINE, 2.2, true)
		draw_line(d[0].lerp(d[2], 0.2), d[0].lerp(d[2], 0.8), Color(Palette.CRITIC_RED, 0.5), 1.4)
	for i in 3:
		var ph := fmod(_t * 0.5 + i * 0.3, 1.0)
		draw_circle(Vector2(-10 + i * 10, -26 - ph * 30.0), 1.6, Color(Palette.CYAN, (1.0 - ph) * 0.9))
