class_name Chapter3Plate
extends Node2D

## Painted 16:9 interior for the House of the Golden Sun.
## Same UV rule as Chapter1Plate / Chapter2Plate: sprite centred, solids in local space.

const TEXTURE_PATH := "res://assets/images/environments/house_gold/golden_sun_hall.png"
const SHADER_PATH := "res://shaders/house_gold_plate.gdshader"
const NATIVE := Vector2(1152.0, 864.0)
const FIT_WIDTH := 1536.0

const SPAWN_UV := Vector2(0.50, 0.72)
const EXIT_UV := Vector2(0.50, 0.90)
const SPINDLE_UV := Vector2(0.50, 0.34)
const SPINDLE_REACH_UV := Vector2(0.50, 0.44)
const EMITTER_UV := Vector2(0.22, 0.32)
const PUZZLE_STEP := Vector2(0.07, 0.07)

const TORCH_UVS: Array[Vector2] = [
	Vector2(0.26, 0.28),
	Vector2(0.74, 0.28),
]

const MIRROR_CELLS: Array[Vector2i] = [
	Vector2i(2, 0),
	Vector2i(2, 2),
	Vector2i(6, 2),
	Vector2i(6, 0),
]
const SPINDLE_CELL := Vector2i(4, 0)
const EMITTER_CELL := Vector2i(0, 0)

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
	var fit := FIT_WIDTH / maxf(1.0, _tex_size.x)
	scale = Vector2(fit, fit)
	_sprite.scale = Vector2.ONE
	_apply_grade()
	add_child(_sprite)
	var ambience := HouseAmbience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	_add_edge_walls()
	_push_torch_uvs()
	# Interior solids are drawn in scenes/world/House3Collision.tscn — same as
	# House1Collision / HubCollision: traced polygons, not axis-aligned boxes.
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


func spindle_world() -> Vector2:
	return uv_to_global(SPINDLE_UV)


func spindle_reach_world() -> Vector2:
	return uv_to_global(SPINDLE_REACH_UV)


func emitter_world() -> Vector2:
	return uv_to_global(EMITTER_UV)


func torch_world(index: int) -> Vector2:
	var uv: Vector2 = TORCH_UVS[clampi(index, 0, TORCH_UVS.size() - 1)]
	return uv_to_global(uv)


func puzzle_uv(cell: Vector2i) -> Vector2:
	return Vector2(
		EMITTER_UV.x + float(cell.x) * PUZZLE_STEP.x,
		EMITTER_UV.y + float(cell.y) * PUZZLE_STEP.y
	)


func puzzle_world(cell: Vector2i) -> Vector2:
	return uv_to_global(puzzle_uv(cell))


func set_restore(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("restore", clampf(amount, 0.0, 1.0))


func set_veil(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("veil", clampf(amount, 0.0, 1.0))


func set_player_world(world_pos: Vector2) -> void:
	if _material != null:
		_material.set_shader_parameter("player_uv", world_to_uv(world_pos))


func set_torch_energy(index: int, energy: float) -> void:
	if _material == null:
		return
	var values := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var current: Variant = _material.get_shader_parameter("torch_energy")
	if current is PackedFloat32Array and (current as PackedFloat32Array).size() >= 4:
		values = current
	elif current is Array:
		for i in mini(4, (current as Array).size()):
			values[i] = float((current as Array)[i])
	if index >= 0 and index < 4:
		values[index] = clampf(energy, 0.0, 1.5)
	_material.set_shader_parameter("torch_energy", values)


func bloom_restore(duration := 3.2) -> void:
	Fx.restoration_sparkle(self)
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(set_restore, 0.0, 1.0, duration).set_ease(Tween.EASE_OUT)


func bloom_veil_out(duration := 1.6) -> void:
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(set_veil, 1.0, 0.0, duration).set_ease(Tween.EASE_OUT)


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


func _push_torch_uvs() -> void:
	if _material == null:
		return
	var uvs := PackedVector2Array()
	for uv in TORCH_UVS:
		uvs.append(uv)
	while uvs.size() < 4:
		uvs.append(Vector2.ZERO)
	_material.set_shader_parameter("torch_uvs", uvs)
	_material.set_shader_parameter("torch_energy", PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
	_material.set_shader_parameter("player_uv", SPAWN_UV)
	_material.set_shader_parameter("veil", 1.0)
	_material.set_shader_parameter("restore", 0.0)


func _load_disk_image() -> Image:
	return Palette.read_image(TEXTURE_PATH)


func _load_texture(disk: Image) -> Texture2D:
	var packed := Palette.read_texture(TEXTURE_PATH)
	if packed != null:
		return packed
	if disk != null:
		return ImageTexture.create_from_image(disk)
	push_warning("Chapter3Plate: missing %s" % TEXTURE_PATH)
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
	_add_uv_box(Vector2(0.50, 0.11), Vector2(0.90, 0.16))
	_add_uv_box(Vector2(0.50, 0.34), Vector2(0.14, 0.14))
	_add_uv_box(Vector2(0.18, 0.40), Vector2(0.16, 0.22))
	_add_uv_box(Vector2(0.86, 0.38), Vector2(0.18, 0.26))
	_add_uv_box(Vector2(0.16, 0.84), Vector2(0.32, 0.28))
	_add_uv_box(Vector2(0.84, 0.82), Vector2(0.30, 0.32))
	_add_uv_box(Vector2(0.02, 0.50), Vector2(0.06, 0.96))
	_add_uv_box(Vector2(0.98, 0.50), Vector2(0.06, 0.96))
	_add_uv_box(Vector2(0.32, 0.62), Vector2(0.18, 0.07))
	_add_uv_box(Vector2(0.68, 0.62), Vector2(0.18, 0.07))


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
