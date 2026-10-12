class_name Hud
extends CanvasLayer
## Ink bottle, Mnemosynth counter, region name, interaction prompt, toasts,
## and the floating Narrator / Silence text.

var bottle: InkBottle
var gauge: LanternGauge
var _toolbar: StyleToolbar
var _boss_view: Control
var _boss_name := ""
var _boss_frac := 0.0
var _clip_view: Control
var _clip_shape: Array = []
var _quick_icon: ItemIcon
var _quick_label: Label
var _mnemo: Label
var _renown: Label
var _region: Label
var _prompt: PromptTag
var _tutorial_card: TutorialCard
var _toast: Label
var _narr: RichTextLabel
var _narr_tween: Tween
var _toast_tween: Tween
var _region_tween: Tween
var _region_text := ""
var _objective: Label
var _dim: ColorRect
var _debuff: Label
var _debuff_tween: Tween
var _labels: Array[Label] = []
var _dark := false

func _ready() -> void:
	layer = 10
	# Full-screen darkening used by the Critic's "Boring!" debuff.
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0.02, 0.0, 0.05, 0.0)
	add_child(_dim)
	bottle = InkBottle.new()
	bottle.position = Vector2(20, 14)
	add_child(bottle)

	gauge = LanternGauge.new()
	gauge.position = Vector2(104, 22)
	add_child(gauge)

	_mnemo = _label(26, Palette.GOLD.darkened(0.25))
	_mnemo.position = Vector2(104, 60)
	set_mnemo(0)

	_renown = _label(17, Color(Palette.INK_BROWN, 0.85))
	_renown.position = Vector2(180, 66)
	_region = _label(30, Palette.INK_BROWN)
	_region.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_region.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_region.position = Vector2(1240, 18)
	_region.modulate.a = 0.0

	_prompt = PromptTag.new()
	_prompt.position = Vector2(240, 496)
	_prompt.size = Vector2(800, 56)
	add_child(_prompt)

	_toast = _label(28, Palette.INK_BROWN)
	_toast.position = Vector2(440, 130)
	_toast.modulate.a = 0.0

	_narr = RichTextLabel.new()
	_narr.bbcode_enabled = true
	_narr.fit_content = true
	_narr.scroll_active = false
	_narr.custom_minimum_size = Vector2(900, 0)
	_narr.position = Vector2(190, 590)
	_narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.modulate.a = 0.0
	_narr.add_theme_font_size_override("italics_font_size", 30)
	_narr.add_theme_font_size_override("normal_font_size", 30)
	_narr.add_theme_color_override("font_outline_color", Color(Palette.PAPER_LIGHT, 0.85))
	_narr.add_theme_constant_override("outline_size", 8)
	add_child(_narr)

	_boss_view = Control.new()
	_boss_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_view.draw.connect(_paint_overlays)
	add_child(_boss_view)

	_toolbar = StyleToolbar.new()
	_toolbar.position = Vector2(104, 112)
	_toolbar.visible = false
	add_child(_toolbar)
	_toolbar.set_style(GameState.format_style)

	_quick_icon = ItemIcon.new()
	_quick_icon.position = Vector2(1180, 640)
	_quick_icon.custom_minimum_size = Vector2(64, 64)
	_quick_icon.size = Vector2(64, 64)
	add_child(_quick_icon)
	_quick_label = _label(20, Palette.INK_BROWN)
	_quick_label.position = Vector2(1150, 690)
	set_quickslot("")

	_objective = _label(22, Palette.INK_BROWN)
	_objective.position = Vector2(104, 92)
	_objective.visible = false
	_debuff = _label(40, Color("ff6a5c"))
	_debuff.position = Vector2(440, 200)
	_debuff.modulate.a = 0.0

	_tutorial_card = TutorialCard.new()
	add_child(_tutorial_card)

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(Palette.PAPER_LIGHT, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_labels.append(l)
	return l

func set_ink(cur: float, mx: float) -> void:
	bottle.set_ink(cur, mx)

func set_lantern(cur: float, mx: float) -> void:
	gauge.set_energy(cur, mx)

## Controls are taught by tutorial cards the first time something unlocks, not by an
## always-on bar. (Kept so older call sites keep working.)
func set_controls(_armed: bool) -> void:
	pass

## Shows the how-to card for a mechanic once per save. Awaitable.
func tutorial(id: String) -> void:
	var flag := "tut_" + id
	if not Settings.tutorial_tips or GameState.has_flag(flag) or not Tutorials.CARDS.has(id):
		return
	GameState.set_flag(flag)
	await _tutorial_card.show_card(Tutorials.CARDS[id])

func set_renown() -> void:
	_renown.text = "Rank %d   %d / %d" % [GameState.rank(), GameState.renown, GameState.rank_next()]

func set_mnemo(v: int) -> void:
	_mnemo.text = "◆ %d" % v

func set_prompt(text: String) -> void:
	_prompt.set_text(text)

func set_region(text: String) -> void:
	if text == _region_text:
		return
	_region_text = text
	_region.text = text
	_region.position.x = 1260.0 - _region.get_minimum_size().x
	if _region_tween:
		_region_tween.kill()
	_region_tween = create_tween()
	_region.modulate.a = 0.0
	_region_tween.tween_property(_region, "modulate:a", 1.0, 0.8)
	_region_tween.tween_interval(3.5)
	_region_tween.tween_property(_region, "modulate:a", 0.0, 1.5)

func toast(text: String) -> void:
	text = InputSetup.fmt(text)
	_toast.text = text
	_toast.position.x = 640.0 - _toast.get_minimum_size().x * 0.5
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 0.0
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.4)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.0)

