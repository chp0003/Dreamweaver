@tool
extends Sprite2D
## Editor-only map picture. Collision drawn here is auto-moved to HubCollision
## so it works in-game (MapReference is hidden when you play).


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_move_collision_to_hub")
	else:
		visible = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_move_collision_to_hub")


func _move_collision_to_hub() -> void:
	if not Engine.is_editor_hint():
		return
	var hub := get_parent().get_node_or_null("HubCollision") as Node2D
	if hub == null:
		return
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			var node2d := child as Node2D
			if node2d == null:
				continue
			var xf: Transform2D = node2d.global_transform
			var node_name := child.name
			child.reparent(hub)
			child.name = node_name
			node2d.global_transform = xf
			var root := owner if owner != null else get_tree().edited_scene_root
			if root != null:
				child.owner = root
