class_name Chapter2Plate
extends Node2D

## Painted 16:9 interior for the House of Red Courage.
## Same UV rule as Chapter1Plate: sprite centred, solids in local space.

const TEXTURE_PATH := "res://assets/images/environments/house_red/red_courage_hall.png"
const SHADER_PATH := "res://shaders/house_red_plate.gdshader"
const NATIVE := Vector2(1536.0, 1152.0)

const SPAWN_UV := Vector2(0.50, 0.88)
const EXIT_UV := Vector2(0.50, 0.90)
const MORTAR_UV := Vector2(0.50, 0.32)
const MORTAR_REACH_UV := Vector2(0.50, 0.42)
const FLOWERS_UV := Vector2(0.78, 0.72)
## Left porch, beside the path. Clear of the steps and the right flower bed.
const QUEEN_UV := Vector2(0.28, 0.78)
const QUEEN_REACH_UV := Vector2(0.34, 0.82)
## Floor mark in the path between the two porch posts.
const BARRIER_UV := Vector2(0.50, 0.72)

## Full curtain from the left porch post to the right one.
const VINE_UVS: Array[Vector2] = [
	Vector2(0.37, 0.80),
	Vector2(0.43, 0.79),
	Vector2(0.50, 0.80),
	Vector2(0.57, 0.79),
	Vector2(0.63, 0.80),
]

## Open floor of the storage hall — aisles and the centre walk to the mortar.
const ROOT_UVS: Array[Vector2] = [
	Vector2(0.24, 0.42),
	Vector2(0.76, 0.42),
	Vector2(0.45, 0.38),
	Vector2(0.55, 0.38),
	Vector2(0.50, 0.50),
]

const MINION_UV := Vector2(0.50, 0.40)

@export var plate_scale := 1.0
@export var debug_draw_collision := false

var _sprite: Sprite2D
var _tex_size := NATIVE
var _solids: StaticBody2D
var _bounds: StaticBody2D
var _material: ShaderMaterial
var _debug_rects: Array[Rect2] = []


func _ready() -> void:
	z_index = -120
	z_as_relative = false
	scale = Vector2.ONE
	var disk := _load_disk_image()
	if disk != null:
		_tex_size = Vector2(disk.get_width(), disk.get_height())
	_sprite = Sprite2D.new()
	_sprite.name = "Plate"
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.texture = _load_texture(disk)
	if _sprite.texture != null and disk == null:
		_tex_size = _sprite.texture.get_size()
	_sprite.scale = Vector2(plate_scale, plate_scale)
	_apply_grade()
	add_child(_sprite)
	_add_edge_walls()
	# Interior solids are drawn in scenes/world/House2Collision.tscn — same as
	# House1Collision / HubCollision: traced polygons, not axis-aligned boxes.
	queue_redraw()


func displayed_size() -> Vector2:
	return _tex_size * plate_scale


func world_rect() -> Rect2:
	var size := displayed_size()
	return Rect2(-size * 0.5, size)


func global_world_rect() -> Rect2:
	var rect := world_rect()
	return Rect2(global_position + rect.position, rect.size)


