extends MiniGameBase
## Chapter 4 - the ancestor statue quizzes, and the reusable quiz UI generally.
##
## The chapter supplies `questions` (see CultureData.STATUE_QUIZZES) before
## adding this to the tree. Wrong answers are counted globally on GameState:
## once a player has given GameState.MAX_QUIZ_MISTAKES wrong answers inside a
## chapter, the quiz reports failure and the chapter sends them to the retry
## screen, which is the "retake" rule.

## Array of { "prompt": String, "options": Array, "answer": int, "lore": String }
@export var questions: Array = []
@export var quiz_speaker := "The Ancestors"

var _prompt_label: Label
var _option_box: VBoxContainer
var _tracker_label: Label
var _index := 0
var _locked := false


func _configure() -> void:
	mini_game_title = "Ancestral Wisdom"
	mini_game_subtitle = quiz_speaker
	instructions = "Answer what the ancestors ask. Wrong answers cost you; %d wrong inside one House and the work must be retaken." % GameState.MAX_QUIZ_MISTAKES
	time_limit = 0.0
	max_attempts = 1
	reward_score = 300


func _build_content(parent: Control) -> void:
	_tracker_label = Label.new()
	_tracker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tracker_label.theme_type_variation = &"FieldLabel"
	parent.add_child(_tracker_label)

	_prompt_label = Label.new()
	_prompt_label.custom_minimum_size = Vector2(720.0, 84.0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 28)
	_prompt_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.79))
	parent.add_child(_prompt_label)

	_option_box = VBoxContainer.new()
	_option_box.add_theme_constant_override("separation", 8)
	_option_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_option_box)


func _reset_round() -> void:
	_index = 0
	_locked = false
	_show_question()


func _show_question() -> void:
	if _index >= questions.size():
		succeed("The ancestors are satisfied. Their knowledge is yours to carry.")
		return

	var question: Dictionary = questions[_index]
	_tracker_label.text = "Question %d of %d      Wrong answers allowed: %d" % [
		_index + 1, questions.size(), GameState.quiz_attempts_left()]
	_prompt_label.text = str(question.get("prompt", ""))

	for child in _option_box.get_children():
		child.queue_free()

	var options: Array = question.get("options", [])
	# Shuffle presentation so a retake is not a memorised button position.
	var order: Array[int] = []
	for i in range(options.size()):
		order.append(i)
	order.shuffle()

	for original_index in order:
		var button := Button.new()
		button.text = str(options[original_index])
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_option_pressed.bind(original_index, button))
		_option_box.add_child(button)

	_locked = false
	set_status("")


func _on_option_pressed(option_index: int, button: Button) -> void:
	if not running or _locked:
		return
	_locked = true

	var question: Dictionary = questions[_index]
	var correct := option_index == int(question.get("answer", 0))

	if correct:
		_tint(button, Color(0.45, 0.68, 0.42))
		Audio.play_sfx(Audio.Sfx.SUCCESS)
		GameState.add_score(120)
		var lore_id := str(question.get("lore", ""))
		if not lore_id.is_empty():
			GameState.unlock_lore(lore_id)
		set_status("Correct. The stone remembers.")
		await get_tree().create_timer(0.75).timeout
		if not running or not is_inside_tree():
			return
		_index += 1
		_show_question()
		return

	_tint(button, Color(0.72, 0.26, 0.22))
	Audio.play_sfx(Audio.Sfx.FAIL)
	var may_continue := GameState.register_quiz_mistake()
	if not may_continue:
		fail("Three answers lost to the forgetting. This House must be taken up again from the beginning.")
		return

	set_status("Not so. %d wrong answer%s left before a retake." % [
		GameState.quiz_attempts_left(),
		"" if GameState.quiz_attempts_left() == 1 else "s",
	])
	await get_tree().create_timer(0.9).timeout
	if not running or not is_inside_tree():
		return
	# Same question again, freshly shuffled.
	_show_question()


func _tint(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	for child in _option_box.get_children():
		(child as Button).disabled = true
