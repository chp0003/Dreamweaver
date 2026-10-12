class_name MiniGameBase
extends Control
## Shared shell for every mini-game in the game.
##
## The base owns everything the five mini-games have in common: the framed
## panel, the countdown, the attempt budget, the pass/fail banner and the single
## `finished(success)` result a chapter awaits. Subclasses only implement:
##
##     func _build_content(parent: Control) -> void   # lay out the puzzle once
##     func _reset_round() -> void                    # deal a fresh attempt
##
## and call `succeed()` / `fail()` when the player resolves it. Chapters run one
## with `ChapterBase.run_mini_game()`.

signal finished(success: bool)

@export var mini_game_title := "Mini-Game"
@export var mini_game_subtitle := ""
@export var instructions := ""
## 0 or less disables the countdown.
@export var time_limit := 60.0
## Total tries before the mini-game reports failure to the chapter.
@export var max_attempts := 3
@export var reward_score := 250
## Compact mini-games dock to the bottom of the screen and let the world show
## through, for in-combat use (Chapter 5's rhythm track and QTE).
@export var compact := false
## Compact combat overlays need enough height for four rhythm lanes at 16:9.
@export var compact_height := 330.0
@export var compact_side_margin := 48

## Filled by subclasses.
var content: VBoxContainer
## 1-based index of the current try.
var attempt := 0
var running := false

var _time_left := 0.0
var _clock_on := false
var _begin_button: Button
var _backdrop: ColorRect
var _panel: WovenFrame
var _title_label: Label
var _subtitle_label: Label
var _instruction_label: Label
var _timer_bar: ProgressBar
var _status_label: Label
var _attempts_label: Label
var _result_layer: Control
var _result_title: Label
var _result_art: TextureRect
var _result_body: Label
var _result_buttons: HBoxContainer
var _theme: Theme


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS if compact else Control.MOUSE_FILTER_STOP
	_theme = load("res://assets/themes/dreamweaver.tres") as Theme
	if _theme != null:
		theme = _theme

	_configure()
	_build_chrome()
	_build_content(content)
	start_round()


func _process(delta: float) -> void:
	if not _clock_on or time_limit <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_timer_bar.value = _time_left
	if _time_left <= 0.0:
		fail("The moment passed. Time ran out.")


# --------------------------------------------------------------------------
# Subclass hooks
# --------------------------------------------------------------------------

## Name and describe the mini-game, before any UI exists. Chapters are free to
## override `time_limit`, `max_attempts` and `reward_score` instead, which this
## hook deliberately leaves alone.
func _configure() -> void:
	pass


## Build the puzzle UI once. `parent` is a VBoxContainer inside the frame.
func _build_content(_parent: Control) -> void:
	pass


## Deal a fresh attempt. Called for every try, including the first.
func _reset_round() -> void:
	pass


# --------------------------------------------------------------------------
# Round control
# --------------------------------------------------------------------------

func start_round() -> void:
	attempt += 1
	_clock_on = false
	_time_left = time_limit
	_result_layer.visible = false
	if _result_art != null:
		_result_art.visible = false
		_result_art.texture = null
	_timer_bar.visible = time_limit > 0.0
	_timer_bar.max_value = maxf(time_limit, 0.001)
	_timer_bar.value = _time_left
	_refresh_attempts()
	var timed := time_limit > 0.0
	running = not timed
	if _begin_button != null:
		_begin_button.visible = timed
	_reset_round()
	if timed:
		set_status("Read the instructions. The timer starts when you begin.")


func _on_begin_pressed() -> void:
	if time_limit <= 0.0 or _clock_on:
		return
	running = true
	_clock_on = true
	_time_left = time_limit
	if _timer_bar != null:
		_timer_bar.value = _time_left
	if _begin_button != null:
		_begin_button.visible = false
	set_status("")


func succeed(message := "") -> void:
	if not running:
		return
	running = false
	_clock_on = false
	GameState.add_score(reward_score)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_show_result(true, message)


func fail(message := "") -> void:
	if not running:
		return
	running = false
	_clock_on = false
	Audio.play_sfx(Audio.Sfx.FAIL)
	_show_result(false, message)


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func set_result_texture(texture: Texture2D) -> void:
	if _result_art == null:
		return
	_result_art.texture = texture
	_result_art.visible = texture != null


func time_left() -> float:
	return _time_left


func attempts_left() -> int:
	return maxi(0, max_attempts - attempt)


func set_instructions(text: String) -> void:
	instructions = text
	if _instruction_label != null:
		_instruction_label.text = text
		_instruction_label.visible = not text.is_empty()


# --------------------------------------------------------------------------
# Chrome
# --------------------------------------------------------------------------

