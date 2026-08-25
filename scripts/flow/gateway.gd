extends Control
## "The Gateway" - the main menu, reached after signing in.
##
## New Game wipes this account's run and starts the prologue. Load Game resumes
## wherever the weaver left off, which the MainGame router works out.

@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var codex_button: Button = %CodexButton
@onready var exit_button: Button = %ExitButton
@onready var welcome_label: Label = %WelcomeLabel
@onready var progress_label: Label = %ProgressLabel
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog


func _ready() -> void:
	# Wind off the mountain, with a brass bell somewhere below.
	Audio.set_ambience(0.65, 9.0)

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	confirm_dialog.confirmed.connect(_start_new_game)

	var weaver := AccountManager.current_username()
	welcome_label.text = "Welcome, %s." % weaver if not weaver.is_empty() \
		else "Welcome, weaver."

	var can_load := GameState.has_save()
	load_game_button.disabled = not can_load
	progress_label.text = _progress_summary(can_load)

	(load_game_button if can_load else new_game_button).grab_focus()
	if $Layout/Column/Title is Label:
		UiStyle.glow_label($Layout/Column/Title, Palette.DREAM_LANTERN, 16)
	var emblem := $Layout/Column/Emblem as Control
	if emblem != null:
		await get_tree().process_frame
		UiMotion.bloom(emblem, 0.05, UiMotion.SLOW)
		UiMotion.breathe(emblem, 7.0, 3.8)


func _progress_summary(can_load: bool) -> String:
	if not can_load:
		return "No cloth on the loom yet. Begin a new dream."
	if GameState.game_completed:
		return "The world is whole.  Rank: %s   Score: %d   Lore: %d / %d" % [
			GameState.rank(), GameState.score,
			GameState.lore.size(), CultureData.total_lore()]
	var place := "The first step"
	if GameState.current_chapter > 0:
		place = Houses.name_for(GameState.current_chapter)
	return "%s   -   Houses restored %d / %d   -   Lives %d" % [
		place, GameState.completed_houses.size(), Houses.count(), GameState.lives]


func _on_new_game_pressed() -> void:
	if SceneFader.is_busy():
		return
	if GameState.has_save():
		confirm_dialog.dialog_text = "A run is already on the loom for this weaver.\n\nStarting a new dream unpicks it. Continue?"
		confirm_dialog.popup_centered()
		return
	_start_new_game()


func _start_new_game() -> void:
	if SceneFader.is_busy():
		return
	GameState.new_game()
	SceneFader.fade_to_scene(AccountManager.STORY_INTRO_SCENE)


func _on_load_game_pressed() -> void:
	if SceneFader.is_busy():
		return
	GameState.load_from_account()
	SceneFader.fade_to_scene(AccountManager.MAIN_GAME_SCENE)


func _on_codex_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.CODEX_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
