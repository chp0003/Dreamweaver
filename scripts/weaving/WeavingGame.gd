class_name WeavingGame
extends Control

signal weaving_completed
signal cloth_completed(cloth: Variant)
signal finished(success: bool)

const PATTERN_DATA_SCRIPT = preload("res://scripts/weaving/PatternData.gd")
const WEAVE_SFX = preload("res://scripts/weaving/WeaveSfx.gd")
const UI_FONT = preload("res://assets/fonts/CrimsonPro-Regular.ttf")
const TITLE_FONT = preload("res://assets/fonts/Cinzel-Bold.ttf")

const GOLD := Color("#C99A4B")
const CREAM := Color("#F5E8C7")
const DARK := Color("#1A0F0A")
const WOOD := Color("#6B4A2E")
const ORANGE := Color("#C96B32")

@onready var guide: GuidePreview = $Guide
@onready var loom: Loom = $Loom
@onready var tip_label: Label = $TipLabel
@onready var progress_label: Label = $ProgressLabel
@onready var yarn_status: Label = $YarnStatus
@onready var pattern_name: Label = $PatternName
@onready var stats_label: Label = $StatsLabel
@onready var complete_panel: Control = $CompletePanel
@onready var complete_cloth: GuidePreview = $CompletePanel/Cloth
@onready var complete_stats: Label = $CompletePanel/Stats
@onready var complete_fact: Label = $CompletePanel/Fact
@onready var sfx_stitch: AudioStreamPlayer = $SfxStitch
@onready var sfx_tight: AudioStreamPlayer = $SfxTight
@onready var sfx_done: AudioStreamPlayer = $SfxDone
@onready var sfx_wrong: AudioStreamPlayer = $SfxWrong

const ART_SIZE := Vector2(320.0, 180.0)
const DISPLAY_SCALE := 4.0

var current_pattern_id := "house_1"
var assigned_pattern_id := ""
var locked_to_assignment := false
var pattern: Array = []
var current_row := 0
var mistakes := 0
var elapsed := 0.0
var weaving_active := false

var yarn_buttons: Array[Button] = []
var pattern_buttons: Dictionary = {}

var _prev_column := -1
var _direction := 1
var _last_second := -1
var _last_stitch_ms := 0
var _last_wrong_ms := 0
var _tip_tween: Tween
var _art_viewport: SubViewport
var _completion_emitted := false

func _ready() -> void:
	_apply_ui_text_style()
	_setup_audio()
	_setup_buttons()
	_setup_resolution_layers()
	loom.stitch_changed.connect(_on_stitch_changed)
	loom.mistake_made.connect(_on_mistake_made)
	loom.yarn_changed.connect(_refresh_yarn_ui)
	loom.row_locked.connect(_on_row_locked)
	loom.beat_hit.connect(_on_beat_hit)
	loom.row_settled.connect(_on_row_settled)
	loom.row_cleared.connect(_on_row_cleared)
	var initial_pattern := assigned_pattern_id if not assigned_pattern_id.is_empty() else "house_1"
	start_weaving(initial_pattern)

func _apply_ui_text_style() -> void:
	_style_text($Title, 44, TITLE_FONT, false)
	_style_text($Subtitle, 22)
	_style_text($ProgressLabel, 24)
	_style_text($TipLabel, 26)
	_style_text($YarnCaption, 22)
	_style_text($YarnPalette/Beige, 22)
	_style_text($YarnPalette/Red, 22)
	_style_text($YarnPalette/Black, 22)
	_style_text($YarnStatus, 22)
	_style_text($GuideCaption, 22)
	_style_text($PatternName, 20)
	_style_text($StatsLabel, 22)
	_style_text($KeysHint, 20)
	_style_text($CompletePanel/Title, 44, TITLE_FONT, false)
	_style_text($CompletePanel/Stats, 26)
	_style_text($CompletePanel/Fact, 26)
	_style_text($CompletePanel/WeaveAgain, 24)
	_style_text($CompletePanel/NextPattern, 24)

func _style_text(control: Control, font_size: int, font: Font = UI_FONT, outlined: bool = true) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", font_size)
	if outlined:
		control.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		control.add_theme_constant_override("outline_size", 3)

func _setup_resolution_layers() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art_view := SubViewportContainer.new()
	art_view.name = "ArtView"
	art_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_view.stretch = true
	art_view.stretch_shrink = int(DISPLAY_SCALE)
	art_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art_view)
	move_child(art_view, 0)

	var art_viewport := SubViewport.new()
	art_viewport.name = "ArtViewport"
	art_viewport.size = Vector2i(320, 180)
	art_viewport.transparent_bg = false
	art_viewport.handle_input_locally = false
	art_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	art_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	art_view.add_child(art_viewport)
	_art_viewport = art_viewport

	var hud := Control.new()
	hud.name = "Hud"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.z_index = 100
	add_child(hud)

	var background: Control = $Background
	background.reparent(art_viewport)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Loom.reparent(art_viewport)
	$Guide.reparent(art_viewport)
	complete_cloth.reparent(art_viewport)
	complete_cloth.position = Vector2(160.0, 64.0)

	for child in get_children():
		if child is Control and child != art_view and child != hud:
			(child as Control).reparent(hud)
	_scale_hud_tree(hud)
	_layout_yarn_palette()