func _build_chrome() -> void:
	if not compact:
		_backdrop = ColorRect.new()
		_backdrop.name = "Backdrop"
		_backdrop.color = Palette.DREAM_ABYSS
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_backdrop)

	var holder := MarginContainer.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if compact:
		holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		holder.offset_top = -compact_height
		holder.add_theme_constant_override("margin_left", compact_side_margin)
		holder.add_theme_constant_override("margin_right", compact_side_margin)
		holder.add_theme_constant_override("margin_bottom", 16)
	else:
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_theme_constant_override("margin_left", 90)
		holder.add_theme_constant_override("margin_top", 56)
		holder.add_theme_constant_override("margin_right", 90)
		holder.add_theme_constant_override("margin_bottom", 56)
	add_child(holder)

	_panel = WovenFrame.new()
	_panel.name = "Frame"
	_panel.pad = 22
	_panel.fill = Palette.alpha(Palette.DREAM_NIGHT, 0.86)
	_panel.lit = true
	_panel.draw_kleng = true
	_panel.header_band = true
	holder.add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title_label = Label.new()
	_title_label.text = mini_game_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.add_theme_font_size_override("font_size", 24 if compact else 30)
	column.add_child(_title_label)

	if not mini_game_subtitle.is_empty():
		_subtitle_label = Label.new()
		_subtitle_label.text = mini_game_subtitle
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.theme_type_variation = &"TaglineLabel"
		column.add_child(_subtitle_label)

	_instruction_label = Label.new()
	_instruction_label.text = instructions
	_instruction_label.visible = not instructions.is_empty()
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.add_theme_font_size_override("font_size", 22)
	_instruction_label.add_theme_color_override("font_color", Color(0.87, 0.8, 0.64))
	column.add_child(_instruction_label)

	_begin_button = Button.new()
	_begin_button.text = "Begin"
	_begin_button.visible = false
	_begin_button.custom_minimum_size = Vector2(200.0, 44.0)
	_begin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_begin_button.pressed.connect(_on_begin_pressed)
	column.add_child(_begin_button)

	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_timer_bar.show_percentage = false
	_timer_bar.add_theme_stylebox_override("background", UiStyle.bar_track())
	_timer_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.GOLD_SACRED))
	column.add_child(_timer_bar)

	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	column.add_child(content)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	footer.add_child(_status_label)

	_attempts_label = Label.new()
	_attempts_label.theme_type_variation = &"FieldLabel"
	_attempts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_attempts_label)

	_build_result_layer()


func _build_result_layer() -> void:
	_result_layer = Control.new()
	_result_layer.name = "Result"
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.visible = false
	add_child(_result_layer)

	var shade := ColorRect.new()
	shade.color = Palette.alpha(Palette.DREAM_ABYSS, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)

	var panel := WovenFrame.new()
	panel.pad = 28
	panel.fill = Palette.alpha(Palette.DREAM_NIGHT, 0.9)
	panel.lit = true
	panel.draw_kleng = true
	panel.header_band = true
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_result_title = Label.new()
	_result_title.theme_type_variation = &"HeaderLabel"
	_result_title.add_theme_font_size_override("font_size", 32)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_title)

	_result_art = TextureRect.new()
	_result_art.name = "ResultArt"
	_result_art.visible = false
	_result_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_art.custom_minimum_size = Vector2(220.0, 280.0)
	_result_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_result_art)

	_result_body = Label.new()
	_result_body.custom_minimum_size = Vector2(520.0, 0.0)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.theme_type_variation = &"TaglineLabel"
	_result_body.add_theme_font_size_override("font_size", 22)
	column.add_child(_result_body)

	_result_buttons = HBoxContainer.new()
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_result_buttons)


func _show_result(success: bool, message: String) -> void:
	for child in _result_buttons.get_children():
		child.queue_free()

	if success:
		_result_title.text = "Restored"
		_result_body.text = message if not message.is_empty() \
			else "The pattern holds. Colour returns to this corner of the House."
		_add_result_button("Continue", func() -> void: finished.emit(true))
	else:
		if _result_art != null:
			_result_art.visible = false
			_result_art.texture = null
		_result_title.text = "Frayed"
		var retries := attempts_left()
		if retries > 0:
			_result_body.text = "%s\n\n%d attempt%s remaining." % [
				message if not message.is_empty() else "The thread slipped.",
				retries,
				"" if retries == 1 else "s",
			]
			_add_result_button("Try Again", start_round)
			_add_result_button("Step Away", func() -> void: finished.emit(false), true)
		else:
			_result_body.text = "%s\n\nNo attempts remain. S'lang must gather herself and begin this work again." % [
				message if not message.is_empty() else "The thread slipped."
			]
			_add_result_button("Continue", func() -> void: finished.emit(false))

	_result_layer.visible = true


func _add_result_button(label: String, action: Callable, ghost := false) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(200.0, 44.0)
	if ghost:
		button.theme_type_variation = &"GhostButton"
	button.pressed.connect(action)
	_result_buttons.add_child(button)
	if _result_buttons.get_child_count() == 1:
		button.grab_focus.call_deferred()


func _refresh_attempts() -> void:
	if _attempts_label == null:
		return
	if max_attempts <= 1:
		_attempts_label.text = ""
		return
	_attempts_label.text = "Attempt %d of %d" % [attempt, max_attempts]


func _bar_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	return style
