@tool
extends Sprite2D
## Hall painting for drawing collision in the editor. Hidden when the game runs.
## Keep this sprite centred on the scene origin so polygons match Chapter1Plate.
## Collision drawn on this sprite is moved onto HallCollision (same as the hub).


func _ready() -> void:
	if Engine.is_editor_hint():
		centered = true
		position = Vector2.ZERO
		call_deferred("_move_collision_to_hall")
	else:
		visible = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_move_collision_to_hall")


func _move_collision_to_hall() -> void:
	if not Engine.is_editor_hint():
		return
	var hall := get_parent().get_node_or_null("HallCollision") as Node2D
	if hall == null:
		return
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			var node2d := child as Node2D
			if node2d == null:
				continue
			var xf: Transform2D = node2d.global_transform
			var node_name := child.name
			child.reparent(hall)
			child.name = node_name
			node2d.global_transform = xf
			var scene_root := owner if owner != null else get_tree().edited_scene_root
			if scene_root != null:
				child.owner = scene_root
