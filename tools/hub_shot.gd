extends Node
## One-shot hub capture for design review. Colour forced on so tiles read clearly.

const OUT_PATH := "res://tools/shots/05_hub.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	# Offline capture — skip AccountManager (network can hang in CI/headless).
	GameState.new_game()
	GameState.add_item("lewet_staff")
	GameState.unlock_lore("guno_bong")
	await get_tree().process_frame

	var packed := load("res://scenes/HubWorld.tscn") as PackedScene
	var instance := packed.instantiate()
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	for _i in range(80):
		await get_tree().process_frame
	ColorRestoration.set_global_gray(0.0)
	# Show house nameplates only — not every interactable E prompt.
	for node in get_tree().get_nodes_in_group("world_chrome"):
		if node is CanvasItem:
			var item := node as CanvasItem
			if node is InteractionPrompt:
				item.visible = false
			elif str(node.name).begins_with("Interaction") or item is Label and (item as Label).text.begins_with("E"):
				item.visible = false
			elif node.get_parent() != null and node.get_parent().get_parent() is PlaceholderProp:
				item.visible = true
	for _i in range(16):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("hub_shot: viewport texture null")
		get_tree().quit(1)
		return
	var err := image.save_png(OUT_PATH)
	print("hub_shot %s gray=%.2f size=%dx%d" % [
		"ok" if err == OK else "fail(%d)" % err,
		ColorRestoration.global_gray(),
		image.get_width(),
		image.get_height(),
	])
	get_tree().quit(0 if err == OK else 1)
