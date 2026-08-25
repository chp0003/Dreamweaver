extends Node
## Minimal collision + walk-frame sanity check (no physics_frame waits).

func _ready() -> void:
	var world := Node2D.new()
	add_child(world)

	var prop := PlaceholderProp.new()
	prop.prop_label = "TEST LOOM"
	prop.prop_size = Vector2(110, 80)
	prop.blocks_movement = true
	prop.show_label = false
	prop.position = Vector2.ZERO
	world.add_child(prop)

	var blocker: StaticBody2D = prop.get_node_or_null("WorldBlocker")
	print("BLOCKER present=%s layer=%s children=%d" % [
		str(blocker != null),
		str(blocker.collision_layer) if blocker else "n/a",
		blocker.get_child_count() if blocker else 0
	])

	var player: Slang = (load("res://scenes/world/Player.tscn") as PackedScene).instantiate()
	player.position = Vector2(0, 90)
	world.add_child(player)

	var anim: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	print("PLAYER layer=%d mask=%d" % [player.collision_layer, player.collision_mask])
	print("WALK_RIGHT frames=%d" % anim.sprite_frames.get_frame_count("walk_right"))

	# Direct physics query: does a shape cast from the player toward the prop hit?
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = PhysicsLayers.feet_circle(14.0)
	query.transform = Transform2D(0.0, Vector2(0, 25))
	query.collision_mask = PhysicsLayers.LAYER_WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := space.intersect_shape(query, 8)
	print("SHAPE_HIT count=%d" % hits.size())
	for h in hits:
		print("  hit=", (h as Dictionary).get("collider"))

	# Shove without awaiting physics frames.
	player.velocity = Vector2(0, -800)
	for _i in range(20):
		player.move_and_slide()
	print("SHOVE after_y=%.1f slides=%d" % [
		player.global_position.y, player.get_slide_collision_count()
	])
	var blocked := player.global_position.y > 20.0 or hits.size() > 0
	print("RESULT: %s" % ("OK solid blocks player" if blocked else "FAIL ghost through prop"))
	get_tree().quit(0 if blocked else 1)
