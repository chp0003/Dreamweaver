class_name HubPlate
extends Node2D
## Painted 16:9 village plate for the hub. One Sprite2D — never tiled.
## Collision lives on this node (not on overlay sprites) so roofs, the totem
## and the river actually block S'lang.

const TEXTURE_PATH := "res://assets/images/hub_crossroads/hub_background.png"
const CURSED_PATH := "res://assets/images/hub_crossroads/hub_background_cursed.png"
const SHADER_PATH := "res://shaders/hub_plate.gdshader"
const NATIVE := Vector2(1536.0, 1024.0)
const PLAZA_UV := Vector2(0.50, 0.52)
const SPAWN_UV := Vector2(0.50, 0.61)

@export var plate_scale := 1.0

var _sprite: Sprite2D
var _tex_size := NATIVE
var _solids: StaticBody2D
var _material: ShaderMaterial


func _ready() -> void:
	z_index = -120
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.name = "Plate"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.texture = _load_texture(TEXTURE_PATH)
	if _sprite.texture != null:
		_tex_size = _sprite.texture.get_size()
	_sprite.scale = Vector2(plate_scale, plate_scale)
	_apply_curse_material()
	add_child(_sprite)
	_add_edge_walls()
	_add_solids()
	sync_restoration()


func displayed_size() -> Vector2:
	return _tex_size * plate_scale


func world_rect() -> Rect2:
	var size := displayed_size()
	return Rect2(-size * 0.5, size)


func uv_to_world(uv: Vector2) -> Vector2:
	var size := displayed_size()
	return Vector2((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y)


func plaza_world() -> Vector2:
	return uv_to_world(PLAZA_UV)


func spawn_world() -> Vector2:
	return uv_to_world(SPAWN_UV)


func world_to_uv(world: Vector2) -> Vector2:
	var size := displayed_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return PLAZA_UV
	return Vector2(world.x / size.x + 0.5, world.y / size.y + 0.5)


func sync_restoration(player: Node2D = null) -> void:
	if _material == null:
		return
	if GameState.game_completed:
		_material.set_shader_parameter("curse", 0.0)
		_material.set_shader_parameter("zone_count", 0)
		return
	_material.set_shader_parameter("curse", 1.0)
	var packed := PackedVector4Array()
	for house in Houses.LIST:
		var house_id := int(house["id"])
		if not GameState.is_house_completed(house_id):
			continue
		var uv: Vector2 = house.get("hub_uv", PLAZA_UV)
		packed.append(Vector4(uv.x, uv.y, 0.36, 0.96))
	if player != null and is_instance_valid(player):
		var puv := world_to_uv(player.global_position)
		packed.append(Vector4(puv.x, puv.y, 0.035, 0.35))
	_material.set_shader_parameter("zones", packed)
	_material.set_shader_parameter("zone_count", packed.size())


func set_ridge_active(on: bool) -> void:
	visible = on
	var layer := PhysicsLayers.LAYER_WORLD if on else 0
	var bounds := get_node_or_null("PlateBounds") as StaticBody2D
	if bounds != null:
		bounds.collision_layer = layer
	if _solids != null:
		_solids.collision_layer = layer


func _load_texture(path: String = TEXTURE_PATH) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var disk := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(disk):
		var image := Image.new()
		if image.load(disk) == OK:
			return ImageTexture.create_from_image(image)
	push_warning("HubPlate: missing %s" % path)
	return null


func _apply_curse_material() -> void:
	var shader := load(SHADER_PATH)
	if shader is Shader:
		_material = ShaderMaterial.new()
		_material.shader = shader as Shader
		_material.set_shader_parameter("cursed_tex", _load_texture(CURSED_PATH))
		_material.set_shader_parameter("curse", 1.0)
		_sprite.material = _material


func _process(_delta: float) -> void:
	if not visible or _material == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	sync_restoration(p)


func _add_edge_walls() -> void:
	var rect := world_rect()
	var body := StaticBody2D.new()
	body.name = "PlateBounds"
	body.collision_layer = PhysicsLayers.LAYER_WORLD
	body.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	var thick := 48.0
	var pads: Array[Rect2] = [
		Rect2(rect.position.x - thick, rect.position.y - thick, rect.size.x + thick * 2.0, thick),
		Rect2(rect.position.x - thick, rect.end.y, rect.size.x + thick * 2.0, thick),
		Rect2(rect.position.x - thick, rect.position.y, thick, rect.size.y),
		Rect2(rect.end.x, rect.position.y, thick, rect.size.y),
	]
	for pad in pads:
		_add_rect_shape(body, pad)
	add_child(body)


func _add_solids() -> void:
	_solids = StaticBody2D.new()
	_solids.name = "HubSolids"
	_solids.collision_layer = PhysicsLayers.LAYER_WORLD
	_solids.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	add_child(_solids)

	# Full painted silhouettes (roof + walls). UV boxes are centre + size.
	_add_uv_box(Vector2(0.50, 0.20), Vector2(0.18, 0.24)) # Golden Sun (north)
	_add_uv_box(Vector2(0.27, 0.34), Vector2(0.16, 0.22)) # Green Sun (northwest)
	_add_uv_box(Vector2(0.73, 0.34), Vector2(0.16, 0.22)) # Dream Ancestors (northeast)
	_add_uv_box(Vector2(0.28, 0.70), Vector2(0.16, 0.22)) # Black Foundation (southwest)
	_add_uv_box(Vector2(0.72, 0.70), Vector2(0.16, 0.22)) # Red Courage (southeast)
	_add_uv_circle(Vector2(0.50, 0.49), 0.032) # centre totem

	# River / lagoon. Gap at bottom-centre keeps the wooden pier walkable.
	_add_uv_box(Vector2(0.08, 0.50), Vector2(0.16, 1.00)) # left water
	_add_uv_box(Vector2(0.92, 0.50), Vector2(0.16, 1.00)) # right water
	_add_uv_box(Vector2(0.22, 0.08), Vector2(0.36, 0.16)) # top-left waterfall
	_add_uv_box(Vector2(0.78, 0.08), Vector2(0.36, 0.16)) # top-right waterfall
	_add_uv_box(Vector2(0.22, 0.90), Vector2(0.36, 0.20)) # bottom-left water
	_add_uv_box(Vector2(0.78, 0.90), Vector2(0.36, 0.20)) # bottom-right water
	_add_uv_box(Vector2(0.50, 0.97), Vector2(0.28, 0.08)) # far south water under the pier


func _add_uv_box(uv_centre: Vector2, uv_size: Vector2) -> void:
	var half := uv_size * 0.5
	var a := uv_to_world(uv_centre - half)
	var b := uv_to_world(uv_centre + half)
	var rect := Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(b.x - a.x), absf(b.y - a.y))
	)
	_add_rect_shape(_solids, rect)


func _add_uv_circle(uv_centre: Vector2, uv_radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = uv_radius * displayed_size().x
	shape.shape = circle
	shape.position = uv_to_world(uv_centre)
	_solids.add_child(shape)


func _add_rect_shape(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
