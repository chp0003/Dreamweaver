extends Control
## Router between the story scenes and the gameplay scenes.
##
## Both the prologue and the Gateway's Load Game land here, so there is exactly
## one place that decides where a weaver belongs:
##
##   no Lewet Staff yet   ->  Tutorial      (the first step)
##   game already beaten  ->  Hub           (free roam in full colour)
##   otherwise            ->  Hub           (pick the next unlocked House)

const HOLD_TIME := 0.9

@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel


func _ready() -> void:
	AccountManager.mark_intro_seen()
	GameState.load_from_account()
	Audio.set_ambience(0.4, 0.0)

	var destination := _resolve_destination()
	await get_tree().create_timer(HOLD_TIME).timeout
	if is_inside_tree():
		SceneFader.fade_to_scene(destination)


func _resolve_destination() -> String:
	if not GameState.has_item("lewet_staff"):
		status_label.text = "The room is gray"
		detail_label.text = "Something on the floor is not."
		return AccountManager.TUTORIAL_SCENE

	if GameState.game_completed:
		status_label.text = "The world is whole"
		detail_label.text = "Rank: %s   -   Score: %d" % [GameState.rank(), GameState.score]
		return AccountManager.HUB_SCENE

	status_label.text = "The highland of the Houses"
	detail_label.text = "%d of %d restored. Lives: %d" % [
		GameState.completed_houses.size(), Houses.count(), GameState.lives]
	return AccountManager.HUB_SCENE
