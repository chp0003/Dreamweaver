extends Control
## Lore Codex: the replayability screen.
##
## Lists every cultural entry in the game, locked ones included (title hidden),
## alongside the run's score and rank. Reachable from the Gateway, the pause
## menu, and the credits.

@onready var entry_list: VBoxContainer = %EntryList
@onready var detail_title: Label = %DetailTitle
@onready var detail_body: Label = %DetailBody
@onready var summary_label: Label = %SummaryLabel
@onready var back_button: Button = %BackButton
@onready var detail_portrait: TextureRect = %DetailPortrait

var _first_unlocked_button: Button


func _ready() -> void:
	Audio.set_ambience(0.3, 14.0)
	back_button.pressed.connect(_on_back_pressed)
	_build_summary()
	_build_list()
	_show_welcome()


func _build_summary() -> void:
	var unlocked := GameState.lore.size()
	var total := CultureData.total_lore()
	summary_label.text = "Rank: %s        Score: %d        Lore: %d / %d        Houses restored: %d / %d" % [
		GameState.rank(),
		GameState.score,
		unlocked,
		total,
		GameState.completed_houses.size(),
		Houses.count(),
	]


func _build_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()

	for entry in CultureData.LORE_ENTRIES:
		var entry_id := str(entry["id"])
		var unlocked: bool = GameState.lore.has(entry_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if unlocked:
			button.text = str(entry["title"])
			button.pressed.connect(_show_entry.bind(entry_id))
			if _first_unlocked_button == null:
				_first_unlocked_button = button
		else:
			button.text = "??? - not yet remembered"
			button.disabled = true
			button.theme_type_variation = &"GhostButton"
		entry_list.add_child(button)


func _show_entry(entry_id: String) -> void:
	var entry := CultureData.lore_entry(entry_id)
	if entry.is_empty():
		return
	detail_title.text = str(entry["title"])
	detail_body.text = str(entry["text"])
	_set_detail_portrait(str(entry.get("portrait", "")))


func _show_welcome() -> void:
	if _first_unlocked_button != null:
		_first_unlocked_button.grab_focus()
		return
	detail_title.text = "Nothing remembered yet"
	detail_body.text = "Lore entries are earned by answering the ancestors correctly, finding hidden things in the Houses, and restoring each sacred colour. Come back once you have walked a House."
	_set_detail_portrait("")


func _set_detail_portrait(path: String) -> void:
	if detail_portrait == null:
		return
	var tex := PlaceholderProp.load_cutout_texture(path)
	detail_portrait.texture = tex
	detail_portrait.visible = tex != null


func _on_back_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)
