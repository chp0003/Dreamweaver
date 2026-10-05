class_name NpcNav
extends RefCounted
## Bakes one NavigationRegion2D per World. Call once after solids exist —
## never from _process.

const REGION_NAME := "NpcNavigation"


static func bake_world(world: Node2D, world_rect: Rect2) -> NavigationRegion2D:
	if world == null or world_rect.size.x < 32.0 or world_rect.size.y < 32.0:
		return null
	var region := world.get_node_or_null(REGION_NAME) as NavigationRegion2D
	if region != null:
		return region
	region = NavigationRegion2D.new()
	region.name = REGION_NAME
	var poly := NavigationPolygon.new()
	var inset := world_rect.grow(-28.0)
	poly.add_outline(PackedVector2Array([
		inset.position,
		Vector2(inset.end.x, inset.position.y),
		inset.end,
		Vector2(inset.position.x, inset.end.y),
	]))
	if poly.has_method("set_parsed_geometry_type"):
		poly.set("parsed_geometry_type", 1)
		poly.set("parsed_collision_mask", PhysicsLayers.LAYER_WORLD)
		poly.set("baking_rect", inset)
		poly.set("agent_radius", 14.0)
	if poly.has_method("make_polygons_from_outlines"):
		poly.call("make_polygons_from_outlines")
	region.navigation_polygon = poly
	world.add_child(region)
	if region.has_method("bake_navigation_polygon"):
		region.call("bake_navigation_polygon", false)
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
