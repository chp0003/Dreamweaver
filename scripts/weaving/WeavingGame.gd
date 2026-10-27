class_name WeavingGame
extends Control

signal weaving_completed

const PATTERN_DATA_SCRIPT = preload("res://scripts/weaving/PatternData.gd")
const WEAVE_SFX = preload("res://scripts/weaving/WeaveSfx.gd")

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

var current_pattern_id := "diamond"
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

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_pixel_canvas()
	get_viewport().size_changed.connect(_fit_pixel_canvas)
	_setup_audio()
	_setup_buttons()
	loom.stitch_changed.connect(_on_stitch_changed)
	loom.mistake_made.connect(_on_mistake_made)
	loom.yarn_changed.connect(_refresh_yarn_ui)
	loom.row_locked.connect(_on_row_locked)
	loom.beat_hit.connect(_on_beat_hit)
	loom.row_settled.connect(_on_row_settled)
	loom.row_cleared.connect(_on_row_cleared)
	start_weaving("diamond")

func _process(delta: float) -> void:
	if not weaving_active:
		return
	elapsed += delta
	if int(elapsed) != _last_second:
		_last_second = int(elapsed)
		_refresh_stats()

func _unhandled_input(event: InputEvent) -> void:
	if complete_panel.visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
			start_weaving(current_pattern_id)

func _fit_pixel_canvas() -> void:
	var viewport_size := get_viewport_rect().size
	var pixel_scale: float = floor(minf(viewport_size.x / 320.0, viewport_size.y / 180.0))
	pixel_scale = maxf(pixel_scale, 1.0)
	scale = Vector2.ONE * pixel_scale
	position = (viewport_size - Vector2(320.0, 180.0) * pixel_scale) * 0.5

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
		"diamond": $PatternPalette/Diamond,
		"stripes": $PatternPalette/Stripes,
		"zigzag": $PatternPalette/Zigzag,
	}
	for id in pattern_buttons:
		var button: Button = pattern_buttons[id]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(start_weaving.bind(id))
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
	current_pattern_id = pattern_id
	pattern = PATTERN_DATA_SCRIPT.pattern(pattern_id)
	current_row = 0
	mistakes = 0
	elapsed = 0.0
	_last_second = -1
	_prev_column = -1
	_direction = 1
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