## Narrator (warm, italic) or Silence (cold, small, whispered). Non-blocking.
func narrate(text: String, silence: bool = false, hold: float = 4.0) -> void:
	text = InputSetup.fmt(text)
	var col := Palette.SILENCE if silence else (Palette.PAPER_LIGHT if _dark else Palette.INK_BROWN)
	_narr.add_theme_color_override("default_color", col)
	_narr.text = "[center][i]%s[/i][/center]" % text
	if _narr_tween:
		_narr_tween.kill()
	_narr_tween = create_tween()
	_narr.modulate.a = 0.0
	_narr_tween.tween_property(_narr, "modulate:a", 1.0, 1.2 if silence else 0.8)
	_narr_tween.tween_interval(hold)
	_narr_tween.tween_property(_narr, "modulate:a", 0.0, 1.6)
	await _narr_tween.finished

func set_objective(text: String) -> void:
	text = InputSetup.fmt(text)
	_objective.visible = text != ""
	_objective.text = text

func set_dim(a: float) -> void:
	_dim.color.a = clampf(a, 0.0, 0.8)

## Flash the word that just hit you.
func debuff(text: String) -> void:
	_debuff.text = text
	_debuff.position.x = 640.0 - _debuff.get_minimum_size().x * 0.5
	if _debuff_tween:
		_debuff_tween.kill()
	_debuff_tween = create_tween()
	_debuff.modulate.a = 1.0
	_debuff_tween.tween_interval(0.5)
	_debuff_tween.tween_property(_debuff, "modulate:a", 0.0, 0.8)

## Light text on a dark page (used inside memories).
func set_dark(on: bool) -> void:
	_dark = on
	var fg := Palette.PAPER_LIGHT if on else Palette.INK_BROWN
	var halo := Color(0.02, 0.03, 0.07, 0.92) if on else Color(Palette.PAPER_LIGHT, 0.9)
	for l in _labels:
		if l == _debuff:
			continue
		l.add_theme_color_override("font_color", fg)
		l.add_theme_color_override("font_outline_color", halo)
	_narr.add_theme_color_override("font_outline_color", halo)
	_mnemo.add_theme_color_override("font_color", Palette.GOLD.lightened(0.2))

## Quick-use slot (F). Shows the item and how many remain.
func set_quickslot(id: String) -> void:
	_quick_icon.set_item(id, 46.0)
	_quick_icon.visible = id != ""
	_quick_label.visible = id != ""
	if id != "":
		_quick_label.text = "F   ×%d" % GameState.count(id)

## The Format mark's toolbar appears once the Quill has learned it.
func show_toolbar(on: bool) -> void:
	_toolbar.visible = on
	_toolbar.set_style(GameState.format_style)

func set_style(s: String) -> void:
	_toolbar.set_style(s)

## Boss health bar across the top (hidden when name is empty).
func set_boss(boss_name: String, fraction: float) -> void:
	_boss_name = boss_name
	_boss_frac = clampf(fraction, 0.0, 1.0)
	_boss_view.queue_redraw()

## The clipboard: the shape you are carrying (empty array = nothing held).
func set_clipboard(shape: Array) -> void:
	_clip_shape = shape
	_boss_view.queue_redraw()

## Cinematic bars (0 = none, 1 = full).
var _letterbox := 0.0
var _boss_bar_hidden := false
func set_boss_hidden(on: bool) -> void:
	_boss_bar_hidden = on
	_boss_view.queue_redraw()
func set_letterbox(amount: float) -> void:
	_letterbox = clampf(amount, 0.0, 1.0)
	_boss_view.queue_redraw()

func _paint_overlays() -> void:
	var font := ThemeDB.get_default_theme().default_font
	if _letterbox > 0.0:
		var bar := 78.0 * _letterbox
		_boss_view.draw_rect(Rect2(0, 0, 1280, bar), Color(0.02, 0.02, 0.04))
		_boss_view.draw_rect(Rect2(0, 720.0 - bar, 1280, bar), Color(0.02, 0.02, 0.04))
	if _boss_name != "" and not _boss_bar_hidden:
		var r := Rect2(340, 66, 600, 16)
		_boss_view.draw_rect(r.grow(4.0), Color(0, 0, 0, 0.45))
		_boss_view.draw_rect(Rect2(r.position, Vector2(r.size.x * _boss_frac, r.size.y)), Palette.CRITIC_RED)
		_boss_view.draw_rect(r, Palette.OUTLINE, false, 2.4)
		_boss_view.draw_string(font, Vector2(340, 56), _boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.PAPER_LIGHT)
	if not _clip_shape.is_empty():
		var base := Vector2(1130, 560)
		_boss_view.draw_rect(Rect2(base + Vector2(-20, -34), Vector2(130, 112)), Color(0, 0, 0, 0.4))
		_boss_view.draw_rect(Rect2(base + Vector2(-20, -34), Vector2(130, 112)), Palette.PAPER_LIGHT, false, 3.0)
		_boss_view.draw_string(font, base + Vector2(-8, -12), "Clipboard", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.PAPER_LIGHT)
		for o in _clip_shape:
			var tl: Vector2 = base + Vector2(10 + o.x * 24, 8 + o.y * 24)
			_boss_view.draw_rect(Rect2(tl, Vector2(22, 22)), Palette.PAGE)
			_boss_view.draw_rect(Rect2(tl, Vector2(22, 22)), Palette.OUTLINE, false, 2.0)
		_boss_view.draw_string(font, base + Vector2(-8, 72), "V: paste", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Palette.GOLD)