func _scale_hud_tree(node: Control) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control == complete_panel:
				_scale_hud_tree(control)
				continue
			control.offset_left *= DISPLAY_SCALE
			control.offset_top *= DISPLAY_SCALE
			control.offset_right *= DISPLAY_SCALE
			control.offset_bottom *= DISPLAY_SCALE
			control.custom_minimum_size *= DISPLAY_SCALE
			if control is Container:
				var separation := control.get_theme_constant("separation")
				control.add_theme_constant_override("separation", int(separation * DISPLAY_SCALE))
			_scale_hud_tree(control)

func _layout_yarn_palette() -> void:
	var palette: VBoxContainer = $Hud/YarnPalette
	palette.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	palette.position = Vector2(16.0, 216.0)
	palette.size = Vector2(200.0, 272.0)
	palette.custom_minimum_size = Vector2(200.0, 272.0)
	palette.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	palette.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	palette.add_theme_constant_override("separation", 8)
	for button in yarn_buttons:
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.custom_minimum_size = Vector2(200.0, 80.0)
		button.size = Vector2(200.0, 80.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _process(delta: float) -> void:
	if not weaving_active:
		return
	elapsed += delta
	if int(elapsed) != _last_second:
		_last_second = int(elapsed)
		_refresh_stats()

func _input(event: InputEvent) -> void:
	if _art_viewport == null:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		loom.handle_input_event(event, _art_viewport.get_mouse_position())
	elif event is InputEventKey:
		loom.handle_input_event(event, Vector2.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if complete_panel.visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
			start_weaving(current_pattern_id)

# ---------------------------------------------------------------- setup

func _setup_audio() -> void:
	sfx_stitch.stream = WEAVE_SFX.stitch()
	sfx_tight.stream = WEAVE_SFX.tight()
	sfx_done.stream = WEAVE_SFX.done()
	sfx_wrong.stream = WEAVE_SFX.wrong()
	sfx_stitch.volume_db = -14.0
	sfx_tight.volume_db = -6.0
	sfx_done.volume_db = -6.0
	sfx_wrong.volume_db = -10.0

func _setup_buttons() -> void:
	yarn_buttons.clear()
	for node_name in ["Beige", "Red", "Black"]:
		yarn_buttons.append($YarnPalette.get_node(node_name) as Button)
	for i in range(yarn_buttons.size()):
		yarn_buttons[i].focus_mode = Control.FOCUS_NONE
		yarn_buttons[i].pressed.connect(_select_yarn.bind(i))
	pattern_buttons = {
		"house_1": $PatternPalette/Diamond,
		"house_2": $PatternPalette/Stripes,
		"house_3": $PatternPalette/Zigzag,
	}
	for id in pattern_buttons:
		var button: Button = pattern_buttons[id]
		button.focus_mode = Control.FOCUS_NONE
		if not locked_to_assignment:
			button.pressed.connect(start_weaving.bind(id))
		else:
			button.disabled = true
	$PatternPalette.visible = not locked_to_assignment
	var again: Button = $CompletePanel/WeaveAgain
	var next: Button = $CompletePanel/NextPattern
	again.focus_mode = Control.FOCUS_NONE
	next.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func() -> void: start_weaving(current_pattern_id))
	next.pressed.connect(func() -> void: start_weaving(PATTERN_DATA_SCRIPT.next_id(current_pattern_id)))
	_apply_button_style(again, WOOD, GOLD, CREAM)
	_apply_button_style(next, Color("#8B2E1A"), GOLD, CREAM)

func _make_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border_width)
	style.border_color = border
	return style

func _apply_button_style(button: Button, fill: Color, border: Color, text: Color, border_width := 1) -> void:
	button.add_theme_stylebox_override("normal", _make_style(fill, border, border_width))
	button.add_theme_stylebox_override("hover", _make_style(fill.lightened(0.15), CREAM, border_width))
	button.add_theme_stylebox_override("pressed", _make_style(fill.darkened(0.2), border, border_width))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, text)

# ---------------------------------------------------------------- flow

func start_weaving(pattern_id: String) -> void:
	if locked_to_assignment and pattern_id != assigned_pattern_id:
		return
	if not PATTERN_DATA_SCRIPT.IDS.has(pattern_id):
		pattern_id = "house_1"
	current_pattern_id = pattern_id
	pattern = PATTERN_DATA_SCRIPT.pattern(pattern_id)
	current_row = 0
	mistakes = 0
	elapsed = 0.0
	_last_second = -1
	_prev_column = -1
	_direction = 1
	_completion_emitted = false
	weaving_active = true
	complete_panel.visible = false
	guide.set_pattern(pattern)
	guide.set_current_row(0)
	loom.configure(pattern)
	pattern_name.text = PATTERN_DATA_SCRIPT.display_name(pattern_id)
	_refresh_progress()
	_refresh_yarn_ui(loom.selected_yarn)
	_refresh_pattern_ui()
	_refresh_stats()
	_show_row_hint()

