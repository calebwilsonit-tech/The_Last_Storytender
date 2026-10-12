class_name RedrawGate
extends RefCounted
## Decides when an animated figure should repaint. Figures animate "on twos" at 24 frames a second, like
## hand-drawn animation: their position still updates every frame, only the pose steps. That is the look
## we want and it is cheap. Far off screen they barely repaint at all.

const HZ := 24.0
var hz := HZ
var _acc := randf() * (1.0 / HZ)

func ok(delta: float, node: Node2D) -> bool:
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
