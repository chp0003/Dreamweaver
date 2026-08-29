class_name HubPlate
extends Node2D
## Painted 16:9 village plate. Sprite2D is the picture; StaticBody2D children
## are the solids. UV (0,0) is the top-left of the centred sprite.

const TEXTURE_PATH := "res://assets/images/hub_crossroads/hub_background.png"
const CURSED_PATH := "res://assets/images/hub_crossroads/hub_background_cursed.png"
const SHADER_PATH := "res://shaders/hub_plate.gdshader"
const NATIVE := Vector2(1536.0, 1024.0)
const PLAZA_UV := Vector2(0.50, 0.52)
const SPAWN_UV := Vector2(0.50, 0.61)

@export var plate_scale := 1.0
## Draw collision on top of the painting (Debug → Visible Collision Shapes
## also works). Turn off once the boxes sit on water and roofs.
@export var debug_draw_collision := true

var _sprite: Sprite2D
var _tex_size := NATIVE
var _source_image: Image
var _bounds: StaticBody2D
var _solids: StaticBody2D
var _material: ShaderMaterial
var _debug_rects: Array[Rect2] = []
var _debug_circles: Array[Vector3] = []


func _ready() -> void:
	z_index = -120
	z_as_relative = false
	position = Vector2.ZERO
	scale = Vector2.ONE
	_source_image = _load_disk_image(TEXTURE_PATH)
	if _source_image != null:
		_tex_size = Vector2(_source_image.get_width(), _source_image.get_height())
	_sprite = Sprite2D.new()
	_sprite.name = "Plate"
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.texture = _load_texture(TEXTURE_PATH)
	if _sprite.texture != null:
		var gpu_size := _sprite.texture.get_size()
		if _source_image == null and gpu_size.x > 1.0:
			_tex_size = gpu_size
	_sprite.scale = Vector2(plate_scale, plate_scale)
	_apply_curse_material()
	add_child(_sprite)
	_add_edge_walls()
	_add_solids()
	sync_restoration()
	queue_redraw()


func displayed_size() -> Vector2:
	return _tex_size * plate_scale


func world_rect() -> Rect2:
	var size := displayed_size()
	return Rect2(-size * 0.5, size)


## UV 0..1 over the painting. Sprite is centred on this node, so UV 0.5,0.5
## is local (0,0) and UV 0,0 is the top-left of displayed_size().
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
	var local := to_local(world) if is_inside_tree() else world
	return Vector2(local.x / size.x + 0.5, local.y / size.y + 0.5)


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


func set_ridge_visible(on: bool) -> void:
	visible = on


func set_ridge_collision(on: bool) -> void:
	var layer := PhysicsLayers.LAYER_WORLD if on else 0
	if _bounds != null:
		_bounds.collision_layer = layer
	if _solids != null:
		_solids.collision_layer = layer


func set_ridge_active(on: bool) -> void:
	set_ridge_visible(on)
	set_ridge_collision(on)


func _load_disk_image(path: String) -> Image:
	var disk := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(disk):
		return null
	var image := Image.new()
	if image.load(disk) != OK:
		return null
	return image


func _load_texture(path: String = TEXTURE_PATH) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	if _source_image != null:
		return ImageTexture.create_from_image(_source_image)
	var image := _load_disk_image(path)
	if image != null:
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


func _draw() -> void:
	if not debug_draw_collision:
		return
	for rect in _debug_rects:
		draw_rect(rect, Color(1.0, 0.15, 0.2, 0.28))
		draw_rect(rect, Color(1.0, 0.85, 0.2, 0.95), false, 1.5)
	for circle in _debug_circles:
		draw_circle(Vector2(circle.x, circle.y), circle.z, Color(1.0, 0.15, 0.2, 0.28))
		draw_arc(Vector2(circle.x, circle.y), circle.z, 0.0, TAU, 28, Color(1.0, 0.85, 0.2, 0.95), 1.5)


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
	_solids.name = "HubSolids"
	_solids.position = Vector2.ZERO
	_solids.collision_layer = PhysicsLayers.LAYER_WORLD
	_solids.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	add_child(_solids)

	_paint_water_from_plate()
	_add_rim_water()
	# Painted huts are ~8–10% of the plate, not the 248px overlay sprites.
	_add_house_body(Vector2(0.50, 0.18))
	_add_house_body(Vector2(0.25, 0.32))
	_add_house_body(Vector2(0.74, 0.32))
	_add_house_body(Vector2(0.26, 0.64))
	_add_house_body(Vector2(0.74, 0.64))
	_add_uv_circle(Vector2(0.50, 0.46), 0.030)


