@tool
extends StaticBody2D
## Draws red overlays for collision children when show_collision_debug is on.
## In the editor, moves any shapes nested under Totem/etc. up to this body.

@export var show_collision_debug := false
@export var fill_color := Color(1.0, 0.18, 0.12, 0.38)
@export var line_color := Color(1.0, 0.45, 0.28, 0.95)
@export var line_width := 2.5


func _ready() -> void:
	z_index = 50
	if Engine.is_editor_hint():
		call_deferred("_flatten_collision_tree")
	else:
		_bake_polygon_scales()
	queue_redraw()


## Godot draws a scaled CollisionPolygon2D with the stretch, then physics drops
## that non-uniform scale. Bake it into the points so the blocker matches the overlay.
func _bake_polygon_scales() -> void:
	for child in get_children():
		var poly := child as CollisionPolygon2D
		if poly == null:
			continue
		var stretched := poly.scale
		if is_equal_approx(stretched.x, 1.0) and is_equal_approx(stretched.y, 1.0):
			continue
		var baked := PackedVector2Array()
		for point in poly.polygon:
			baked.append(Vector2(point.x * stretched.x, point.y * stretched.y))
		poly.polygon = baked
		poly.scale = Vector2.ONE


func _process(_delta: float) -> void:
	if show_collision_debug:
		queue_redraw()


func _flatten_collision_tree() -> void:
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		_flatten_node(child)


func _flatten_node(node: Node) -> void:
	for sub in node.get_children():
		if sub is CollisionPolygon2D or sub is CollisionShape2D:
			var node2d := sub as Node2D
			if node2d == null:
				continue
			var xf: Transform2D = node2d.global_transform
			var node_name := sub.name
			sub.reparent(self)
			sub.name = node_name
			node2d.global_transform = xf
			var root := owner if owner != null else get_tree().edited_scene_root
			if root != null:
				sub.owner = root
		elif sub is Node2D:
			_flatten_node(sub)


func _draw() -> void:
	if not show_collision_debug:
		return
	_draw_node_children(self)


func _draw_node_children(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionPolygon2D:
			_draw_polygon(child as CollisionPolygon2D)
		elif child is CollisionShape2D:
			_draw_shape(child as CollisionShape2D)
		elif child is Node2D:
			_draw_node_children(child)


func _draw_polygon(poly: CollisionPolygon2D) -> void:
	if poly.polygon.size() < 3:
		return
	var pts := PackedVector2Array()
	var xf := poly.global_transform * global_transform.affine_inverse()
	for p in poly.polygon:
		pts.append(xf * p)
	var local_pts := PackedVector2Array()
	for p in pts:
		local_pts.append(to_local(p))
	draw_colored_polygon(local_pts, fill_color)
	for i in range(local_pts.size()):
		var a := local_pts[i]
		var b := local_pts[(i + 1) % local_pts.size()]
		draw_line(a, b, line_color, line_width)


func _draw_shape(shape_node: CollisionShape2D) -> void:
	var shape := shape_node.shape
	if shape == null:
		return
	var xf := shape_node.global_transform * global_transform.affine_inverse()
	var center := to_local(xf.origin)
	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		var half := rect_shape.size * 0.5
		var corners := PackedVector2Array([
			to_local(xf * (-half)),
			to_local(xf * Vector2(half.x, -half.y)),
			to_local(xf * half),
			to_local(xf * Vector2(-half.x, half.y)),
		])
		draw_colored_polygon(corners, fill_color)
		for i in range(corners.size()):
			draw_line(corners[i], corners[(i + 1) % corners.size()], line_color, line_width)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var radius: float = circle.radius * maxf(xf.get_scale().x, xf.get_scale().y)
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, line_color, line_width)
