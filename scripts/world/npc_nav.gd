class_name NpcNav
extends RefCounted
## One NavigationRegion2D per walkable space. Hub and each house plate get
## their own region on the same map so indoor NPCs do not steer on the green.

const REGION_NAME := "NpcNavigation"


static func bake_world(world: Node2D, world_rect: Rect2) -> NavigationRegion2D:
	return bake_region(world, REGION_NAME, world_rect)


static func bake_region(world: Node2D, region_name: String, world_rect: Rect2) -> NavigationRegion2D:
	if world == null or region_name.is_empty() or world_rect.size.x < 32.0 or world_rect.size.y < 32.0:
		return null
	var region := world.get_node_or_null(region_name) as NavigationRegion2D
	if region != null:
		return region
	region = NavigationRegion2D.new()
	region.name = region_name
	world.add_child(region)

	var inset := world_rect.grow(-28.0)
	var walkable := PackedVector2Array([
		inset.position,
		Vector2(inset.end.x, inset.position.y),
		inset.end,
		Vector2(inset.position.x, inset.end.y),
	])
	var poly := NavigationPolygon.new()
	if poly.has_method("set_parsed_geometry_type"):
		poly.set("parsed_geometry_type", 1)
		poly.set("parsed_collision_mask", PhysicsLayers.LAYER_WORLD)
		poly.set("baking_rect", inset)
		poly.set("agent_radius", 16.0)
	poly.add_outline(walkable)

	var source := NavigationMeshSourceGeometryData2D.new()
	if source.has_method("add_traversable_outline"):
		source.call("add_traversable_outline", walkable)
	if NavigationServer2D.has_method("parse_source_geometry_data"):
		NavigationServer2D.call("parse_source_geometry_data", poly, source, world)
	_add_blocker_outlines(world, source, inset)
	if NavigationServer2D.has_method("bake_from_source_geometry_data"):
		NavigationServer2D.call("bake_from_source_geometry_data", poly, source)
	if poly.get_polygon_count() < 1 and poly.has_method("make_polygons_from_outlines"):
		poly.call("make_polygons_from_outlines")
	region.navigation_polygon = poly
	return region


static func ensure_near(actor: Node2D) -> void:
	if actor == null or not actor.is_inside_tree():
		return
	var world := actor.get_parent() as Node2D
	if world == null:
		return
	if world.get_node_or_null(REGION_NAME) != null:
		return
	var rect := Rect2(actor.global_position - Vector2(720, 480), Vector2(1440, 960))
	bake_world(world, rect)


static func _add_blocker_outlines(world: Node2D, source: NavigationMeshSourceGeometryData2D, bounds: Rect2) -> void:
	if world == null or source == null or not source.has_method("add_obstruction_outline"):
		return
	var area := bounds.grow(48.0)
	for child in world.get_children():
		if child is StaticBody2D:
			var body := child as Node2D
			if not area.has_point(body.global_position) and not _body_hits(body, area):
				continue
			_collect_shape_outlines(child, source)


static func _body_hits(node: Node2D, area: Rect2) -> bool:
	if area.has_point(node.global_position):
		return true
	for child in node.get_children():
		if child is Node2D and _body_hits(child as Node2D, area):
			return true
	return false


static func _collect_shape_outlines(node: Node, source: NavigationMeshSourceGeometryData2D) -> void:
	if node is CollisionPolygon2D:
		var poly := node as CollisionPolygon2D
		if poly.polygon.size() >= 3:
			var pts := PackedVector2Array()
			var xf := poly.global_transform
			for point in poly.polygon:
				pts.append(xf * point)
			source.call("add_obstruction_outline", pts)
	elif node is CollisionShape2D:
		var shape_node := node as CollisionShape2D
		var outline := _shape_outline(shape_node)
		if outline.size() >= 3:
			source.call("add_obstruction_outline", outline)
	if node is CharacterBody2D or node is Area2D:
		return
	for child in node.get_children():
		_collect_shape_outlines(child, source)


static func _shape_outline(shape_node: CollisionShape2D) -> PackedVector2Array:
	var shape := shape_node.shape
	if shape == null:
		return PackedVector2Array()
	var xf := shape_node.global_transform
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		var pts := PackedVector2Array()
		for i in 10:
			var angle := TAU * float(i) / 10.0
			pts.append(xf * Vector2(cos(angle), sin(angle)) * radius)
		return pts
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([
			xf * Vector2(-half.x, -half.y),
			xf * Vector2(half.x, -half.y),
			xf * Vector2(half.x, half.y),
			xf * Vector2(-half.x, half.y),
		])
	if shape is ConvexPolygonShape2D:
		var pts := PackedVector2Array()
		for point in (shape as ConvexPolygonShape2D).points:
			pts.append(xf * point)
		return pts
	return PackedVector2Array()
