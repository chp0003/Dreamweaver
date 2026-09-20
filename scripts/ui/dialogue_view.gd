class_name DialogueView
extends CanvasLayer
## Reusable dialogue box for NPCs, the Narrator, and branching choices.
##
## Chapters await it directly:
##     await dialogue.play([
##         {"speaker": "Spirit of the Fiber", "text": "I have forgotten..."},
##         "A line with no speaker is narration.",
##     ])
##     var pick := await dialogue.ask("Which thread?", ["Black", "Red"])
##
## Lines type on with visible_characters (not visible_ratio) so autowrap never
## clips mid-word into "Five hous".

signal finished
signal choice_made(index: int)

const CHARS_PER_SECOND := 48.0

@onready var panel: Control = %Panel
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var continue_hint: Label = %ContinueHint
@onready var choice_box: VBoxContainer = %ChoiceBox
@onready var portrait: TextureRect = %Portrait
@onready var dock: Control = $Root/Dock

var _typing: Tween
var _awaiting_advance := false
var _advance_requested := false
var _choosing := false
var _line_length := 0
var _presented := false
var _hint_tween: Tween


func _ready() -> void:
	layer = 115
	visible = false
	choice_box.visible = false
	add_to_group("dialogue_view")
	if portrait != null:
		var well := portrait.get_parent() as PanelContainer
		if well != null:
			well.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			well.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_advance or event.is_echo():
		return
	var advance := event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("interact") \
		or event.is_action_pressed("attack")
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		advance = advance or (mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if advance:
		get_viewport().set_input_as_handled()
		_advance_requested = true


func play(lines: Array) -> void:
	visible = true
	choice_box.visible = false
	_present()
	for line in lines:
		var speaker := ""
		var body := ""
		if typeof(line) == TYPE_DICTIONARY:
			speaker = str((line as Dictionary).get("speaker", ""))
			body = str((line as Dictionary).get("text", ""))
		else:
			body = str(line)
		await _show_line(speaker, body)
	visible = false
	_presented = false
	finished.emit()


func ask(prompt: String, options: Array, speaker := "") -> int:
	visible = true
	_present()
	await _show_line(speaker, prompt, false)

	_build_choices(options)
	_choosing = true
	var pick: int = await choice_made
	choice_box.visible = false
	visible = false
	_presented = false
	return pick


func say_line(speaker: String, body: String) -> void:
	visible = true
	choice_box.visible = false
	_present()
	await _show_line(speaker, body)
	visible = false
	_presented = false


func is_busy() -> bool:
	return visible


func _show_line(speaker: String, body: String, wait_for_input := true) -> void:
	speaker_label.text = speaker.to_upper() if not speaker.is_empty() else "NARRATOR"
	speaker_label.visible = true
	_style_speaker(speaker)
	_set_portrait(speaker)
	text_label.text = body
	_line_length = body.length()
	text_label.visible_characters = 0
	continue_hint.text = "E  ·  continue"
	continue_hint.visible = wait_for_input
	_pulse_hint(false)

	_start_typing()
	if not wait_for_input:
		await _wait_for_typing()
		return

	_awaiting_advance = true
	_advance_requested = false

	while true:
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
		if _advance_requested:
			_advance_requested = false
			if text_label.visible_characters >= 0 and text_label.visible_characters < _line_length:
				_kill_typing()
				text_label.visible_characters = -1
			else:
				break
		elif _typing == null and (text_label.visible_characters < 0 \
				or text_label.visible_characters >= _line_length):
			continue_hint.text = "E  ·  continue  ▸"
			_pulse_hint(true)

	_awaiting_advance = false


func _wait_for_typing() -> void:
	while _typing != null:
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame


func _start_typing() -> void:
	_kill_typing()
	text_label.visible_characters = 0
	if _line_length <= 0:
		text_label.visible_characters = -1
		return
	var duration := clampf(float(_line_length) / CHARS_PER_SECOND, 0.2, 5.5)
	_typing = create_tween()
	_typing.tween_method(_set_visible_chars, 0, _line_length, duration)
	_typing.tween_callback(func() -> void:
		text_label.visible_characters = -1
		_typing = null
	)


func _set_visible_chars(count: int) -> void:
	text_label.visible_characters = count


func _kill_typing() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null


func _build_choices(options: Array) -> void:
	for child in choice_box.get_children():
		child.queue_free()

	for i in range(options.size()):
		var button := Button.new()
		button.text = "✦   %s" % str(options[i])
		button.theme_type_variation = &"GhostButton"
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		choice_box.add_child(button)
	choice_box.visible = true
	UiMotion.cascade(choice_box, 0.0, UiMotion.FAST, 8.0, 0.04)


func _present() -> void:
	if _presented or dock == null:
		return
	_presented = true
	var home := dock.position
	dock.position = home + Vector2(0.0, 28.0)
	dock.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(dock, "modulate:a", 1.0, UiMotion.BASE)
	tween.tween_property(dock, "position", home, UiMotion.SLOW)


func _pulse_hint(on: bool) -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	if not on or continue_hint == null:
		if continue_hint != null:
			continue_hint.modulate.a = 0.75
		return
	_hint_tween = UiMotion.shimmer(continue_hint, 0.4, 1.0, 1.4)


func _style_speaker(speaker: String) -> void:
	var key := speaker.to_lower()
	var color := Palette.GOLD_SACRED
	if speaker.is_empty():
		color = Palette.CREAM_STONE
	elif "fun kdungon" in key:
		color = Palette.GOLD_SUN
	elif "spirit" in key:
		color = Palette.DREAM_AURORA
	elif "master" in key or "ancestor" in key:
		color = Palette.GOLD_SUN
	elif "shadow" in key:
		color = Palette.DREAM_MIST
	elif "s'lang" in key or "slang" in key:
		color = Palette.GOLD_BRASS
	speaker_label.add_theme_color_override("font_color", Palette.alpha(color, 0.95))


func _set_portrait(speaker: String) -> void:
	if portrait == null:
		return
	var path := _portrait_path(speaker)
	var tex: Texture2D = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	portrait.texture = tex
	portrait.visible = tex != null
	var well := portrait.get_parent() as CanvasItem
	if well != null and well != panel:
		well.visible = tex != null
	if tex != null:
		var key := speaker.to_lower()
		if "fun kdungon" in key or "master" in key:
			portrait.modulate = Color.WHITE
			portrait.custom_minimum_size = Vector2(108, 148)
		elif "spirit" in key:
			portrait.modulate = Color(0.92, 0.95, 1.05, 0.92)
			portrait.custom_minimum_size = Vector2(92, 112)
		elif "shadow" in key:
			portrait.modulate = Color(0.55, 0.5, 0.62)
			portrait.custom_minimum_size = Vector2(92, 112)
		else:
			portrait.modulate = Color.WHITE
			portrait.custom_minimum_size = Vector2(92, 112)


func _portrait_path(speaker: String) -> String:
	var key := speaker.to_lower()
	if key.is_empty():
		return ""
	if "s'lang" in key or key == "slang":
		return "res://assets/images/characters/slang.png"
	if "fun kdungon" in key:
		return "res://assets/images/characters/fun_kdungon.png"
	if "spirit" in key:
		return "res://assets/images/characters/spirit_of_the_fiber.png"
	if "master" in key:
		return "res://assets/images/characters/fun_kdungon.png"
	if "shadow" in key:
		return "res://assets/images/enemies/shadow_minion.png"
	return "res://assets/images/characters/slang.png"


func _on_choice_pressed(index: int) -> void:
	if not _choosing:
		return
	_choosing = false
	Audio.play_sfx(Audio.Sfx.PICKUP)
	choice_made.emit(index)
