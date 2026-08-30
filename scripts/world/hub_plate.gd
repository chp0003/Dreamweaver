class_name HubPlate
extends Node2D
## Painted 16:9 village plate. Sprite2D is the picture; StaticBody2D children
## are hand-placed solids in UV space (0..1 over the centred sprite).
##
## Tune collision visually: set debug_draw_collision = true on HubPlate, run
## HubWorld, then edit hub_roof_polygons_uv / RIVER_BOXES / TOTEM_* constants.

const TEXTURE_PATH := "res://assets/images/hub_crossroads/hub_background.png"
const CURSED_PATH := "res://assets/images/hub_crossroads/hub_background_cursed.png"
const SHADER_PATH := "res://shaders/hub_plate.gdshader"
const NATIVE := Vector2(1536.0, 1024.0)
const PLAZA_UV := Vector2(0.50, 0.52)
const SPAWN_UV := Vector2(0.50, 0.61)
## Restored-house colour on the ridge plate. Original was a flat 0.36 UV
## (~552 px) — too wide on the crossroads. Trim ~35% so the glow still covers
## the hut, porch, and garden without painting half the map.
const RESTORE_ZONE_TRIM := 0.35
const RESTORE_ZONE_ORIGINAL := 0.36
const RESTORE_ZONE_MIN := 0.20
const RESTORE_ZONE_MAX := 0.26
const RESTORE_ZONE_PORCH_PAD := 0.045

@export var plate_scale := 1.0
## When false, HubPlate does not spawn roof/river/totem collision — draw those
## on World/HubCollision in scenes/HubWorld.tscn instead.
@export var auto_generate_collision := false
## Overlay collision rects/circles on the painting while tuning hand-placed UV boxes.
@export var debug_draw_collision := false
## Show live mouse UV readout while debug_draw_collision is on.
@export var debug_draw_mouse_uv := true
## When true, porch walk-pads and door UV anchors are drawn (green / white).
@export var debug_draw_porch_pads := false

## Hand-placed rim water — centre UV + full width/height in UV space (0..1).
const RIVER_BOXES: Array[Dictionary] = [
	{"centre": Vector2(0.045, 0.52), "size": Vector2(0.07, 0.86), "label": "West river"},
	{"centre": Vector2(0.955, 0.52), "size": Vector2(0.07, 0.86), "label": "East river"},
	{"centre": Vector2(0.20, 0.90), "size": Vector2(0.22, 0.14), "label": "SW dock"},
	{"centre": Vector2(0.80, 0.90), "size": Vector2(0.22, 0.14), "label": "SE dock"},
	{"centre": Vector2(0.17, 0.21), "size": Vector2(0.14, 0.16), "label": "NW pool"},
	{"centre": Vector2(0.82, 0.23), "size": Vector2(0.14, 0.14), "label": "NE pool"},
]
const TOTEM_UV := Vector2(0.50, 0.46)
const TOTEM_RADIUS_UV := 0.028

const DEBUG_COLORS := {
	"roof": Color(1.0, 0.18, 0.12, 0.38),
	"wall": Color(1.0, 0.55, 0.08, 0.32),
	"water": Color(0.15, 0.45, 1.0, 0.34),
	"rim": Color(0.25, 0.65, 0.95, 0.28),
	"totem": Color(1.0, 0.88, 0.18, 0.40),
	"porch": Color(0.25, 0.95, 0.45, 0.22),
	"footprint": Color(0.55, 0.22, 1.0, 0.36),
	"door": Color(1.0, 1.0, 1.0, 0.95),
	"edge": Color(0.85, 0.85, 0.85, 0.18),
}

var _sprite: Sprite2D
var _tex_size := NATIVE
var _source_image: Image
var _bounds: StaticBody2D
var _solids: StaticBody2D
var _material: ShaderMaterial
var _debug_rects: Array[Rect2] = []
var _debug_circles: Array[Vector3] = []
var _debug_solids: Array[Dictionary] = []
var _debug_polygons: Array[Dictionary] = []
var _debug_markers: Array[Dictionary] = []


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
	if auto_generate_collision:
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
		var uv: Vector2 = Houses.hub_solid_centre(house)
		var zone_r := _house_restore_uv_radius(house)
		packed.append(Vector4(uv.x, uv.y, zone_r, 0.96))
	if player != null and is_instance_valid(player):
		var puv := world_to_uv(player.global_position)
		packed.append(Vector4(puv.x, puv.y, 0.035, 0.35))
	_material.set_shader_parameter("zones", packed)
	_material.set_shader_parameter("zone_count", packed.size())


