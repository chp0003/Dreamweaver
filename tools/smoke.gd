extends Node
## Temporary runtime smoke test. Run headless:
##   Godot_v4.x_console.exe --headless --path . res://tools/Smoke.tscn
##
## Validate.tscn only proves every scene *loads*. This actually runs each
## gameplay scene with a signed-in account and a mid-run save, letting it tick
## for a while so _build_world() and the first beats of _run_chapter() execute,
## then moves on. Any runtime failure shows up as an ERROR / SCRIPT ERROR line in
## the output above the summary.
##
## Scenes are mounted under the root rather than via change_scene_to_file, so
## this node survives the whole sweep. MainGame is left out on purpose: it is a
## router whose only job is to call SceneFader, which would replace this node
## mid-run and strand the sweep.

const FRAMES_PER_SCENE := 90

const SCENES := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/Tutorial.tscn",
	"res://scenes/HubWorld.tscn",
	"res://scenes/Chapter1.tscn",
	"res://scenes/Chapter2.tscn",
	"res://scenes/Chapter3.tscn",
	"res://scenes/Chapter4.tscn",
	"res://scenes/Chapter5.tscn",
	"res://scenes/GameOver.tscn",
	"res://scenes/LoreCodex.tscn",
	"res://scenes/Ending.tscn",
]

const MINI_GAMES := [
	"res://scenes/minigames/FiberSorting.tscn",
	"res://scenes/minigames/PigmentMashing.tscn",
	"res://scenes/minigames/PatternMemory.tscn",
	"res://scenes/minigames/WarpAlignment.tscn",
	"res://scenes/minigames/CultureQuiz.tscn",
	"res://scenes/minigames/RhythmTrack.tscn",
	"res://scenes/minigames/QteSequence.tscn",
]


func _ready() -> void:
	await _sign_in()
	_seed_progress()

	print("\n===== SMOKE TEST =====")

	for path in MINI_GAMES:
		await _tick_mini_game(str(path))

	for path in SCENES:
		await _tick_scene(str(path))

	print("Scenes ticked: %d   Mini-games ticked: %d" % [SCENES.size(), MINI_GAMES.size()])
	print("Look above for ERROR / SCRIPT ERROR lines; none means the run is clean.")
	print("======================\n")
	get_tree().quit(0)


## A throwaway account so AccountManager has a session to save progress into.
func _sign_in() -> void:
	var error := await AccountManager.try_register("smoketest", "abaca123", "abaca123")
	if not error.is_empty():
		error = await AccountManager.try_login("smoketest", "abaca123")
	if not error.is_empty():
		print("SMOKE: could not sign in (%s)" % error)


## Mid-run state: staff taken, every House open, three essences and the pattern
## banked, so Chapter 5 and the Hub's final door are both reachable.
func _seed_progress() -> void:
	GameState.new_game()
	GameState.add_item("lewet_staff")
	for essence in ["black", "red", "gold"]:
		GameState.add_essence(str(essence))
	GameState.add_item("master_pattern")
	for house_id in range(1, Houses.count() + 1):
		GameState.unlock_house(house_id)
	GameState.set_current_chapter(1)


func _tick_scene(path: String) -> void:
	print("-> %s" % path)
	var packed := load(path) as PackedScene
	if packed == null:
		print("   FAILED to load")
		return
	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	for _i in range(FRAMES_PER_SCENE):
		await get_tree().process_frame
	if is_instance_valid(instance):
		instance.queue_free()
	await get_tree().process_frame


## Mini-games are Controls a chapter adds to its UI layer, so add them the same
## way rather than making them the whole scene.
func _tick_mini_game(path: String) -> void:
	print("-> %s" % path)
	var packed := load(path) as PackedScene
	if packed == null:
		print("   FAILED to load")
		return
	var host := CanvasLayer.new()
	add_child(host)
	var game := packed.instantiate()
	host.add_child(game)
	for _i in range(FRAMES_PER_SCENE):
		await get_tree().process_frame
	host.queue_free()
