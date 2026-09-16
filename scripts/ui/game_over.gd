extends Control
## Retry screen. Reached when S'lang runs out of lives, or when a quiz has been
## failed past the allowed number of wrong answers.
##
## Retrying restarts the *current chapter* only - never the whole game - and
## hands back a full set of lives.

@onready var reason_label: Label = %ReasonLabel
@onready var detail_label: Label = %DetailLabel
@onready var retry_button: Button = %RetryButton
@onready var hub_button: Button = %HubButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	Audio.set_ambience(0.25, 0.0)
	Audio.play_sfx(Audio.Sfx.FAIL)

	var chapter := GameState.current_chapter
	if chapter > 0:
		reason_label.text = "The Pattern Loosened"
		if chapter == 4:
			detail_label.text = "%s remains unwoven.\n\nLore you have already remembered stays with you. The score of this attempt is unwoven. Your three lives return, and the House begins again." % Houses.name_for(chapter)
		else:
			detail_label.text = "%s remains unwoven.\n\nYou keep every essence and every lore entry already earned. Your three lives return, and the House begins again." % Houses.name_for(chapter)
		retry_button.text = "Retake %s" % Houses.short_name_for(chapter)
	else:
		reason_label.text = "The Dream Slipped"
		detail_label.text = "S'lang has not yet taken up the Lewet Staff.\n\nBegin the first step again."
		retry_button.text = "Try Again"

	retry_button.pressed.connect(_on_retry_pressed)
	hub_button.pressed.connect(_on_hub_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	hub_button.disabled = GameState.current_chapter <= 0
	retry_button.grab_focus()
	var motes := LightMotes.new()
	motes.mote_count = 24
	add_child(motes)
	var column := $Center/Panel/Column as Control
	if column != null:
		UiMotion.cascade(column, 0.1, UiMotion.BASE, 12.0, 0.06)
	UiStyle.glow_label(reason_label, Palette.DREAM_LANTERN, 14)


func _on_retry_pressed() -> void:
	if SceneFader.is_busy():
		return
	# A retry is a fresh attempt at the same House: lives restored, quiz strikes
	# wiped, progress in other Houses untouched.
	GameState.refill_lives()
	GameState.reset_quiz_mistakes()
	if GameState.current_chapter == 4:
		GameState.restore_house_score()
	SceneFader.fade_to_scene(GameState.current_chapter_scene())


func _on_hub_pressed() -> void:
	if SceneFader.is_busy():
		return
	GameState.refill_lives()
	GameState.reset_quiz_mistakes()
	SceneFader.fade_to_scene(AccountManager.HUB_SCENE)


func _on_menu_pressed() -> void:
	if SceneFader.is_busy():
		return
	GameState.refill_lives()
	GameState.reset_quiz_mistakes()
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)
