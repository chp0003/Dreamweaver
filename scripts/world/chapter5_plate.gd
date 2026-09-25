class_name Chapter5Plate
extends Node2D

## Painted interior for the Final Stand at the Sacred Loom.
## Same UV rule as Chapter1Plate / Chapter4Plate: sprite centred, solids in local space.

const TEXTURE_PATH := "res://assets/images/environments/house_sacred/sacred_loom_hall.png"
const SHADER_PATH := "res://shaders/house_sacred_plate.gdshader"
const NATIVE := Vector2(1152.0, 864.0)
const FIT_WIDTH := 1536.0

const SPAWN_UV := Vector2(0.50, 0.78)
const EXIT_UV := Vector2(0.50, 0.90)
const LOOM_UV := Vector2(0.50, 0.34)
const LOOM_REACH_UV := Vector2(0.50, 0.54)
const GHOST_UV := Vector2(0.70, 0.48)
## Low enough that the tall six-armed silhouette remains inside the camera.
const BOSS_UV := Vector2(0.50, 0.58)
const VEIL_UV := Vector2(0.50, 0.46)

## Open wooden aisle and the ink-stain pools already painted on the floor.
const SPAWN_UVS: Array[Vector2] = [
	Vector2(0.34, 0.56),
	Vector2(0.66, 0.56),
	Vector2(0.38, 0.68),
	Vector2(0.62, 0.66),
	Vector2(0.50, 0.72),
	Vector2(0.30, 0.50),
	Vector2(0.70, 0.50),
	Vector2(0.42, 0.52),
	Vector2(0.58, 0.52),
	Vector2(0.50, 0.60),
]

@export var plate_scale := 1.0
@export var debug_draw_collision := false

var _sprite: Sprite2D
var _tex_size := NATIVE
var _solids: StaticBody2D
var _bounds: StaticBody2D
var _material: ShaderMaterial
var _ash: GPUParticles2D
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
	var fit := FIT_WIDTH / maxf(1.0, _tex_size.x)
	scale = Vector2(fit, fit)
	_sprite.scale = Vector2.ONE
	_apply_grade()
	add_child(_sprite)
	_add_edge_walls()
	_add_ash()
	_push_lights()
	queue_redraw()


func displayed_size() -> Vector2:
	return _tex_size


func world_rect() -> Rect2:
	var size := displayed_size()
	return Rect2(-size * 0.5, size)


func global_world_rect() -> Rect2:
	var rect := world_rect()
	if is_inside_tree():
		var top_left := to_global(rect.position)
		return Rect2(top_left, rect.size * absf(scale.x))
	return Rect2(global_position + rect.position * scale, rect.size * absf(scale.x))


