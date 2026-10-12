class_name RedrawGate
extends RefCounted
## Decides when an animated figure should repaint. The original art redraws every frame; the Ink Cel
## figures are far more detailed, so they repaint about 24 times a second (position still updates every
## frame, only the pose steps) and rarely at all when they are far off screen.

const HZ := 24.0
var hz := HZ
var _acc := randf() * (1.0 / HZ)

func ok(delta: float, node: Node2D) -> bool:
	if Settings.art_style == "default":
		return true
	_acc += delta
	var every := 1.0 / hz
	var cam := node.get_viewport().get_camera_2d() if node.is_inside_tree() else null
	if cam != null:
		var d := node.global_position - cam.get_screen_center_position()
		if absf(d.x) > 760.0 or absf(d.y) > 520.0:
			every = 0.5
	if _acc >= every:
		_acc = fmod(_acc, every)
		return true
	return false
