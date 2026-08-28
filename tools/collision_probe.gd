extends Node
## Collision sanity check: house stilts must stop CharacterBody2D.

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var prop := PlaceholderProp.new()
	prop.prop_label = "GUNO BONG I"
	prop.texture_path = "res://assets/images/houses/House1.png"
	prop.prop_size = Vector2(236, 248)
	prop.collision_feet = Vector2(200, 96)
	prop.blocks_movement = true
	prop.show_label = false
	prop.position = Vector2(40, -30)
	world.add_child(prop)
	prop.position = Vector2(80, -20)
	prop.sync_blocker()

	await get_tree().physics_frame
	await get_tree().physics_frame

	var blocker: StaticBody2D = prop.get_world_blocker()
	print("BLOCKER present=%s layer=%s children=%d gp=%s parent=%s" % [
		str(blocker != null),
		str(blocker.collision_layer) if blocker else "n/a",
		blocker.get_child_count() if blocker else 0,
		str(blocker.global_position) if blocker else "n/a",
		blocker.get_parent().name if blocker and blocker.get_parent() else "n/a",
	])
	var parent_ok := blocker != null and blocker.get_parent() == prop

	var player: Slang = (load("res://scenes/world/Player.tscn") as PackedScene).instantiate()
	player.position = Vector2(80, 90)
	world.add_child(player)
	await get_tree().physics_frame

	var space := player.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = PhysicsLayers.feet_circle(14.0)
	query.transform = Transform2D(0.0, Vector2(80, -55))
	query.collision_mask = PhysicsLayers.LAYER_WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := space.intersect_shape(query, 8)
	print("SHAPE_HIT count=%d" % hits.size())
	for h in hits:
		print("  hit=", (h as Dictionary).get("collider"))

	player.velocity = Vector2(0, -900)
	var slides := 0
	for _i in range(40):
		player.move_and_slide()
		slides += player.get_slide_collision_count()
	print("SHOVE after=%s slides=%d" % [str(player.global_position), slides])
	var blocked := parent_ok and (player.global_position.y > 0.0 or hits.size() > 0 or slides > 0)
	print("RESULT: %s" % ("OK solid blocks player" if blocked else "FAIL ghost through prop"))
	get_tree().quit(0 if blocked else 1)
