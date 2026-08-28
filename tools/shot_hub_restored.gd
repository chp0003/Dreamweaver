extends Node
## One-shot: render the hub after the Color Burst. Does not write GameState.
## Run: Dreamweaver.console.exe --path . res://tools/ShotHubRestored.tscn

const OUT_PATH := "res://tools/shots/hub_restored.png"
const SETTLE_FRAMES := 120


func _ready() -> void:
	_arm_restored_state()
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	await get_tree().process_frame

	var packed := load("res://scenes/HubWorld.tscn") as PackedScene
	var hub := packed.instantiate()
	get_tree().root.add_child(hub)

	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUT_PATH)
	print("hub_restored gray=%.2f %s" % [
		ColorRestoration.global_gray(),
		"ok" if error == OK else "save failed (%d)" % error,
	])
	get_tree().quit(0 if error == OK else 1)


func _arm_restored_state() -> void:
	GameState.current_chapter = 0
	GameState.unlocked_houses = [1, 2, 3, 4, 5]
	GameState.completed_houses = [1, 2, 3, 4, 5]
	GameState.essences = ["black", "red", "gold"]
	GameState.items = ["lewet_staff", "master_pattern"]
	GameState.game_completed = true
	GameState.objective = "The world is whole."
	ColorRestoration.reset()
	ColorRestoration.sync_essences()