func _house_restore_uv_radius(house: Dictionary) -> float:
	var trimmed := RESTORE_ZONE_ORIGINAL * (1.0 - RESTORE_ZONE_TRIM)
	var solid_size := Houses.hub_solid_size(house)
	var rx: float = solid_size.x * 0.82
	var ry: float = solid_size.y * 0.76
	return clampf(maxf(maxf(rx, ry), trimmed) + RESTORE_ZONE_PORCH_PAD,
		RESTORE_ZONE_MIN, RESTORE_ZONE_MAX)


func set_ridge_visible(on: bool) -> void:
	visible = on


func set_ridge_collision(on: bool) -> void:
	var layer := PhysicsLayers.LAYER_WORLD if on else 0
	if _bounds != null:
		_bounds.collision_layer = layer
	if _solids != null:
		_solids.collision_layer = layer


## StaticBody2D children must live on the World node (same branch as the player)
## or CharacterBody2D slide checks miss them.
func reparent_solids_to(host: Node2D) -> void:
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
	if debug_draw_collision and debug_draw_mouse_uv:
		queue_redraw()
	if not visible or _material == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	sync_restoration(p)


func _draw() -> void:
	if not debug_draw_collision and not debug_draw_porch_pads:
		return
	if debug_draw_collision:
		for entry in _debug_polygons:
			var pts: PackedVector2Array = entry.get("points", PackedVector2Array())
			if pts.size() < 3:
				continue
			var kind: String = str(entry.get("kind", "roof"))
			var fill: Color = DEBUG_COLORS.get(kind, Color(1, 0, 0, 0.3))
			draw_colored_polygon(pts, fill)
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], fill.lightened(0.45), 2.5)
				draw_circle(pts[i], 3.5, DEBUG_COLORS["door"])
			var label: String = str(entry.get("label", ""))
			if not label.is_empty():
				var anchor := pts[0]
				for p in pts:
					if p.y < anchor.y:
						anchor = p
				draw_string(ThemeDB.fallback_font, anchor + Vector2(4, 14), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill.lightened(0.5))
		for entry in _debug_solids:
			var rect: Rect2 = entry.get("rect", Rect2())
			var kind: String = str(entry.get("kind", "roof"))
			var fill: Color = DEBUG_COLORS.get(kind, Color(1, 0, 0, 0.3))
			draw_rect(rect, fill)
			draw_rect(rect, fill.lightened(0.35), false, 2.0)
			var label: String = str(entry.get("label", ""))
			if not label.is_empty():
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 14), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill.lightened(0.5))
		for circle in _debug_circles:
			_draw_debug_circle(Vector2(circle.x, circle.y), circle.z, "totem")
		for rect in _debug_rects:
			if _debug_solids.is_empty():
				draw_rect(rect, DEBUG_COLORS["edge"])
				draw_rect(rect, Color(1.0, 0.85, 0.2, 0.95), false, 1.5)
		_draw_mouse_uv_hud()
	if debug_draw_porch_pads:
		_draw_porch_pad_hints()
		for marker in _debug_markers:
			var pos: Vector2 = marker.get("pos", Vector2.ZERO)
			var label: String = str(marker.get("label", ""))
			draw_circle(pos, 5.0, DEBUG_COLORS["door"])
			draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), DEBUG_COLORS["door"], 2.0)
			draw_line(pos + Vector2(0, -10), pos + Vector2(0, 10), DEBUG_COLORS["door"], 2.0)
			if not label.is_empty():
				draw_string(ThemeDB.fallback_font, pos + Vector2(8, -8), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DEBUG_COLORS["door"])


func _draw_debug_circle(center: Vector2, radius: float, kind: String) -> void:
	var fill: Color = DEBUG_COLORS.get(kind, Color(1, 1, 0, 0.3))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 32, fill.lightened(0.35), 2.0)


