extends Node
## Temporary visual check. Run WITH a rendering device (no --headless):
##   Godot_v4.x_console.exe --path . res://tools/Shot.tscn
##
## Mounts each screen, lets it settle, and writes a real rendered frame to
## res://tools/shots/. Used to confirm on-screen colour rather than inferring it
## from the code - the grayscale veil is an autoload, so whether a screen is
## bleached is not visible in that screen's own scene file.

const OUT_DIR := "res://tools/shots"
const SETTLE_FRAMES := 60

const TARGETS := [
	{"name": "01_login", "scene": "res://scenes/Login.tscn"},
	{"name": "01b_register", "scene": "res://scenes/Register.tscn"},
	{"name": "02_main_menu", "scene": "res://scenes/MainMenu.tscn"},
	{"name": "03_story_intro", "scene": "res://scenes/StoryIntro.tscn"},
	{"name": "04_tutorial", "scene": "res://scenes/Tutorial.tscn"},
	{"name": "05_hub", "scene": "res://scenes/HubWorld.tscn"},
	{"name": "06_chapter1", "scene": "res://scenes/Chapter1.tscn"},
	{"name": "07_ending", "scene": "res://scenes/Ending.tscn"},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _sign_in()
	# The root is still building its own children during our _ready().
	await get_tree().process_frame

	for target in TARGETS:
		await _shoot(str(target["name"]), str(target["scene"]))

	print("Shots written to %s" % OUT_DIR)
	get_tree().quit(0)


func _sign_in() -> void:
	if await AccountManager.try_register(
			"shotcheck", "shotcheck@example.com", "abaca123", "abaca123") != "":
		await AccountManager.try_login("shotcheck@example.com", "abaca123")
	GameState.new_game()
	GameState.add_item("lewet_staff")


func _shoot(shot_name: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("MISSING %s" % scene_path)
		return

	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var out_path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(out_path)
	print("%s  gray=%.2f  %s" % [
		shot_name, ColorRestoration.global_gray(),
		"ok" if error == OK else "save failed (%d)" % error])

	if is_instance_valid(instance):
		instance.queue_free()
	await get_tree().process_frame
