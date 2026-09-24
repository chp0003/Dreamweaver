class_name Chapter1Plate
extends Node2D
## Painted 16:9 interior for the House of the Black Foundation.
## Same UV rule as TutorialPlate / HubPlate: sprite centred, solids in local space.

const TEXTURE_PATH := "res://assets/images/environments/house_black/black_foundation_hall.png"
const SHADER_PATH := "res://shaders/house_black_plate.gdshader"
const NATIVE := Vector2(1536.0, 1024.0)

const SPAWN_UV := Vector2(0.50, 0.66)
## Open floor to the right of the painted loom — not on the seat.
const SPIRIT_UV := Vector2(0.40, 0.58)
const SPIRIT_REACH_UV := Vector2(0.40, 0.60)
const CHIEF_UV := Vector2(0.26, 0.58)
const CHIEF_REACH_UV := Vector2(0.26, 0.60)
const RACK_UV := Vector2(0.50, 0.30)
const RACK_REACH_UV := Vector2(0.50, 0.40)
const VAT_UV := Vector2(0.78, 0.38)
const VAT_REACH_UV := Vector2(0.72, 0.46)
const EXIT_UV := Vector2(0.50, 0.88)

## Spread across the walkable diamond of House1Collision (hall + garden path).
## Inset ~40px from wall / loom / shelf / planter edges.
const HALL_STRAND_UVS: Array[Vector2] = [
	Vector2(0.30, 0.54),
	Vector2(0.42, 0.38),
	Vector2(0.58, 0.38),
	Vector2(0.70, 0.46),
	Vector2(0.50, 0.52),
]
const GARDEN_STRAND_UVS: Array[Vector2] = [
	Vector2(0.40, 0.64),
	Vector2(0.60, 0.64),
	Vector2(0.40, 0.84),
	Vector2(0.60, 0.86),
	Vector2(0.50, 0.86),
]

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
	# Interior walls are drawn in scenes/world/House1Collision.tscn — same as HubCollision.
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


func spirit_world() -> Vector2:
	return uv_to_global(SPIRIT_UV)


func spirit_reach_world() -> Vector2:
	return uv_to_global(SPIRIT_REACH_UV)


func chief_world() -> Vector2:
	return uv_to_global(CHIEF_UV)


func chief_reach_world() -> Vector2:
	return uv_to_global(CHIEF_REACH_UV)


func rack_world() -> Vector2:
	return uv_to_global(RACK_UV)


func rack_reach_world() -> Vector2:
	return uv_to_global(RACK_REACH_UV)


func vat_world() -> Vector2:
	return uv_to_global(VAT_UV)


func vat_reach_world() -> Vector2:
	return uv_to_global(VAT_REACH_UV)


func exit_world() -> Vector2:
	return uv_to_global(EXIT_UV)


func set_restore(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("restore", clampf(amount, 0.0, 1.0))


func bloom_restore(duration := 3.2) -> void:
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


func _load_disk_image() -> Image:
	var disk := ProjectSettings.globalize_path(TEXTURE_PATH)
	if not FileAccess.file_exists(disk):
		return null
	var image := Image.new()
	if image.load(disk) != OK:
		return null
	return image


func _load_texture(disk: Image) -> Texture2D:
	if ResourceLoader.exists(TEXTURE_PATH):
		var loaded := load(TEXTURE_PATH)
		if loaded is Texture2D:
			return loaded as Texture2D
	if disk != null:
		return ImageTexture.create_from_image(disk)
	push_warning("Chapter1Plate: missing %s" % TEXTURE_PATH)
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
	# Back wall and hanging rack — leave the aisle open.
	_add_uv_box(Vector2(0.50, 0.16), Vector2(0.72, 0.14))
	# Loom and baskets, left of the spirit's sitting mat.
	_add_uv_box(Vector2(0.13, 0.38), Vector2(0.16, 0.20))
	# Vat, jars, and chest along the right wall.
	_add_uv_box(Vector2(0.88, 0.40), Vector2(0.16, 0.26))
	# Garden beds — centre path stays clear so the porch is reachable.
	_add_uv_box(Vector2(0.14, 0.84), Vector2(0.22, 0.18))
	_add_uv_box(Vector2(0.86, 0.84), Vector2(0.18, 0.16))
	_add_uv_box(Vector2(0.04, 0.52), Vector2(0.08, 0.72))
	_add_uv_box(Vector2(0.96, 0.52), Vector2(0.08, 0.72))


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