func _draw_mouse_uv_hud() -> void:
	if not debug_draw_mouse_uv:
		return
	var mouse_uv := world_to_uv(get_global_mouse_position())
	var mouse_local := to_local(get_global_mouse_position())
	var text := "mouse UV  %.3f, %.3f" % [mouse_uv.x, mouse_uv.y]
	var hud_pos := world_rect().position + Vector2(10.0, 22.0)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var pad := Vector2(6.0, 4.0)
	draw_rect(Rect2(hud_pos - pad, text_size + pad * 2.0), Color(0.0, 0.0, 0.0, 0.62))
	draw_string(font, hud_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DEBUG_COLORS["door"])
	draw_line(mouse_local + Vector2(-10.0, 0.0), mouse_local + Vector2(10.0, 0.0),
		DEBUG_COLORS["door"], 1.5)
	draw_line(mouse_local + Vector2(0.0, -10.0), mouse_local + Vector2(0.0, 10.0),
		DEBUG_COLORS["door"], 1.5)
	draw_circle(mouse_local, 4.0, DEBUG_COLORS["door"])


func _draw_porch_pad_hints() -> void:
	for house in Houses.LIST:
		var porch_uv: Vector2 = Houses.hub_porch(house)
		var pad_r: float = 0.055 * displayed_size().x
		_draw_debug_circle(uv_to_world(porch_uv), pad_r, "porch")


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
		_add_rect_shape(_bounds, pad, "edge")
	add_child(_bounds)


func _add_solids() -> void:
	_solids = StaticBody2D.new()
	_solids.name = "HubSolids"
	_solids.position = Vector2.ZERO
	_solids.collision_layer = PhysicsLayers.LAYER_WORLD
	_solids.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	add_child(_solids)

	_add_river_solids()
	for house in Houses.LIST:
		_add_hut_roof(house)
	_add_uv_circle(TOTEM_UV, TOTEM_RADIUS_UV, "totem", "Plaza totem")


func _add_river_solids() -> void:
	for entry in RIVER_BOXES:
		_add_uv_box(entry["centre"] as Vector2, entry["size"] as Vector2,
			"water", str(entry.get("label", "River")))


## Diagonal thatch roof — one or more UV quads (main + porch) from Houses.
func _add_hut_roof(house: Dictionary) -> void:
	var polys := Houses.hub_roof_polygons(house)
	var door_uv: Vector2 = house.get("hub_uv", PLAZA_UV)
	var label: String = str(house.get("short", "Hut"))
	_debug_mark_door(door_uv, "%s door" % label)
	for i in range(polys.size()):
		var part := " roof" if i == 0 else " porch"
		_add_uv_polygon(polys[i], "roof", label + part)


func _debug_mark_door(door_uv: Vector2, label: String) -> void:
	_debug_markers.append({"pos": uv_to_world(door_uv), "label": label})


func _add_uv_polygon(points_uv: PackedVector2Array, kind: String = "roof",
		label: String = "") -> void:
	if points_uv.size() < 3:
		return
	var world_pts := PackedVector2Array()
	for uv in points_uv:
		world_pts.append(uv_to_world(uv))
	var poly := CollisionPolygon2D.new()
	poly.polygon = world_pts
	poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	_solids.add_child(poly)
	_debug_polygons.append({"points": world_pts, "kind": kind, "label": label})


func _add_uv_box(uv_centre: Vector2, uv_size: Vector2, kind: String = "roof",
		label: String = "") -> void:
	var half := uv_size * 0.5
	var a := uv_to_world(uv_centre - half)
	var b := uv_to_world(uv_centre + half)
	var rect := Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(b.x - a.x), absf(b.y - a.y))
	)
	_add_rect_shape(_solids, rect, kind, label)


func _add_uv_circle(uv_centre: Vector2, uv_radius: float, kind: String = "totem",
		label: String = "") -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = uv_radius * displayed_size().x
	shape.shape = circle
	shape.position = uv_to_world(uv_centre)
	shape.disabled = false
	_solids.add_child(shape)
	var p := uv_to_world(uv_centre)
	_debug_circles.append(Vector3(p.x, p.y, circle.radius))
	if not label.is_empty():
		_debug_solids.append({
			"rect": Rect2(p - Vector2(circle.radius, circle.radius),
				Vector2(circle.radius * 2.0, circle.radius * 2.0)),
			"kind": kind,
			"label": label,
		})


func _add_rect_shape(body: StaticBody2D, rect: Rect2, kind: String = "edge",
		label: String = "") -> void:
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
	_debug_solids.append({"rect": rect, "kind": kind, "label": label})
