extends Node
## Capture Chapters 1-5 for the manuscript appendix.
## Run: Godot --path . res://tools/ShotChapters.tscn

const OUT_DIR := "res://tools/shots"
const SETTLE_FRAMES := 90

const TARGETS := [
	{"name": "06_chapter1", "scene": "res://scenes/Chapter1.tscn", "house": 1},
	{"name": "06b_chapter2", "scene": "res://scenes/Chapter2.tscn", "house": 2},
	{"name": "06c_chapter3", "scene": "res://scenes/Chapter3.tscn", "house": 3},
	{"name": "06d_chapter4", "scene": "res://scenes/Chapter4.tscn", "house": 4},
	{"name": "06e_chapter5", "scene": "res://scenes/Chapter5.tscn", "house": 5},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _sign_in()
	await get_tree().process_frame

	for target in TARGETS:
		_seed_for_house(int(target["house"]))
		await _shoot(str(target["name"]), str(target["scene"]))

	print("Chapter shots written to %s" % OUT_DIR)
	get_tree().quit(0)


func _sign_in() -> void:
	if await AccountManager.try_register(
			"shotcheck", "shotcheck@example.com", "abaca123", "abaca123") != "":
		await AccountManager.try_login("shotcheck@example.com", "abaca123")
	GameState.new_game()
	GameState.add_item("lewet_staff")


func _seed_for_house(house: int) -> void:
	GameState.unlocked_houses = []
	GameState.completed_houses = []
	GameState.essences = []
	GameState.items = ["lewet_staff"]
	GameState.game_completed = false
	GameState.current_chapter = house
	GameState.replay_house_id = house
	for i in range(1, house + 1):
		GameState.unlocked_houses.append(i)
	for i in range(1, house):
		GameState.completed_houses.append(i)
	match house:
		1:
			pass
		2:
			GameState.essences = ["black"]
		3:
			GameState.essences = ["black", "red"]
		4:
			GameState.essences = ["black", "red", "gold"]
		5:
			GameState.essences = ["black", "red", "gold"]
			if not GameState.has_item("master_pattern"):
				GameState.add_item("master_pattern")


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
	await get_tree().create_timer(0.35).timeout
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
