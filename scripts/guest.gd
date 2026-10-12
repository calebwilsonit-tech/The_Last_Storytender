class_name Guest
extends Node2D
## A shape in the dark that used to sit at Maud's table. Hold the Lantern's warmth
## on one and it drifts toward you; lead it to an empty chair and it sits down.
## The Clearing erases standing guests and stands seated ones back up.

signal seated(guest: Guest)
signal unseated(guest: Guest)

var floor_ref: IsoFloor
var target: Node2D
var walkable: Array[Vector2i] = []   # cells guests may wander on
var chairs: Array[Prop] = []
var variant := 0
var elev := 0.0
var hit_r := 22.0
var state := "wander"                # wander | follow | seated | erased
var chair: Prop
var _t := 0.0
var _lit_t := 0.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _fade := 1.0
var _respawn_t := 0.0
var _seed := 0.0

func _ready() -> void:
	_seed = position.x * 0.013 + position.y * 0.021
	_t = _seed * 5.0
	add_to_group("lightable")

## The beam: guests are drawn to the light like moths.
func lit(_delta: float) -> void:
	if state == "wander" or state == "follow":
		state = "follow"
		_lit_t = 0.5

func _step(g: Vector2, spd: float, delta: float) -> void:
	var v := Vector2(g.x, g.y * 0.5) * spd * delta
	var np := position + v
	var c := floor_ref.cell_at(np)
	if walkable.has(c) and not floor_ref.block_cells.has(c) and floor_ref.cells.get(c, "") != "#":
		position = np

func _process(delta: float) -> void:
	_t += delta
	match state:
		"wander":
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(1.0, 2.5)
				_wander = Vector2.from_angle(randf() * TAU) if randf() > 0.35 else Vector2.ZERO
			_step(_wander, 34.0, delta)
		"follow":
			_lit_t -= delta
			if _lit_t <= 0.0:
				state = "wander"
			else:
				var d := target.position - position
				var g := Vector2(d.x, d.y * 2.0)
				if g.length() > 56.0:
					_step(g.normalized(), 80.0, delta)
				_try_sit()
		"erased":
			_fade = maxf(_fade - delta * 2.5, 0.0)
			_respawn_t -= delta
			if _respawn_t <= 0.0:
				state = "wander"
				_fade = 1.0
	queue_redraw()

func _try_sit() -> void:
	for c in chairs:
		if c.occupied:
			continue
		var d := c.position - position
		if Vector2(d.x, d.y * 2.0).length() < 60.0:
			state = "seated"
			chair = c
			c.occupied = true
			position = c.position + Vector2(0, -2)
			seated.emit(self)
			return

func unseat() -> void:
	if state != "seated":
		return
	if chair:
		chair.occupied = false
	chair = null
	state = "wander"
	unseated.emit(self)

## The Clearing wipes you away; you drift back from the edge a moment later.
func erase(respawn_at: Vector2, seconds: float = 3.5) -> void:
	if state == "seated":
		unseat()
	state = "erased"
	_respawn_t = seconds
	position = respawn_at

func is_seated() -> bool:
	return state == "seated"

func _draw() -> void:
	if state == "erased" and _fade <= 0.0:
		return
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.22 * _fade))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	var warm := state == "seated"
	var seat_lift := 14.0 if warm else 0.0
	var body_col := Color("e0a96a") if warm else Palette.STATIC_GRAY
	var edge := Palette.OUTLINE if warm else Color(0.85, 0.85, 0.95)
	var bob := sin(_t * 2.0) * 1.2 if not warm else 0.0
	var a := _fade
	if warm:
		for k in 3:
			draw_colored_polygon(DrawKit.ellipse(Vector2(0, -34 - seat_lift * 0.3), 18.0 + k * 6.0, 28.0 + k * 7.0, 20), Color(Palette.GOLD, (0.10 - k * 0.025) * a))
	var base := Vector2(0, -seat_lift + bob)
	DrawKit.shape(self, DrawKit.ellipse(base + Vector2(0, -22), 11.0, 15.0, 16, 0.05, _seed), Color(body_col, a), Color(edge, a), 2.4, _seed)
	DrawKit.shape(self, DrawKit.ellipse(base + Vector2(0, -42), 8.5, 8.5, 14, 0.05, _seed + 1.0), Color(body_col.lightened(0.1), a), Color(edge, a), 2.4, _seed + 1.0)
	match variant % 3:
		0:  # a hat
			DrawKit.shape(self, PackedVector2Array([base + Vector2(-10, -47), base + Vector2(10, -47), base + Vector2(6, -58), base + Vector2(-6, -58)]), Color(body_col.darkened(0.3), a), Color(edge, a), 2.0, _seed + 2.0)
		1:  # a scarf
			draw_line(base + Vector2(-9, -34), base + Vector2(9, -34), Color(Palette.CRITIC_RED if warm else edge, a), 4.0)
		_:  # a bonnet
			draw_arc(base + Vector2(0, -44), 10.0, PI, TAU, 10, Color(Palette.PAGE, a), 4.0, true)
	if warm:
		draw_circle(base + Vector2(-3, -43), 1.4, Palette.OUTLINE)
		draw_circle(base + Vector2(3, -43), 1.4, Palette.OUTLINE)
	else:
		# Television-static speckle and a glitchy tear, as with every forgotten thing.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 8.0) * 131 + int(_seed * 100.0)
		for i in 40:
			var p := base + Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-52.0, -6.0))
			var q := (p - base - Vector2(0, -22)) / Vector2(11, 15)
			if q.length() < 1.0 or (p - base - Vector2(0, -42)).length() < 8.5:
				var v := rng.randf()
				draw_rect(Rect2(p, Vector2(2, 2)), Color(Color.WHITE if v > 0.5 else (Palette.GLITCH if v > 0.35 else Color.BLACK), 0.8 * a))
