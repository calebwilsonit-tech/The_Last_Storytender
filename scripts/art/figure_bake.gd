class_name FigureBake
extends Node
## Ink Cel figures are made of dozens of shapes (about 150 drawing commands each). That is fine for one
## figure and too much for a town full of them on integrated graphics. So each distinct pose of a figure
## is painted ONCE into a small texture, and every later frame draws that one picture. A pose is the
## figure's description rounded to what the eye can tell apart: facing in 8 steps, walk phase in 8,
## time-based idle motion in 12 steps, effects in eighths. The first time a pose is seen it is drawn the
## normal way while its picture is made (about two frames), so nothing ever flashes or goes missing.
##
## Gameplay overlays (health, labels, telegraphs) are never baked; they stay in the entity scripts.

const SCALE := 2.0                 # baked at 2x so the lines stay crisp
const BUDGET_BYTES := 140_000_000
const T_LOOP := 3.1416
const T_STEPS := 12
const IGNORE := ["origin", "scale", "hp"]

## Frame (world pixels) and where the feet sit inside it, per kind. Anything not listed uses DEFAULT.
const DEFAULT := {"size": Vector2(112, 112), "foot": Vector2(56, 92)}
const FRAMES := {
	"storytender": {"size": Vector2(136, 124), "foot": Vector2(68, 98)},
	"prop_house": {"size": Vector2(180, 184), "foot": Vector2(90, 146)},
	"prop_oven": {"size": Vector2(150, 150), "foot": Vector2(75, 122)},
	"prop_gate": {"size": Vector2(112, 130), "foot": Vector2(56, 114)},
}
## Props that are worth baking (still or nearly so). Animated ones with big moving parts draw directly.
const BAKE_PROPS := ["prop_house", "prop_sign", "prop_post", "prop_block", "prop_chair", "prop_oven", "prop_gate", "prop_chest", "prop_plate", "prop_echoplate"]

static var instance: FigureBake
static var enabled := true

var _entries: Dictionary = {}      # key -> {vp, tex, ready, ok, bytes, last, size, foot}
var _bytes := 0

static func _host(ci: CanvasItem) -> FigureBake:
	if instance == null or not is_instance_valid(instance):
		instance = FigureBake.new()
		instance.name = "FigureBake"
		ci.get_tree().root.add_child.call_deferred(instance)
		Settings.quality_changed.connect(instance.clear)
	return instance

## Draws `kind` through `art` at ctx.origin using a baked picture when one is ready. Returns what
## art.draw_character would have returned.
static func draw_prop(art: ArtStyle, ci: CanvasItem, kind: String, ctx: Dictionary) -> bool:
	if not BAKE_PROPS.has(kind):
		return art.draw_prop(ci, kind, ctx)
	return draw(art, ci, kind, ctx)

static func _paint(art: ArtStyle, ci: CanvasItem, kind: String, ctx: Dictionary) -> bool:
	return art.draw_prop(ci, kind, ctx) if kind.begins_with("prop_") else art.draw_character(ci, kind, ctx)

static func draw(art: ArtStyle, ci: CanvasItem, kind: String, ctx: Dictionary) -> bool:
	if not enabled or not ci.is_inside_tree():
		return _paint(art, ci, kind, ctx)
	var host := _host(ci)
	if not host.is_inside_tree():
		return _paint(art, ci, kind, ctx)
	var q := _quantize(kind, ctx)
	var key: String = q["key"]
	var e = host._entries.get(key)
	var frame := Engine.get_process_frames()
	if e == null:
		host._bake(art, kind, q["ctx"], key)
		return _paint(art, ci, kind, ctx)
	e["last"] = frame
	if frame < int(e["ready"]):
		return _paint(art, ci, kind, ctx)
	if not e["ok"]:
		return false
	var org: Vector2 = ctx.get("origin", Vector2.ZERO)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_texture_rect(e["tex"], Rect2(org - Vector2(e["foot"]), Vector2(e["size"])), false)
	ci.draw_set_transform(org, 0.0, Vector2.ONE)
	return true