func _select_yarn(color_id: int) -> void:
	loom.set_yarn(color_id)
	_refresh_yarn_ui(color_id)

func _on_stitch_changed(column: int, _color_id: int, correct: bool) -> void:
	if _prev_column >= 0 and column != _prev_column:
		_direction = 1 if column > _prev_column else -1
	_prev_column = column
	var now := Time.get_ticks_msec()
	if correct:
		if now - _last_stitch_ms > 40:
			_last_stitch_ms = now
			sfx_stitch.pitch_scale = 0.9 + randf() * 0.3
			sfx_stitch.play()
	elif now - _last_wrong_ms > 120:
		_last_wrong_ms = now
		sfx_wrong.play()
	if loom.wrong_count() > 0:
		_set_tip("Orange outline: switch yarn and weave it again.")
		return
	var next_column := column + _direction
	if next_column >= 0 and next_column < PATTERN_DATA_SCRIPT.COLS \
			and loom.woven[current_row][next_column] < 0:
		var needed := int(pattern[current_row][next_column])
		if needed != loom.selected_yarn:
			_set_tip("Next stitch: switch to %s." % PATTERN_DATA_SCRIPT.yarn_label(needed))
			return
	_set_tip("Good. Keep weaving.")

func _on_mistake_made(total: int) -> void:
	mistakes = total
	_refresh_stats()
	_flash_tip(ORANGE)

func _on_row_cleared() -> void:
	_prev_column = -1
	_direction = 1
	_set_tip("Row cleared. Weave it again.")

func _on_row_locked(_row: int) -> void:
	_set_tip("Row complete!")
	_flash_tip(GOLD)

func _on_beat_hit(_row: int) -> void:
	sfx_tight.pitch_scale = 0.95 + randf() * 0.1
	sfx_tight.play()

func _on_row_settled(row: int) -> void:
	current_row = row + 1
	if current_row >= PATTERN_DATA_SCRIPT.ROWS:
		_show_complete()
		return
	loom.advance_row(current_row)
	guide.set_current_row(current_row)
	_prev_column = -1
	_direction = 1
	_refresh_progress()
	_show_row_hint()

func _show_row_hint() -> void:
	var row: Array = pattern[current_row]
	var changes := 0
	for col in range(1, row.size()):
		if row[col] != row[col - 1]:
			changes += 1
	if changes == 0:
		_set_tip("One color this row: %s." % PATTERN_DATA_SCRIPT.yarn_label(int(row[0])))
	else:
		_set_tip("Trace the faded row. It changes color %d time%s." % [changes, "" if changes == 1 else "s"])

func _show_complete() -> void:
	weaving_active = false
	loom.input_enabled = false
	var stars := 3 if mistakes <= 4 else (2 if mistakes <= 16 else 1)
	complete_cloth.set_pattern(pattern)
	complete_cloth.show_cloth()
	complete_cloth.set_stars(stars)
	complete_stats.text = "TIME %s    MISTAKES %d" % [_format_time(elapsed), mistakes]
	complete_fact.text = PATTERN_DATA_SCRIPT.random_fact()
	complete_panel.modulate.a = 0.0
	complete_panel.visible = true
	create_tween().tween_property(complete_panel, "modulate:a", 1.0, 0.4)
	sfx_done.play()
	weaving_completed.emit()
	cloth_completed.emit(null)
	if not _completion_emitted:
		_completion_emitted = true
		call_deferred("_emit_finished")

func _emit_finished() -> void:
	if is_inside_tree():
		finished.emit(true)

# ---------------------------------------------------------------- UI

func _refresh_progress() -> void:
	progress_label.text = "ROW %02d / %02d" % [current_row + 1, PATTERN_DATA_SCRIPT.ROWS]

func _refresh_stats() -> void:
	stats_label.text = "ERRORS %d\nTIME %s" % [mistakes, _format_time(elapsed)]

func _refresh_yarn_ui(color_id: int) -> void:
	yarn_status.text = PATTERN_DATA_SCRIPT.yarn_label(color_id)
	for i in range(yarn_buttons.size()):
		var selected := i == color_id
		var fill: Color = PATTERN_DATA_SCRIPT.yarn_color(i)
		if not selected:
			fill = fill.darkened(0.4)
		var text := DARK if i == PATTERN_DATA_SCRIPT.BEIGE and selected else CREAM
		_apply_button_style(yarn_buttons[i], fill, GOLD if selected else WOOD, text, 2 if selected else 1)

func _refresh_pattern_ui() -> void:
	for id in pattern_buttons:
		var active: bool = id == current_pattern_id
		_apply_button_style(pattern_buttons[id], Color("#8B2E1A") if active else Color("#2A1810"), GOLD if active else WOOD, CREAM)

func _set_tip(text: String) -> void:
	tip_label.text = text

func _flash_tip(color: Color) -> void:
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	tip_label.modulate = color
	_tip_tween = create_tween()
	_tip_tween.tween_property(tip_label, "modulate", Color.WHITE, 0.45)

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]
