extends CanvasLayer
## Page-turn fade between scenes (autoload as Transition).

var _rect: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(Palette.PAPER_LIGHT, 0.0)
	add_child(_rect)

func go(path: String, tint: Color = Palette.PAPER_LIGHT) -> void:
	if _busy:
		return
	_busy = true
	_rect.color = Color(tint, 0.0)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, 0.8)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, 1.1)
	await tw2.finished
	_busy = false