func _add_house_body(door_uv: Vector2) -> void:
	# Roof/walls sit slightly toward the top of the plate, not a full overlay
	# sprite tall — that overshot into jungle and left the thatch open.
	_add_uv_box(door_uv + Vector2(0.0, -0.02), Vector2(0.072, 0.062))


func _add_rim_water() -> void:
	# Measured cyan/teal lives on the rim of this painting, not at 0.22/0.80.
	_add_uv_box(Vector2(0.06, 0.50), Vector2(0.13, 0.92))
	_add_uv_box(Vector2(0.94, 0.50), Vector2(0.13, 0.92))
	_add_uv_box(Vector2(0.22, 0.90), Vector2(0.28, 0.18))
	_add_uv_box(Vector2(0.78, 0.90), Vector2(0.28, 0.18))
	_add_uv_box(Vector2(0.18, 0.22), Vector2(0.16, 0.20))
	_add_uv_box(Vector2(0.80, 0.24), Vector2(0.16, 0.18))


func _paint_water_from_plate() -> void:
	if _source_image == null:
		_source_image = _load_disk_image(TEXTURE_PATH)
	if _source_image == null:
		return
	var cols := 48
	var rows := 32
	var flags: Array = []
	flags.resize(rows)
	for y in range(rows):
		var row: Array[bool] = []
		row.resize(cols)
		for x in range(cols):
			var uv := Vector2((float(x) + 0.5) / float(cols), (float(y) + 0.5) / float(rows))
			row[x] = _color_is_water(_sample(_source_image, uv)) and not _is_walk_pad(uv)
		flags[y] = row
	var cell := Vector2(1.0 / float(cols), 1.0 / float(rows))
	for y in range(rows):
		var x := 0
		var row: Array = flags[y]
		while x < cols:
			if not bool(row[x]):
				x += 1
				continue
			var x1 := x + 1
			while x1 < cols and bool(row[x1]):
				x1 += 1
			var uv := Vector2((float(x) + float(x1)) * 0.5 / float(cols), (float(y) + 0.5) / float(rows))
			_add_uv_box(uv, Vector2(cell.x * float(x1 - x) * 1.04, cell.y * 1.10))
			x = x1


func _is_walk_pad(uv: Vector2) -> bool:
	if uv.distance_to(PLAZA_UV) < 0.09:
		return true
	if uv.distance_to(SPAWN_UV) < 0.05:
		return true
	if absf(uv.x - 0.50) < 0.07 and uv.y > 0.82:
		return true
	for house in Houses.LIST:
		var door: Vector2 = house.get("hub_uv", PLAZA_UV)
		var porch: Vector2 = door.lerp(PLAZA_UV, 0.28)
		if uv.distance_to(porch) < 0.045:
			return true
	return false


func _sample(image: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * float(image.get_width())), 0, image.get_width() - 1)
	var y := clampi(int(uv.y * float(image.get_height())), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _color_is_water(c: Color) -> bool:
	# Sampled from hub_background.png: far-west river is ~32,243,240.
	if c.b > 0.50 and c.g > 0.45 and c.r < 0.48:
		return true
	if c.b > 0.38 and c.g > 0.40 and c.r < 0.35 and c.b >= c.g * 0.72:
		return true
	return false


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
	shape.disabled = false
	_solids.add_child(shape)
	var p := uv_to_world(uv_centre)
	_debug_circles.append(Vector3(p.x, p.y, circle.radius))


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