func clear() -> void:
	for k in _entries:
		var vp = _entries[k]["vp"]
		if is_instance_valid(vp):
			vp.queue_free()
	_entries.clear()
	_bytes = 0

func _bake(art: ArtStyle, kind: String, ctx: Dictionary, key: String) -> void:
	var fr: Dictionary = FRAMES.get(kind, DEFAULT)
	var size: Vector2 = fr["size"]
	var foot: Vector2 = fr["foot"]
	var bytes := int(size.x * size.y * SCALE * SCALE * 4.0)
	_evict(bytes)
	var vp := SubViewport.new()
	vp.size = Vector2i(size * SCALE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := FigurePainter.new()
	var c := ctx.duplicate()
	c["origin"] = foot * SCALE
	c["scale"] = SCALE
	painter.art = art
	painter.kind = kind
	painter.ctx = c
	vp.add_child(painter)
	add_child(vp)
	var e := {"vp": vp, "tex": vp.get_texture(), "ready": Engine.get_process_frames() + 3, "ok": true,
		"bytes": bytes, "last": Engine.get_process_frames(), "size": size, "foot": foot}
	painter.entry = e
	_entries[key] = e
	_bytes += bytes

func _evict(need: int) -> void:
	if _bytes + need <= BUDGET_BYTES:
		return
	var keys := _entries.keys()
	keys.sort_custom(func(a, b): return _entries[a]["last"] < _entries[b]["last"])
	var frame := Engine.get_process_frames()
	for k in keys:
		if _bytes + need <= BUDGET_BYTES * 0.8:
			break
		var e: Dictionary = _entries[k]
		if frame - int(e["last"]) < 120:
			continue
		if is_instance_valid(e["vp"]):
			e["vp"].queue_free()
		_bytes -= int(e["bytes"])
		_entries.erase(k)

## Rounds a ctx to the poses the eye can tell apart. Returns {key, ctx}: the cache key, and the ctx the
## baked picture should be painted with (so a picture is exactly what its key says).
static func _quantize(kind: String, ctx: Dictionary) -> Dictionary:
	var parts: Array = [kind]
	var qc := {}
	var keys := ctx.keys()
	keys.sort()
	for k in keys:
		if IGNORE.has(k):
			continue
		var v = ctx[k]
		match typeof(v):
			TYPE_FLOAT:
				if k == "t":
					if ctx.get("moving", false):
						parts.append(-1)       # a walking pose is set by its phase, not the clock
						qc[k] = 0.0
						continue
					var tb := int(fposmod(v, T_LOOP) / T_LOOP * T_STEPS) % T_STEPS
					parts.append(tb)
					qc[k] = tb * T_LOOP / T_STEPS
				elif k == "phase":
					var pb := int(round(fposmod(v, TAU) / TAU * 8.0)) % 8
					parts.append(pb)
					qc[k] = pb * TAU / 8.0
				elif k == "seed":
					var sb := int(fposmod(absf(v), 1.0) * 4.0)
					parts.append(sb)
					qc[k] = sb * 1.7 + 0.3
				elif k == "flick":
					var fb := int(round(v * 2.0))
					parts.append(fb)
					qc[k] = fb / 2.0
				elif k == "invuln":
					parts.append(v > 0.0)
					qc[k] = v
				else:
					var b := int(round(v * 8.0))
					parts.append(b)
					qc[k] = b / 8.0
			TYPE_VECTOR2:
				var ang := fposmod(atan2(v.y, v.x), TAU)
				var ab := int(round(ang / TAU * 8.0)) % 8
				parts.append(ab)
				qc[k] = Vector2.from_angle(ab * TAU / 8.0)
			TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
				parts.append(v)
				qc[k] = v
			_:
				parts.append(str(v))
				qc[k] = v
	return {"key": "|".join(parts.map(func(p): return str(p))), "ctx": qc}


## Paints one figure into its viewport.
class FigurePainter extends Node2D:
	var art: ArtStyle
	var kind := ""
	var ctx: Dictionary = {}
	var entry: Dictionary = {}

	func _draw() -> void:
		var ok := FigureBake._paint(art, self, kind, ctx)
		if not entry.is_empty():
			entry["ok"] = ok
