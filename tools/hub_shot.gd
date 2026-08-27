extends Node
## One-shot hub capture for design review. Colour forced on so tiles read clearly.
##   /tmp/godot/Godot_v4.4.1-stable_linux.x86_64 --path . res://tools/HubShot.tscn

const OUT_PATH := "res://tools/shots/05_hub.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	if await AccountManager.try_register(
			"hubshot", "hubshot@example.com", "abaca123", "abaca123") != "":
		await AccountManager.try_login("hubshot@example.com", "abaca123")
	GameState.new_game()
	GameState.add_item("lewet_staff")
	# Skip opening narrator so house nameplates stay visible in the shot.
	GameState.unlock_lore("guno_bong")
	await get_tree().process_frame

	var packed := load("res://scenes/HubWorld.tscn") as PackedScene
	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	for _i in range(100):
		await get_tree().process_frame
	ColorRestoration.set_global_gray(0.0)
	for node in get_tree().get_nodes_in_group("world_chrome"):
		if node is CanvasItem:
			(node as CanvasItem).visible = true
	for _i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(OUT_PATH)
	print("hub_shot %s gray=%.2f" % [
		"ok" if err == OK else "fail(%d)" % err,
		ColorRestoration.global_gray(),
	])
	get_tree().quit(0 if err == OK else 1)
