extends Control
## "The Gateway" — modern game main menu after sign-in.
##
## Continue / New Game, Load, Lore Codex, Leaderboard, Settings
## (audio · account · display), Log Out, and Quit. Settings opens a shared
## overlay used across auth screens.

const SETTINGS_SCENE := "res://scenes/ui/SettingsOverlay.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var codex_button: Button = %CodexButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var settings_button: Button = %SettingsButton
@onready var logout_button: Button = %LogoutButton
@onready var quit_button: Button = %QuitButton
@onready var welcome_label: Label = %WelcomeLabel
@onready var progress_label: Label = %ProgressLabel
@onready var user_chip: Label = %UserChip
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var brand: Control = %Brand
@onready var emblem: TextureRect = %Emblem
@onready var title_label: Label = %Title
@onready var menu_host: Control = %MenuHost
@onready var menu_column: VBoxContainer = %Menu
@onready var embers: GPUParticles2D = %Embers
@onready var background: TextureRect = %Background

var _settings: CanvasLayer
var _chapter_picker: Control


func _ready() -> void:
	Audio.play_menu_music()
	Audio.set_ambience(0.18, 0.0)

	_settings = load(SETTINGS_SCENE).instantiate()
	add_child(_settings)

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	confirm_dialog.confirmed.connect(_start_new_game)
	_build_chapter_picker()
	get_viewport().size_changed.connect(_fit_embers)
	_fit_embers()

	var weaver := AccountManager.current_username()
	welcome_label.text = "Welcome back, %s." % weaver if not weaver.is_empty() \
		else "Welcome, weaver."
	user_chip.text = weaver if not weaver.is_empty() else "Weaver"

	var can_load := GameState.has_save()
	continue_button.visible = can_load
	load_game_button.disabled = not can_load
	progress_label.text = _progress_summary(can_load)

	if can_load:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

	UiStyle.glow_label(title_label, Palette.DREAM_LANTERN, 18)
	var motes := LightMotes.new()
	motes.mote_count = 28
	add_child(motes)
	await get_tree().process_frame
	_play_entrance()


func _fit_embers() -> void:
	var size := get_viewport_rect().size
	embers.position = Vector2(size.x * 0.5, size.y + 20.0)
	var mat := embers.process_material as ParticleProcessMaterial
	if mat != null:
		mat.emission_box_extents = Vector3(size.x * 0.55, 10.0, 1.0)


func _play_entrance() -> void:
	background.pivot_offset = background.size * 0.5
	background.scale = Vector2(1.05, 1.05)
	var sky := create_tween()
	sky.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	sky.tween_property(background, "scale", Vector2.ONE, 8.0)

	UiMotion.fade_in(brand, 0.06, UiMotion.SLOW, 24.0)
	UiMotion.bloom(emblem, 0.1, UiMotion.SLOW)
	UiMotion.breathe(emblem, 4.0, 4.0)
	UiMotion.breathe(brand, 3.0, 5.2, 0.35)
	UiMotion.fade_in(menu_host, 0.2, UiMotion.SLOW, 20.0)
	UiMotion.cascade(menu_column, 0.3, UiMotion.BASE, 12.0, 0.05)


func _progress_summary(can_load: bool) -> String:
	if not can_load:
		return "No save yet — start a new dream when you are ready."
	if GameState.game_completed:
		return "World restored · Rank %s · Score %d · Lore %d / %d" % [
			GameState.rank(), GameState.score,
			GameState.lore.size(), CultureData.total_lore()]
	var place := "Prologue"
	if GameState.current_chapter > 0:
		place = Houses.name_for(GameState.current_chapter)
	return "%s · Houses %d / %d · Lives %d" % [
		place, GameState.completed_houses.size(), Houses.count(), GameState.lives]


func _on_continue_pressed() -> void:
	_on_load_game_pressed()


func _on_new_game_pressed() -> void:
	if SceneFader.is_busy():
		return
	if GameState.has_save():
		confirm_dialog.dialog_text = "A save already exists for this account.\n\nStarting a new game will overwrite it. Continue?"
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


func _build_chapter_picker() -> void:
	var toggle := Button.new()
	toggle.name = "TestChapterButton"
	toggle.text = "Test Chapter"
	toggle.custom_minimum_size = Vector2(0, 40)
	toggle.theme_type_variation = &"GhostButton"
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62, 0.9))
	toggle.flat = true
	var slot := load_game_button.get_index() + 1
	menu_column.add_child(toggle)
	menu_column.move_child(toggle, slot)
	toggle.pressed.connect(_toggle_chapter_picker)

	var picker := WovenFrame.new()
	picker.name = "ChapterPicker"
	picker.visible = false
	picker.lit = true
	picker.draw_kleng = true
	picker.pad = 16
	picker.fill = Color(0.086, 0.114, 0.227, 0.92)
	picker.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	picker.offset_left = -760.0
	picker.offset_top = -430.0
	picker.offset_right = -450.0
	picker.offset_bottom = -40.0
	add_child(picker)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_chapter_picker = picker

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	picker.add_child(column)

	var title := Label.new()
	title.text = "TEST A CHAPTER"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 0.9))
	column.add_child(title)

	var note := Label.new()
	note.text = "Replays that house from the start, even if you already finished the game."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62, 0.88))
	column.add_child(note)

	var normal := load_game_button.get_theme_stylebox("normal")
	var hover := load_game_button.get_theme_stylebox("hover")
	var font := load_game_button.get_theme_font("font")
	for house in Houses.LIST:
		var house_id := int(house["id"])
		var button := Button.new()
		button.text = "%d   %s" % [house_id, str(house["short"])]
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 14)
		if font != null:
			button.add_theme_font_override("font", font)
		if normal != null:
			button.add_theme_stylebox_override("normal", normal)
		if hover != null:
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("pressed", hover)
		button.pressed.connect(_jump_to_chapter.bind(house_id))
		column.add_child(button)


func _toggle_chapter_picker() -> void:
	if _chapter_picker == null:
		return
	_chapter_picker.visible = not _chapter_picker.visible


func _jump_to_chapter(house_id: int) -> void:
	if SceneFader.is_busy():
		return
	GameState.prepare_chapter_jump(house_id)
	SceneFader.fade_to_scene(AccountManager.HUB_SCENE)


func _on_codex_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.CODEX_SCENE)


func _on_leaderboard_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.LEADERBOARD_SCENE)


func _on_settings_pressed() -> void:
	if _settings != null and _settings.has_method("open"):
		_settings.open(true)


func _on_logout_pressed() -> void:
	if SceneFader.is_busy():
		return
	await AccountManager.logout()
	SceneFader.fade_to_scene(AccountManager.LOGIN_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
