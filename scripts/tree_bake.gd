class_name TreeBake
extends Node
## A tree is about 70 drawing commands. A forest of them is thousands per frame, which is what makes
## the orchard slow on integrated graphics. So each tree look (3 sizes x 4 variations) is painted
## once into a small texture at double resolution, and every tree then draws that one picture.
## Sway is a gentle skew of the picture. Unbaked trees (the first frame or two) draw the old way.

const SIZE := Vector2i(110, 130)        # in world pixels
const SCALE := 2.0                      # bake at 2x for crisp lines when the camera zooms in
const BASE := Vector2(55.0, 110.0)      # where the tree's foot sits inside the picture
const BUCKETS := 4

static var instance: TreeBake
var _tex: Dictionary = {}               # "variant_bucket" -> Texture2D
var ready_flag := false
var _vps: Array = []

static func ensure(host: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		instance = TreeBake.new()
		instance.name = "TreeBake"
		host.get_tree().root.add_child.call_deferred(instance)

static func texture(variant: int, bucket: int) -> Texture2D:
	if instance == null or not is_instance_valid(instance) or not instance.ready_flag:
		return null
	return instance._tex.get("%d_%d" % [variant, bucket], null)

func _ready() -> void:
	for v in 3:
		for b in BUCKETS:
			var vp := SubViewport.new()
			vp.size = Vector2i(Vector2(SIZE) * SCALE)
			vp.transparent_bg = true
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(vp)
			_vps.append(vp)
			var painter := Prop.new()
			painter.kind = Prop.Kind.TREE
			painter.variant = v
			painter.baking = true
			painter.bake_seed = float(b) * 7.31 + 0.6
			painter.position = BASE
			painter.scale = Vector2(SCALE, SCALE)
			# the node sits at BASE scaled; position is in the (scaled) parent space
			painter.position = BASE * SCALE
			vp.add_child(painter)
			_tex["%d_%d" % [v, b]] = vp.get_texture()
	Settings.quality_changed.connect(_rebake)
	# the pictures are ready a couple of frames from now
	await get_tree().process_frame
	await get_tree().process_frame
	ready_flag = true

func _rebake() -> void:
	for vp: SubViewport in _vps:
		for c in vp.get_children():
			c.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
