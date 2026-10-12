extends MiniGameBase
## Chapter 5, Phase 3 - "The Finishing Stitch".
##
## A run of W/A/S/D prompts with reaction windows that tighten as the sequence
## goes on. A wrong key or a missed window costs the attempt; the chapter offers
## the retry itself, so this runs with a small attempt budget rather than sending
## the player straight to the game-over screen.

signal prompt_resolved(hit: bool)
## Fired on the last correct key, before the minigame closes, so the Color
## Burst can leave the loom on that same input.
signal final_stitch

const PROMPTS := [
	{"action": "move_forward", "glyph": "W"},
	{"action": "move_left", "glyph": "A"},
	{"action": "move_back", "glyph": "S"},
	{"action": "move_right", "glyph": "D"},
]

@export var prompt_count := 8
@export var start_window := 0.92
@export var end_window := 0.55

const OverlayScript := preload("res://scripts/ui/tnalak_overlay.gd")

var _glyph_label: Label
var _window_bar: ProgressBar
var _step_label: Label
var _overlay: Control
var _key_labels: Array[Label] = []

var _step := 0
var _required := 0
var _window := 0.0
var _window_left := 0.0
var _waiting := false


func _configure() -> void:
	compact = true
	mini_game_title = "Last stitch"
	instructions = ""
	time_limit = 0.0
	max_attempts = 3
	reward_score = 400


func _build_content(_parent: Control) -> void:
	# The stitch is the flashing letters, not the minigame card.
	if _backdrop != null:
		_backdrop.visible = false
	if _panel != null:
		_panel.visible = false

	_overlay = OverlayScript.new()
	_overlay.name = "TnalakOverlay"
	add_child(_overlay)
	move_child(_overlay, 0)
	if _overlay.has_method("fade_in"):
		_overlay.call("fade_in", 0.28)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.theme_type_variation = &"FieldLabel"
	_step_label.add_theme_font_size_override("font_size", 24)
	stack.add_child(_step_label)

	_glyph_label = Label.new()
	_glyph_label.text = ""
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.theme_type_variation = &"HeaderLabel"
	_glyph_label.add_theme_font_size_override("font_size", 128)
	_glyph_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.62))
	_glyph_label.custom_minimum_size = Vector2(220.0, 140.0)
	stack.add_child(_glyph_label)

	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 18)
	stack.add_child(keys)
	for prompt in PROMPTS:
		var key := Label.new()
		key.text = str(prompt["glyph"])
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2(72.0, 72.0)
		key.add_theme_font_size_override("font_size", 36)
		key.add_theme_color_override("font_color", Color(0.55, 0.48, 0.32))
		keys.add_child(key)
		_key_labels.append(key)

	_window_bar = ProgressBar.new()
	_window_bar.custom_minimum_size = Vector2(360.0, 14.0)
	_window_bar.show_percentage = false
	_window_bar.max_value = 1.0
	stack.add_child(_window_bar)


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
		fail("Too slow on letter %d. Try again." % (_step))


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
		fail("Wrong key on letter %d. Try again." % _step)
		return

	prompt_resolved.emit(true)
	Audio.play_sfx(Audio.Sfx.BELL)
	Audio.play_sfx(Audio.Sfx.PARRY)
	GameState.add_score(60)
	_flash(Color(1.15, 1.05, 0.62))
	if _overlay != null and _overlay.has_method("strike"):
		_overlay.call("strike")
	if _step >= prompt_count:
		_complete_stitch()
		return
	await get_tree().create_timer(0.05).timeout
	if running and is_inside_tree():
		_next_prompt()


## The last key does not wait on a results card. The burst leaves the loom now.
func _complete_stitch() -> void:
	if not running:
		return
	running = false
	_waiting = false
	Audio.play_brass_shock()
	final_stitch.emit()
	GameState.add_score(reward_score)
	finished.emit(true)


func _next_prompt() -> void:
	_step += 1
	_required = randi() % PROMPTS.size()
	# Windows tighten as the finale builds.
	var t := float(_step - 1) / maxf(1.0, float(prompt_count - 1))
	_window = lerpf(start_window, end_window, clampf(t, 0.0, 1.0))
	_window_left = _window

	_glyph_label.text = str(PROMPTS[_required]["glyph"])
	_glyph_label.modulate = Color(1.4, 1.2, 0.7)
	_glyph_label.scale = Vector2(1.45, 1.45)
	var tween := create_tween()
	tween.tween_property(_glyph_label, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(_glyph_label, "modulate", Color.WHITE, 0.08)
	for i in range(_key_labels.size()):
		var lit := i == _required
		_key_labels[i].modulate = Color(1.35, 1.15, 0.55) if lit else Color(0.45, 0.4, 0.32)
		_key_labels[i].scale = Vector2(1.18, 1.18) if lit else Vector2.ONE

	_step_label.text = "Stitch   %d / %d" % [_step, prompt_count]
	_window_bar.value = 1.0
	set_status("")
	_waiting = true


func _flash(color: Color) -> void:
	_glyph_label.modulate = color
	var tween := create_tween()
	tween.tween_property(_glyph_label, "modulate", Color.WHITE, 0.2)
