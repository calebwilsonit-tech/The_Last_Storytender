class_name SentenceStone
extends StaticBody2D
## A tablet bearing a sentence with one swappable word, e.g. "The bridge [BREAKS]".
## Strike it with the Quill (or press E) to rewrite the word and change what is true.
## Option 0 is the "bad" truth, the last option the "good" one.

signal rewritten(stone: SentenceStone, index: int)

var prefix := ""
var options: PackedStringArray = []
var suffix := "."
var index := 0
var locked := false           # once true, the sentence can no longer be changed
var ttl_max := 5.0            # what a full timer bar represents
var ttl := -1.0               # > 0 for the Spoiler's ephemeral sentences (seconds left)
var elev := 0.0
var hit_r := 24.0
var _t := 0.0
var _flash := 0.0
var _cd := 0.0

func _ready() -> void:
	var poly := CollisionPolygon2D.new()
	poly.polygon = Iso.diamond(Vector2.ZERO, 0.45)
	add_child(poly)
	add_to_group("hittables")

func word() -> String:
	return options[index]

func is_good() -> bool:
	return index == options.size() - 1

## Called by the Quill (hurt) or by the E key.
func hurt(_dmg: float = 0.0, _dir: Vector2 = Vector2.ZERO) -> void:
	rewrite()

func rewrite() -> void:
	if locked or _cd > 0.0:
		return
	_cd = 0.35
	_flash = 0.5
	index = (index + 1) % options.size()
	rewritten.emit(self, index)

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_cd = maxf(_cd - delta, 0.0)
	if ttl > 0.0:
		ttl -= delta
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.get_default_theme().default_font
	var sz := 22
	var full := "%s %s%s" % [prefix, options[index], suffix]
	var pw := font.get_string_size(prefix + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var ww := font.get_string_size(options[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var sw := font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	var total := pw + ww + sw
	var hover := sin(_t * 1.8) * 3.0
	var lift := elev + 44.0 + hover
	# Shadow and post.
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, -elev), 0.0, Vector2.ONE)
	# a little wooden lectern: tapered post on a stack of three old books
	var wood := Color("6a4a30")
	DrawKit.shape(self, PackedVector2Array([Vector2(-4, -lift + 14.0), Vector2(4, -lift + 14.0), Vector2(5, -12), Vector2(-5, -12)]), wood, Palette.OUTLINE, 2.0, 1.0)
	for i in 3:
		var bw := 24.0 - i * 3.0
		var bc: Color = [Color("8e3b32"), Color("2f5d7a"), Color("5b7a3a")][i]
		draw_rect(Rect2(-bw * 0.5, -4.0 * (i + 1), bw, 4.0), bc)
		draw_rect(Rect2(-bw * 0.5, -4.0 * (i + 1), bw, 4.0), Palette.OUTLINE, false, 1.6)
	draw_rect(Rect2(-14, -lift + 12.0, 28, 4), wood)
	draw_rect(Rect2(-14, -lift + 12.0, 28, 4), Palette.OUTLINE, false, 1.6)
	# The tablet.
	var good := is_good()
	var tint := Color("d9efd0") if good else Color("f6dcc8")
	var r := Rect2(-total * 0.5 - 14.0, -lift - 20.0, total + 28.0, 36.0)
	var glow := Palette.CYAN if _flash > 0.0 else (Palette.GOLD if not locked else Palette.GRASS)
	draw_rect(Rect2(r.position - Vector2(5, 5), r.size + Vector2(10, 10)), Color(glow, 0.20 + _flash * 0.5))
	draw_rect(r, tint)
	draw_rect(r, Palette.OUTLINE, false, 3.0)
	# a folded corner and a ribbon, so it reads as a loose page
	var fc := r.position + Vector2(r.size.x, r.size.y)
	draw_colored_polygon(PackedVector2Array([fc, fc + Vector2(-11, 0), fc + Vector2(0, -11)]), tint.darkened(0.12))
	draw_line(fc + Vector2(-11, 0), fc + Vector2(0, -11), Palette.OUTLINE, 1.6)
	draw_line(r.position + Vector2(10, 0), r.position + Vector2(10, -8), Color("a8483f"), 3.0)
	for k in 2:
		draw_line(r.position + Vector2(6, 10 + k * 14), r.position + Vector2(r.size.x - 6, 10 + k * 14), Color(Palette.INK_BROWN, 0.08), 1.0)
	var x := r.position.x + 14.0
	var y := r.position.y + 26.0
	draw_string(font, Vector2(x, y), prefix + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Palette.INK)
	var wcol := Color("2f8a45") if good else Color("c03b2b")
	draw_string_outline(font, Vector2(x + pw, y), options[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, 4, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(x + pw, y), options[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, wcol)
	draw_line(Vector2(x + pw, y + 3), Vector2(x + pw + ww, y + 3), wcol, 2.0)
	draw_string(font, Vector2(x + pw + ww, y), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, Palette.INK)
	if locked:
		draw_string(font, Vector2(r.position.x + 6, r.position.y - 6), "written", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(Palette.GRASS_DARK, 0.9))
	if ttl >= 0.0 and not locked:
		# Time left before this sentence comes true.
		var w := r.size.x
		draw_rect(Rect2(r.position + Vector2(0, r.size.y + 4), Vector2(w * clampf(ttl / ttl_max, 0.0, 1.0), 4)), Color(Palette.CRITIC_RED, 0.9))
