extends CanvasLayer
## Esc menu available inside every gameplay scene.
##
## Pauses the tree, so anything that must keep running (the grayscale veil, the
## audio generator) sets `process_mode = ALWAYS` for itself.

signal resumed

@onready var panel: Control = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var codex_button: Button = %CodexButton
@onready var hub_button: Button = %HubButton
@onready var menu_button: Button = %MenuButton
@onready var progress_label: Label = %ProgressLabel

## Hidden in the Hub (there is nowhere to retreat to) and in the tutorial.
@export var allow_return_to_hub := true


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	resume_button.pressed.connect(close)
	codex_button.pressed.connect(_on_codex_pressed)
	hub_button.pressed.connect(_on_hub_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	hub_button.visible = allow_return_to_hub
	var motes := LightMotes.new()
	motes.mote_count = 22
	add_child(motes)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func open() -> void:
	if SceneFader.is_busy():
		return
	visible = true
	get_tree().paused = true
	progress_label.text = "%s  ·  cloth %d%%" % [
		Houses.name_for(GameState.current_chapter) if GameState.current_chapter > 0 else "The First Step",
		roundi(GameState.weaving_percent() * 100.0),
	]
	resume_button.grab_focus()
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, UiMotion.BASE)
	var column := panel.get_node_or_null("Column")
	if column != null:
		UiMotion.cascade(column, 0.06, UiMotion.FAST, 8.0, 0.04)


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _on_codex_pressed() -> void:
	get_tree().paused = false
	SceneFader.fade_to_scene(AccountManager.CODEX_SCENE)


func _on_hub_pressed() -> void:
	get_tree().paused = false
	SceneFader.fade_to_scene(AccountManager.HUB_SCENE)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)
