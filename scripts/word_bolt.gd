class_name WordBolt
extends Node2D
## A discouraging word flying through the air. Hits apply damage plus a debuff
## ("slow" or "dim"), handled by the memory level.

var word := ""
var fx := "slow"
var vel := Vector2.ZERO
var floor_ref: IsoFloor
const REWRITES := {
	"Derivative!": "Original!", "Boring!": "Gripping!", "Overwritten.": "Concise.",
	"Clichéd!": "Fresh!", "Nobody asked.": "Everyone asked.", "Too slow!": "Just right.",
}

var reflectable := false     # during the Reckoning the Quill can strike a word out of the air
var friendly := false        # ...and it comes back rewritten, flying at the Critic
var reflect_to: Node2D
var hit_r := 24.0
var _age := 0.0
var _trail: Array[Vector2] = []

func _ready() -> void:
	add_to_group("bolts")
	if reflectable:
		add_to_group("hittables")

## The Quill rewrites the word and sends it back.
func hurt(_dmg: float = 0.0, _dir: Vector2 = Vector2.ZERO) -> void:
	if not reflectable or friendly:
		return
	friendly = true
	remove_from_group("hittables")
	word = REWRITES.get(word, "Lovely!")
	_age = 0.0
	var speed := maxf(vel.length(), 150.0) * 1.5
	vel = (reflect_to.position - position).normalized() * speed if reflect_to else -vel

func _process(delta: float) -> void:
	_age += delta
	position += vel * delta
	_trail.append(position)
	if _trail.size() > 14:
		_trail.pop_front()
	if _age > 5.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var z := (floor_ref.height_at(position) * Iso.LEVEL_H + 26.0) if floor_ref else 26.0
	var fade := clampf((5.0 - _age) / 0.6, 0.0, 1.0)
	# Ink streak trailing behind the word.
	for i in _trail.size():
		var p := _trail[i] - position + Vector2(0, -z)
		var a := float(i) / maxf(_trail.size(), 1.0)
		draw_circle(p, 2.0 + a * 4.0, Color(Color("5fd08a") if friendly else Palette.CRITIC_RED, a * 0.6 * fade))
	var font := ThemeDB.get_default_theme().default_font
	var sz := 26
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var at := Vector2(-w * 0.5, -z)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 8, Color(Palette.OUTLINE, 0.95 * fade))
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, (Color("7fe3a0", fade) if friendly else Color("ff6a5c", fade)))
	# Ground marker so the aim is readable on a tilted plane.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 12.0, Color(Palette.CRITIC_RED, 0.25 * fade))