func uv_to_world(uv: Vector2) -> Vector2:
	var size := displayed_size()
	return Vector2((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y)


func uv_to_global(uv: Vector2) -> Vector2:
	return to_global(uv_to_world(uv)) if is_inside_tree() else global_position + uv_to_world(uv)


func spawn_world() -> Vector2:
	return uv_to_global(SPAWN_UV)


func mortar_world() -> Vector2:
	return uv_to_global(MORTAR_UV)


func mortar_reach_world() -> Vector2:
	return uv_to_global(MORTAR_REACH_UV)


func flowers_world() -> Vector2:
	return uv_to_global(FLOWERS_UV)


func queen_world() -> Vector2:
	return uv_to_global(QUEEN_UV)


func queen_reach_world() -> Vector2:
	return uv_to_global(QUEEN_REACH_UV)


func exit_world() -> Vector2:
	return uv_to_global(EXIT_UV)


func barrier_world() -> Vector2:
	return uv_to_global(BARRIER_UV)


func vine_world(index: int) -> Vector2:
	var uv: Vector2 = VINE_UVS[clampi(index, 0, VINE_UVS.size() - 1)]
	return uv_to_global(uv)


func minion_world() -> Vector2:
	return uv_to_global(MINION_UV)


func set_restore(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("restore", clampf(amount, 0.0, 1.0))


func bloom_restore(duration := 3.2) -> void:
	Fx.restoration_sparkle(self)
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(set_restore, 0.0, 1.0, duration).set_ease(Tween.EASE_OUT)


func attach_solids(host: Node2D) -> void:
	if host == null:
		return
	for body in [_bounds, _solids]:
		if body == null or not is_instance_valid(body):
			continue
		var xf: Transform2D = body.global_transform
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		host.add_child(body)
		body.global_transform = xf


func add_fallback_solids() -> void:
	if _solids != null:
		return
	_add_solids()


func _load_disk_image() -> Image:
	return Palette.read_image(TEXTURE_PATH)


func _load_texture(disk: Image) -> Texture2D:
	var packed := Palette.read_texture(TEXTURE_PATH)
	if packed != null:
		return packed
	if disk != null:
		return ImageTexture.create_from_image(disk)
	push_warning("Chapter2Plate: missing %s" % TEXTURE_PATH)
	return null


func _apply_grade() -> void:
	var shader := load(SHADER_PATH)
	if shader is Shader:
		_material = ShaderMaterial.new()
		_material.shader = shader as Shader
		_material.set_shader_parameter("restore", 0.0)
		_sprite.material = _material


func _draw() -> void:
	if not debug_draw_collision:
		return
	for rect in _debug_rects:
		draw_rect(rect, Color(1.0, 0.15, 0.2, 0.28))
		draw_rect(rect, Color(1.0, 0.85, 0.2, 0.95), false, 1.5)


func _add_edge_walls() -> void:
	var rect := world_rect()
	_bounds = StaticBody2D.new()
	_bounds.name = "PlateBounds"
	_bounds.position = Vector2.ZERO
	_bounds.collision_layer = PhysicsLayers.LAYER_WORLD
	_bounds.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	var thick := 48.0
	var pads: Array[Rect2] = [
		Rect2(rect.position.x - thick, rect.position.y - thick, rect.size.x + thick * 2.0, thick),
		Rect2(rect.position.x - thick, rect.end.y, rect.size.x + thick * 2.0, thick),
		Rect2(rect.position.x - thick, rect.position.y, thick, rect.size.y),
		Rect2(rect.end.x, rect.position.y, thick, rect.size.y),
	]
	for pad in pads:
		_add_rect_shape(_bounds, pad)
	add_child(_bounds)


func _add_solids() -> void:
	_solids = StaticBody2D.new()
	_solids.name = "HallSolids"
	_solids.position = Vector2.ZERO
	_solids.collision_layer = PhysicsLayers.LAYER_WORLD
	_solids.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	add_child(_solids)
	_add_uv_box(Vector2(0.50, 0.12), Vector2(0.90, 0.14))
	_add_uv_box(Vector2(0.50, 0.30), Vector2(0.16, 0.12))
	_add_uv_box(Vector2(0.34, 0.46), Vector2(0.12, 0.16))
	_add_uv_box(Vector2(0.66, 0.46), Vector2(0.12, 0.16))
	_add_uv_box(Vector2(0.12, 0.38), Vector2(0.16, 0.24))
	_add_uv_box(Vector2(0.88, 0.40), Vector2(0.16, 0.28))
	_add_uv_box(Vector2(0.16, 0.84), Vector2(0.32, 0.28))
	_add_uv_box(Vector2(0.84, 0.80), Vector2(0.30, 0.34))
	_add_uv_box(Vector2(0.02, 0.50), Vector2(0.06, 0.96))
	_add_uv_box(Vector2(0.98, 0.50), Vector2(0.06, 0.96))
	_add_uv_box(Vector2(0.28, 0.62), Vector2(0.18, 0.07))
	_add_uv_box(Vector2(0.72, 0.62), Vector2(0.18, 0.07))


func _add_uv_box(uv_centre: Vector2, uv_size: Vector2) -> void:
	var half := uv_size * 0.5
	var a := uv_to_world(uv_centre - half)
	var b := uv_to_world(uv_centre + half)
	var rect := Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(b.x - a.x), absf(b.y - a.y))
	)
	_add_rect_shape(_solids, rect)


func _add_rect_shape(body: StaticBody2D, rect: Rect2) -> void:
	if body == null or rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.disabled = false
	body.add_child(shape)
	_debug_rects.append(rect)
