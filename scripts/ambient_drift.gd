class_name AmbientDrift
extends Node2D
## A handful of leaves and paper scraps blowing slowly across the screen, so the page never sits perfectly
## still. They follow the camera, repaint about 12 times a second, and cost a few dozen drawing commands.

const COUNT := 14
const HZ := 12.0
var _t := 0.0
var _acc := 0.0
var _cam: Camera2D

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 1.0 / HZ:
		_acc = 0.0
		visible = Settings.gfx_on("ambient")
		if visible:
			queue_redraw()

func _draw() -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d()
		if _cam == null:
			return
	var c := _cam.get_screen_center_position()
	for i in COUNT:
		var sp := 14.0 + fmod(i * 7.3, 12.0)                    # px per second
		var life := fmod(_t * 0.045 + i * 0.137, 1.0)            # 0..1 across the screen
		var x := lerpf(-760.0, 760.0, life)
		var y := -300.0 + fmod(i * 97.0, 560.0) + sin(_t * (0.9 + i * 0.07) + i) * 26.0 + life * 90.0
		var p := c + Vector2(x, y)
		var ang := _t * (0.8 + fmod(i, 3) * 0.5) + i
		var leaf := i % 3 != 0
		var a := sin(life * PI) * 0.75
		if leaf:
			var col := Color("8fb552") if i % 2 == 0 else Color("c7a24a")
			var pts := PackedVector2Array([Vector2(-4, 0), Vector2(0, -2.4), Vector2(4, 0), Vector2(0, 2.4)])
			for k in pts.size():
				pts[k] = p + pts[k].rotated(ang)
			draw_colored_polygon(pts, Color(col, a))
		else:
			var pts2 := PackedVector2Array([Vector2(-3.4, -2.6), Vector2(3.4, -2.2), Vector2(2.8, 2.6), Vector2(-3.0, 2.2)])
			for k in pts2.size():
				pts2[k] = p + pts2[k].rotated(ang)
			draw_colored_polygon(pts2, Color(0.96, 0.93, 0.82, a))
