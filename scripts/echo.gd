class_name Echo
extends Node2D
## A remembered moment of the Storytender. Press R to start remembering, walk, press R to
## stop: a ghost then plays those seconds back and stands where the memory ends. It has weight
## (it holds plates down) and the curious are drawn to it (it lures guards).

signal recorded(echo: Echo)
signal discarded(echo: Echo)

const MAX_TIME := 9.0
const MIN_FRAMES := 20

var floor_ref: IsoFloor
var player: Player
var state := "rec"            # rec | play | hold
var lures := false            # true once recorded
var elev := 0.0
var path: Array[Vector2] = []
var _idx := 0
var _t := 0.0

func _ready() -> void:
	add_to_group("echoes")
	position = player.position
	path.append(position)

func elapsed_frac() -> float:
	return clampf(float(path.size()) / (MAX_TIME * 60.0), 0.0, 1.0)

func stop_record() -> void:
	if state != "rec":
		return
	if path.size() < MIN_FRAMES:
		discarded.emit(self)
		queue_free()
		return
	state = "play"
	lures = true
	_idx = 0
	position = path[0]
	recorded.emit(self)

func _physics_process(_delta: float) -> void:
	match state:
		"rec":
			path.append(player.position)
			if path.size() >= int(MAX_TIME * 60.0):
				stop_record()
		"play":
			_idx += 1
			if _idx >= path.size():
				state = "hold"
				_idx = path.size() - 1
			position = path[_idx]
	var want := floor_ref.height_at(position) * Iso.LEVEL_H if floor_ref else 0.0
	elev = lerpf(elev, want, 0.25)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _facing() -> float:
	if _idx > 4 and _idx < path.size():
		var d := path[_idx].x - path[_idx - 4].x
		if absf(d) > 0.5:
			return signf(d)
	return 1.0

func _draw() -> void:
	var cyan := Palette.CYAN
	if state == "rec":
		# Where the memory begins, and the road walked so far.
		draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 22.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - elapsed_frac()), 28, Color(cyan, 0.9), 3.0, true)
		draw_arc(Vector2.ZERO, 14.0 + sin(_t * 6.0) * 2.0, 0.0, TAU, 20, Color(cyan, 0.5), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var i := 0
		while i < path.size():
			var p := path[i] - position
			draw_circle(Vector2(p.x, p.y * 0.5), 2.2, Color(cyan, 0.55))
			i += 10
		return
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0.0, 0.1, 0.15, 0.25))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var f := _facing()
	var bob := sin(_t * 3.0) * 1.2 if state == "hold" else 0.0
	var alpha := 0.55 + 0.12 * sin(_t * 4.0)
	var cloak := PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(6, -26 + bob), Vector2(-6, -26 + bob)])
	draw_colored_polygon(cloak, Color(cyan, alpha * 0.55))
	draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[3], cloak[0]]), Color(cyan, alpha), 2.0, true)
	draw_circle(Vector2(0, -31 + bob), 8.0, Color(0.05, 0.12, 0.2, 0.8))
	draw_arc(Vector2(0, -31 + bob), 8.0, 0.0, TAU, 16, Color(cyan, alpha), 2.0, true)
	var lamp := Vector2(11 * f, -14 + bob)
	draw_circle(lamp, 9.0, Color(cyan, 0.12))
	draw_circle(lamp, 3.0, Color(1, 1, 1, 0.9))
	if state == "hold":
		draw_arc(Vector2(0, -2), 16.0 + sin(_t * 3.0) * 1.5, 0.0, TAU, 20, Color(cyan, 0.25), 1.5, true)
