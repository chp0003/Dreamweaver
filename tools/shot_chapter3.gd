extends Node
## One-off visual check for Chapter 3. Run WITH a rendering device:
##   Godot_v4.x_console.exe --path . res://tools/ShotChapter3.tscn

const OUT := "res://tools/shots/06c_chapter3.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	if await AccountManager.try_register(
			"shotcheck", "shotcheck@example.com", "abaca123", "abaca123") != "":
		await AccountManager.try_login("shotcheck@example.com", "abaca123")
	GameState.new_game()
	GameState.add_item("lewet_staff")
	GameState.unlock_house(3)
	GameState.set_current_chapter(3)

	var packed := load("res://scenes/Chapter3.tscn") as PackedScene
	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	for _i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tools/shots/06c_chapter3.png")

	var plate := instance.find_child("Chapter3Plate", true, false)
	if plate != null and plate.has_method("set_veil"):
		plate.call("set_veil", 0.0)
		plate.call("set_restore", 0.0)
	for _j in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	var error := image.save_png("res://tools/shots/06c_chapter3_hall.png")
	print("chapter3 shot %s gray=%.2f" % [
		"ok" if error == OK else "fail", ColorRestoration.global_gray()])
	get_tree().quit(0 if error == OK else 1)
