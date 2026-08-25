extends MiniGameBase
## Chapter 5, Phase 3 - "The Finishing Stitch".
##
## A run of W/A/S/D prompts with reaction windows that tighten as the sequence
## goes on. A wrong key or a missed window costs the attempt; the chapter offers
## the retry itself, so this runs with a small attempt budget rather than sending
## the player straight to the game-over screen.

signal prompt_resolved(hit: bool)

const PROMPTS := [
	{"action": "move_forward", "glyph": "W"},
	{"action": "move_left", "glyph": "A"},
	{"action": "move_back", "glyph": "S"},
	{"action": "move_right", "glyph": "D"},
]

@export var prompt_count := 6
@export var start_window := 1.15
@export var end_window := 0.55

var _glyph_label: Label
var _window_bar: ProgressBar
var _step_label: Label

var _step := 0
var _required := 0
var _window := 0.0
var _window_left := 0.0
var _waiting := false


func _configure() -> void:
	compact = true
	mini_game_title = "The Finishing Stitch"
	instructions = "Press each key before its window closes."
	time_limit = 0.0
	max_attempts = 3
	reward_score = 400


func _build_content(parent: Control) -> void:
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.theme_type_variation = &"FieldLabel"
	parent.add_child(_step_label)

	_glyph_label = Label.new()
	_glyph_label.text = ""
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.theme_type_variation = &"HeaderLabel"
	_glyph_label.add_theme_font_size_override("font_size", 84)
	parent.add_child(_glyph_label)

	_window_bar = ProgressBar.new()
	_window_bar.custom_minimum_size = Vector2(0.0, 16.0)
	_window_bar.show_percentage = false
	_window_bar.max_value = 1.0
	parent.add_child(_window_bar)


func _reset_round() -> void:
	_step = 0
	_waiting = false
	_next_prompt()


func _process(delta: float) -> void:
	super._process(delta)
	if not running or not _waiting:
		return
	_window_left -= delta
	_window_bar.value = clampf(_window_left / _window, 0.0, 1.0)
	if _window_left <= 0.0:
		_waiting = false
		prompt_resolved.emit(false)
		fail("The window closed on step %d. The stitch did not take." % (_step))


func _unhandled_input(event: InputEvent) -> void:
	if not running or not _waiting or event.is_echo():
		return
	for i in range(PROMPTS.size()):
		if event.is_action_pressed(str(PROMPTS[i]["action"])):
			get_viewport().set_input_as_handled()
			_answer(i)
			return


func _answer(index: int) -> void:
	_waiting = false
	if index != _required:
		prompt_resolved.emit(false)
		Audio.play_sfx(Audio.Sfx.FAIL)
		fail("Wrong thread on step %d." % _step)
		return

	prompt_resolved.emit(true)
	Audio.play_sfx(Audio.Sfx.PARRY)
	GameState.add_score(60)
	_flash(Color(0.6, 0.85, 0.55))
	if _step >= prompt_count:
		succeed("The last stitch closes. The pattern is whole.")
		return
	await get_tree().create_timer(0.18).timeout
	if running and is_inside_tree():
		_next_prompt()


func _next_prompt() -> void:
	_step += 1
	_required = randi() % PROMPTS.size()
	# Windows tighten as the finale builds.
	var t := float(_step - 1) / maxf(1.0, float(prompt_count - 1))
	_window = lerpf(start_window, end_window, clampf(t, 0.0, 1.0))
	_window_left = _window

	_glyph_label.text = str(PROMPTS[_required]["glyph"])
	_glyph_label.modulate = Color.WHITE
	_glyph_label.scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.tween_property(_glyph_label, "scale", Vector2.ONE, 0.14)

	_step_label.text = "Stitch %d of %d" % [_step, prompt_count]
	_window_bar.value = 1.0
	set_status("")
	_waiting = true


func _flash(color: Color) -> void:
	_glyph_label.modulate = color
	var tween := create_tween()
	tween.tween_property(_glyph_label, "modulate", Color.WHITE, 0.2)
