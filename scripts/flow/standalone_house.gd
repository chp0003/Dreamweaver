extends ChapterBase
## Loads one HouseQuest in a single-room scene (smoke tests, Shot, retries of
## an isolated House). The live game uses the open ridge instead.

@export var quest_script: Script

var _quest: HouseQuest


func _build_world() -> void:
	if quest_script == null:
		push_error("StandaloneHouse: missing quest_script")
		return
	_quest = quest_script.new() as HouseQuest
	if _quest == null:
		push_error("StandaloneHouse: quest_script is not a HouseQuest")
		return
	_quest.host = self
	_quest.house_id = chapter_id
	_quest.region_origin = Vector2.ZERO
	_quest.name = "HouseQuest"
	add_child(_quest)
	_quest.build()


func _run_chapter() -> void:
	if _quest == null:
		return
	Audio.set_house(chapter_id)
	_quest.start_quest()
	await until(func() -> bool: return _quest.is_complete() or is_finished())


func _exit_tree() -> void:
	Audio.clear_house()


func _on_player_attacked(swing_position: Vector2, facing: Vector2) -> void:
	if _quest != null and _quest.has_method("_on_player_attacked"):
		_quest._on_player_attacked(swing_position, facing)
	else:
		shake_camera(4.5)


func on_house_completed(_house_id: int, next_scene := "") -> void:
	objective("Return to the ridge and choose the next House.")
	set_player_input(false)
	SceneFader.fade_to_scene(next_scene if not next_scene.is_empty()
		else AccountManager.HUB_SCENE)