func uv_to_world(uv: Vector2) -> Vector2:
	var size := displayed_size()
	return Vector2((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y)


func uv_to_global(uv: Vector2) -> Vector2:
	return to_global(uv_to_world(uv)) if is_inside_tree() else global_position + uv_to_world(uv)


func world_to_uv(world: Vector2) -> Vector2:
	var local := to_local(world) if is_inside_tree() else world - global_position
	var size := displayed_size()
	if size.x < 1.0 or size.y < 1.0:
		return Vector2(0.5, 0.5)
	return Vector2(local.x / size.x + 0.5, local.y / size.y + 0.5)


func spawn_world() -> Vector2:
	return uv_to_global(SPAWN_UV)


func exit_world() -> Vector2:
	return uv_to_global(EXIT_UV)


func loom_world() -> Vector2:
	return uv_to_global(LOOM_UV)


func loom_reach_world() -> Vector2:
	return uv_to_global(LOOM_REACH_UV)


func ghost_world() -> Vector2:
	return uv_to_global(GHOST_UV)


func boss_world() -> Vector2:
	return uv_to_global(BOSS_UV)


func veil_world() -> Vector2:
	return uv_to_global(VEIL_UV)


func spawn_point(index: int) -> Vector2:
	return uv_to_global(SPAWN_UVS[clampi(index, 0, SPAWN_UVS.size() - 1)])


func set_restore(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("restore", clampf(amount, 0.0, 1.0))
	if _ash != null:
		_ash.emitting = amount < 0.82


func set_sanctity(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("sanctity", clampf(amount, 0.0, 1.0))


func set_player_world(world_pos: Vector2) -> void:
	if _material != null:
		_material.set_shader_parameter("player_uv", world_to_uv(world_pos))


func set_loom_energy(energy: float) -> void:
	if _material != null:
		_material.set_shader_parameter("loom_energy", clampf(energy, 0.0, 2.0))


func bloom_restore(duration := 3.2) -> void:
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(set_restore, 0.0, 1.0, duration).set_ease(Tween.EASE_OUT)


func bloom_sanctity(to_value: float, duration := 1.4) -> void:
	if _material == null:
		return
	var from_value := 0.0
	var current: Variant = _material.get_shader_parameter("sanctity")
	if current is float or current is int:
		from_value = float(current)
	var tween := create_tween()
	tween.tween_method(set_sanctity, from_value, clampf(to_value, 0.0, 1.0), duration)\
		.set_ease(Tween.EASE_OUT)


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


func _push_lights() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("loom_uv", LOOM_UV)
	_material.set_shader_parameter("loom_energy", 0.12)
	_material.set_shader_parameter("player_uv", SPAWN_UV)
	_material.set_shader_parameter("player_radius", 0.22)
	_material.set_shader_parameter("restore", 0.0)
	_material.set_shader_parameter("sanctity", 0.0)


func _load_disk_image() -> Image:
	return Palette.read_image(TEXTURE_PATH)


func _load_texture(disk: Image) -> Texture2D:
	# Editor keeps the PNG on disk. The exported app reads the packed copy.
	var packed := Palette.read_texture(TEXTURE_PATH)
	if packed != null:
		return packed
	if disk != null:
		return ImageTexture.create_from_image(disk)
	push_warning("Chapter5Plate: missing %s" % TEXTURE_PATH)
	return null


func _apply_grade() -> void:
	var shader := load(SHADER_PATH)
	if shader is Shader:
		_material = ShaderMaterial.new()
		_material.shader = shader as Shader
		_sprite.material = _material


func _draw() -> void:
	if not debug_draw_collision:
		return
	for rect in _debug_rects:
		draw_rect(rect, Color(1.0, 0.15, 0.2, 0.28))
		draw_rect(rect, Color(1.0, 0.85, 0.2, 0.95), false, 1.5)


func _add_ash() -> void:
	_ash = GPUParticles2D.new()
	_ash.name = "HallAsh"
	_ash.z_index = 6
	_ash.amount = 48
	_ash.lifetime = 5.2
	_ash.preprocess = 2.4
	_ash.explosiveness = 0.0
	_ash.randomness = 0.85
	_ash.texture = _ash_dot()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(420.0, 260.0, 1.0)
	mat.direction = Vector3(0.08, -1.0, 0.0)
	mat.spread = 28.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3(6.0, -12.0, 0.0)
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = Color(0.22, 0.12, 0.14, 0.55)
	_ash.process_material = mat
	_ash.emitting = true
	add_child(_ash)


func _ash_dot() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var centre := Vector2(7.5, 7.5)
	for y in range(16):
		for x in range(16):
			var d := Vector2(x, y).distance_to(centre) / 8.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.7)))
	return ImageTexture.create_from_image(image)


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
	# Back wall and thatch. Centre aisle stays open for the Breach.
	_add_uv_box(Vector2(0.50, 0.12), Vector2(0.86, 0.16))
	# Sacred Loom frame — the hanging cloth is visual, feet are solid.
	_add_uv_box(Vector2(0.50, 0.34), Vector2(0.30, 0.16))
	# Gong shelf and chest on the right wall.
	_add_uv_box(Vector2(0.84, 0.38), Vector2(0.22, 0.22))
	# Porch gardens.
	_add_uv_box(Vector2(0.16, 0.86), Vector2(0.30, 0.24))
	_add_uv_box(Vector2(0.84, 0.84), Vector2(0.28, 0.28))
	_add_uv_box(Vector2(0.03, 0.50), Vector2(0.07, 0.90))
	_add_uv_box(Vector2(0.97, 0.50), Vector2(0.07, 0.90))
	# Porch rails, gap in the middle for the steps.
	_add_uv_box(Vector2(0.32, 0.70), Vector2(0.18, 0.07))
	_add_uv_box(Vector2(0.68, 0.70), Vector2(0.18, 0.07))


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
