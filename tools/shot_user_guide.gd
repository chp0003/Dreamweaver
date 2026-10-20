extends Node
## Capture User Guide screens for the manuscript appendix.
## Run: Godot --path . res://tools/ShotUserGuide.tscn

const OUT_DIR := "res://tools/shots/user_guide"
const SETTLE := 70


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _sign_in_with_save()
	await get_tree().process_frame

	await _shoot_scene("01_login", "res://scenes/Login.tscn")
	await _shoot_scene("02_register", "res://scenes/Register.tscn")
	await _shoot_gateway()
	await _shoot_settings()
	await _shoot_scene("05_lore_codex", "res://scenes/LoreCodex.tscn")
	await _shoot_scene("06_leaderboard", "res://scenes/Leaderboard.tscn")
	await _shoot_scene("07_story_intro", "res://scenes/StoryIntro.tscn")
	await _shoot_tutorial_dialogue()
	await _shoot_hub_and_overlays()
	await _shoot_chapters()
	await _shoot_final_house()
	await _shoot_scene("18_ending", "res://scenes/Ending.tscn")

	print("User guide shots written to %s" % OUT_DIR)
	get_tree().quit(0)


func _sign_in_with_save() -> void:
	if await AccountManager.try_register(
			"shotcheck", "shotcheck@example.com", "abaca123", "abaca123") != "":
		await AccountManager.try_login("shotcheck@example.com", "abaca123")
	GameState.new_game()
	GameState.add_item("lewet_staff")
	GameState.unlocked_houses = [1, 2, 3]
	GameState.completed_houses = [1]
	GameState.essences = ["black"]
	GameState.current_chapter = 0
	GameState.unlock_lore("spirit_fiber")
	GameState.add_score(250)
	GameState.save()


func _shoot_scene(shot_name: String, scene_path: String) -> void:
	ColorRestoration.reset()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("MISSING %s" % scene_path)
		return
	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	await _settle()
	await _capture(shot_name)
	_free(instance)


func _shoot_gateway() -> void:
	ColorRestoration.reset()
	# Ensure Continue appears
	GameState.save()
	var packed := load("res://scenes/MainMenu.tscn") as PackedScene
	var gateway := packed.instantiate()
	get_tree().root.add_child(gateway)
	await _settle(90)
	await _capture("03_gateway")
	_free(gateway)


func _shoot_settings() -> void:
	ColorRestoration.reset()
	var packed := load("res://scenes/MainMenu.tscn") as PackedScene
	var gateway := packed.instantiate()
	get_tree().root.add_child(gateway)
	await _settle(50)
	var settings := gateway.get_node_or_null("_settings")
	# Gateway stores settings as a child CanvasLayer without that name — find by script
	for child in gateway.get_children():
		if child is CanvasLayer and child.has_method("open"):
			child.call("open", true, 0) # AUDIO tab
			await _settle(40)
			await _capture("04_settings_audio")
			if child.has_method("_show_tab"):
				child.call("_show_tab", 2) # DISPLAY
				await _settle(25)
				await _capture("04b_settings_display")
			break
	_free(gateway)


func _shoot_tutorial_dialogue() -> void:
	ColorRestoration.reset()
	GameState.add_item("lewet_staff")
	var packed := load("res://scenes/Tutorial.tscn") as PackedScene
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	await _settle(100)
	await _capture("08_tutorial_controls")
	_free(scene)


func _shoot_hub_and_overlays() -> void:
	ColorRestoration.reset()
	GameState.current_chapter = 0
	GameState.add_item("lewet_staff")
	GameState.essences = ["black", "red"]
	var packed := load("res://scenes/HubWorld.tscn") as PackedScene
	var hub := packed.instantiate()
	get_tree().root.add_child(hub)
	await _settle(100)
	await _capture("09_hub_world")

	# Pause menu
	var pause := hub.get_node_or_null("Pause") as CanvasLayer
	if pause != null and pause.has_method("open"):
		pause.call("open")
		await _settle(40)
		await _capture("10_pause_menu")
		if pause.has_method("close"):
			pause.call("close")
		await get_tree().process_frame

	# Satchel / inventory (autoload PlayerBag)
	var bag := get_node_or_null("/root/PlayerBag")
	if bag != null and bag.has_method("open"):
		# Seed a fuller bag for the guide
		GameState.essences = ["black", "red", "gold"]
		GameState.add_item("master_pattern")
		GameState.inventory_changed.emit()
		bag.call("open")
		await _settle(45)
		await _capture("11_satchel")
		if bag.has_method("close"):
			bag.call("close")

	_free(hub)


func _shoot_chapters() -> void:
	var chap := [
		["12_chapter1", "res://scenes/Chapter1.tscn", 1],
		["13_chapter2", "res://scenes/Chapter2.tscn", 2],
		["14_chapter3", "res://scenes/Chapter3.tscn", 3],
		["15_chapter4", "res://scenes/Chapter4.tscn", 4],
	]
	for row in chap:
		_seed_house(int(row[2]))
		await _shoot_scene(str(row[0]), str(row[1]))


func _shoot_final_house() -> void:
	_seed_house(5)
	GameState.add_item("master_pattern")
	ColorRestoration.reset()
	var packed := load("res://scenes/Chapter5.tscn") as PackedScene
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	await _settle(110)
	# Try unlock beam UI if player exists
	var player := get_tree().get_first_node_in_group("player")
	if player != null and "has_light_beam" in player:
		player.has_light_beam = true
		if player.has_method("grant_light_beam"):
			player.call("grant_light_beam")
	await _settle(30)
	await _capture("16_chapter5_sacred_loom")
	_free(scene)

	# Restored hub after Color Burst
	GameState.game_completed = true
	GameState.completed_houses = [1, 2, 3, 4, 5]
	GameState.essences = ["black", "red", "gold"]
	GameState.objective = "The world is whole."
	ColorRestoration.restore_world(0.0)
	await _shoot_scene("17_hub_restored", "res://scenes/HubWorld.tscn")


func _seed_house(house: int) -> void:
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
		2:
			GameState.essences = ["black"]
		3:
			GameState.essences = ["black", "red"]
		4, 5:
			GameState.essences = ["black", "red", "gold"]


func _settle(frames: int = SETTLE) -> void:
	for _i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw


func _capture(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var out_path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(out_path)
	print("%s  %s" % [shot_name, "ok" if error == OK else "fail %d" % error])


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
