class_name ShadowFx
extends RefCounted
## Sprite-sheet VFX for the shadow minions and the Shadow Weaver.
## Sheets are 8 equal cells packed by tools/pack_shadow_sheets.gd.

const HIT_SPARK := "res://assets/images/vfx/shadow_hit_spark.png"
const CLAW_SWIPE := "res://assets/images/vfx/minion_claw_swipe.png"
const BOLT_IMPACT := "res://assets/images/vfx/weaver_bolt_impact.png"
const CHARGE := "res://assets/images/vfx/weaver_charge_gather.png"
const DASH_BURST := "res://assets/images/vfx/weaver_dash_burst.png"
const STUN_STARS := "res://assets/images/vfx/weaver_stun_stars.png"
const SUMMON_PORTAL := "res://assets/images/vfx/weaver_summon_portal.png"
const SHADOW_BOLT := "res://assets/images/vfx/weaver_shadow_bolt.png"

const FRAMES := 8

static var _cache: Dictionary = {}
static var _additive: CanvasItemMaterial


## One-shot effect parented to `host` at a world position. Frees itself.
static func burst(host: Node, path: String, world_pos: Vector2, fps := 18.0,
		scale := Vector2.ONE, rotation := 0.0, z := 20) -> AnimatedSprite2D:
	if host == null or not host.is_inside_tree():
		return null
	var fx := _make(path, fps, false)
	if fx == null:
		return null
	fx.scale = scale
	fx.rotation = rotation
	fx.z_index = z
	host.add_child(fx)
	fx.global_position = world_pos
	fx.play(&"play")
	fx.animation_finished.connect(fx.queue_free)
	return fx


## Effect that follows `parent`. Looping ones stay until the caller frees them.
static func attach(parent: Node2D, path: String, local_pos: Vector2, fps := 12.0,
		loop := false, scale := Vector2.ONE, z := 20) -> AnimatedSprite2D:
	var fx := _make(path, fps, loop)
	if fx == null or parent == null:
		return null
	fx.position = local_pos
	fx.scale = scale
	fx.z_index = z
	parent.add_child(fx)
	fx.play(&"play")
	if not loop:
		fx.animation_finished.connect(fx.queue_free)
	return fx


static func frames(path: String, fps := 12.0, loop := false) -> SpriteFrames:
	var textures := _textures(path)
	if textures.is_empty():
		return null
	var sprite_frames := SpriteFrames.new()
	sprite_frames.set_animation_speed(&"default", fps)
	sprite_frames.set_animation_loop(&"default", loop)
	sprite_frames.rename_animation(&"default", &"play")
	for texture in textures:
		sprite_frames.add_frame(&"play", texture)
	return sprite_frames


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func _make(path: String, fps: float, loop: bool) -> AnimatedSprite2D:
	var sprite_frames := frames(path, fps, loop)
	if sprite_frames == null:
		return null
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = sprite_frames
	fx.centered = true
	fx.material = additive()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return fx


static func _textures(path: String) -> Array[Texture2D]:
	if _cache.has(path):
		return _cache[path]
	var result: Array[Texture2D] = []
	var sheet := Palette.read_image(path)
	if sheet != null and sheet.get_width() >= FRAMES:
		var cell_w := sheet.get_width() / FRAMES
		for i in range(FRAMES):
			var cell := sheet.get_region(Rect2i(i * cell_w, 0, cell_w, sheet.get_height()))
			result.append(ImageTexture.create_from_image(cell))
	_cache[path] = result
	return result
