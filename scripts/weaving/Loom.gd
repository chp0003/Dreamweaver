class_name Loom
extends Node2D

signal stitch_changed(column: int, color_id: int, correct: bool)
signal mistake_made(total: int)
signal yarn_changed(color_id: int)
signal row_locked(row: int)
signal beat_hit(row: int)
signal row_settled(row: int)
signal row_cleared

const COLS := 16
const ROWS := 16
const CELL_W := 12
const ROW_H := 6
const LOOM_LEFT := 70
const LOOM_TOP := 55
const LOOM_W := 192
const LOOM_H := 96
const DRAG_GRAB_RADIUS := 14.0
const GHOST_ALPHA := 0.3
const BEATER_REST_GAP := 12.0
const SHUTTLE_START_X := 64.0

const WRONG_OUTLINE := Color("#C96B32")
const GOLD := Color("#C99A4B")
const WARP := Color("#8A7448")
const WARP_HIGHLIGHT := Color("#B39B66")
const WOOD := Color("#6B4A2E")
const WOOD_HIGHLIGHT := Color("#8F6A44")
const WOOD_SHADOW := Color("#3F2A18")
const WARP_X := [1, 5, 9]

const PATTERN_DATA_SCRIPT = preload("res://scripts/weaving/PatternData.gd")

var pattern: Array = []
var woven: Array = []
var current_row := 0
var selected_yarn: int = PATTERN_DATA_SCRIPT.BEIGE
var is_dragging := false
var input_enabled := true
var mistakes := 0
var beat := 0.0

var _locked := false
var _last_column := -1
var _hover_col := -1
var _shuttle_x := SHUTTLE_START_X
var _shuttle_target := SHUTTLE_START_X
var _flash := 0.0
var _flash_row := -1
var _time := 0.0
var _tween: Tween

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func configure(new_pattern: Array) -> void:
	pattern = new_pattern
	woven.clear()
	for _row in range(ROWS):
		var empty_row: Array[int] = []
		for _col in range(COLS):
			empty_row.append(-1)
		woven.append(empty_row)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	beat = 0.0
	_flash = 0.0
	_flash_row = -1
	mistakes = 0
	current_row = 0
	input_enabled = true
	_locked = false
	_shuttle_x = SHUTTLE_START_X
	_shuttle_target = SHUTTLE_START_X
	selected_yarn = PATTERN_DATA_SCRIPT.BEIGE
	_reset_row()

func set_yarn(color_id: int) -> void:
	var clamped := clampi(color_id, PATTERN_DATA_SCRIPT.BEIGE, PATTERN_DATA_SCRIPT.BLACK)
	if clamped == selected_yarn:
		return
	selected_yarn = clamped
	yarn_changed.emit(clamped)

func advance_row(row: int) -> void:
	current_row = clampi(row, 0, ROWS - 1)
	_locked = false
	_reset_row()

func reset_row() -> void:
	if _locked or not input_enabled:
		return
	_reset_row()
	row_cleared.emit()

func wrong_count() -> int:
	var total := 0
	for col in range(COLS):
		var value: int = woven[current_row][col]
		if value >= 0 and value != int(pattern[current_row][col]):
			total += 1
	return total

func _reset_row() -> void:
	is_dragging = false
	_last_column = -1
	for col in range(COLS):
		woven[current_row][col] = -1
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_shuttle_x = lerpf(_shuttle_x, _shuttle_target, 1.0 - exp(-delta * 28.0))
	_flash = maxf(0.0, _flash - delta * 3.0)
	_hover_col = -1
	if input_enabled and not _locked and not pattern.is_empty():
		var p := get_local_mouse_position()
		if _grab_rect().has_point(p):
			_hover_col = _column_at(p.x)
	queue_redraw()

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not input_enabled or _locked or pattern.is_empty():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_1, KEY_KP_1:
					set_yarn(PATTERN_DATA_SCRIPT.BEIGE)
				KEY_2, KEY_KP_2:
					set_yarn(PATTERN_DATA_SCRIPT.RED)
				KEY_3, KEY_KP_3:
					set_yarn(PATTERN_DATA_SCRIPT.BLACK)
				KEY_R, KEY_BACKSPACE:
					reset_row()
	# Touch is handled through emulated mouse events (the Godot default),
	# so handling InputEventScreenTouch as well would weave every stitch twice.
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var local_point := get_local_mouse_position()
		if mouse.pressed:
			if _grab_rect().has_point(local_point):
				is_dragging = true
				_paint_at(local_point.x)
				get_viewport().set_input_as_handled()
		elif is_dragging:
			_end_drag()
	elif event is InputEventMouseMotion and is_dragging:
		_paint_at(get_local_mouse_position().x)

func _end_drag() -> void:
	is_dragging = false
	_last_column = -1
	if _row_complete():
		_lock_row()

func _column_at(x: float) -> int:
	return clampi(floori((x - LOOM_LEFT) / float(CELL_W)), 0, COLS - 1)

func _paint_at(x: float) -> void:
	var column := _column_at(x)
	if column == _last_column:
		return
	var from_col := column
	if _last_column >= 0:
		from_col = _last_column + (1 if column > _last_column else -1)
	var step := 1 if column >= from_col else -1
	# Fill every column crossed since the last event, in either direction,
	# so a fast drag never leaves gaps.
	for index in range(from_col, column + step, step):
		_stitch(index)
	_last_column = column
	_shuttle_target = LOOM_LEFT + column * CELL_W + CELL_W * 0.5
	if _row_complete():
		_lock_row()

func _stitch(index: int) -> void:
	var previous: int = woven[current_row][index]
	woven[current_row][index] = selected_yarn
	var correct := selected_yarn == int(pattern[current_row][index])
	if not correct and previous != selected_yarn:
		mistakes += 1
		mistake_made.emit(mistakes)
	stitch_changed.emit(index, selected_yarn, correct)

func _row_complete() -> bool:
	for col in range(COLS):
		if woven[current_row][col] < 0:
			return false
		if woven[current_row][col] != int(pattern[current_row][col]):
			return false
	return true

func _lock_row() -> void:
	if _locked:
		return
	_locked = true
	is_dragging = false
	_last_column = -1
	_flash_row = current_row
	_flash = 1.0
	row_locked.emit(current_row)
	# The beater (reed) swings down to pack the new weft against the cloth.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "beat", 1.0, 0.10).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(func() -> void: beat_hit.emit(current_row))
	_tween.tween_property(self, "beat", 0.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(func() -> void: row_settled.emit(current_row))

# ---------------------------------------------------------------- geometry

func _row_top(row: int) -> float:
	return float(LOOM_TOP + LOOM_H - ROW_H * (row + 1))

func _row_rect() -> Rect2:
	return Rect2(LOOM_LEFT, _row_top(current_row), LOOM_W, ROW_H)

func _grab_rect() -> Rect2:
	return _row_rect().grow(DRAG_GRAB_RADIUS)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_draw_frame()
	_draw_warp()
	_draw_beams()
	if pattern.is_empty():
		return
	_draw_rows()
	_draw_beater()
	_draw_shuttle()
	_draw_hover()

func _draw_frame() -> void:
	draw_rect(Rect2(58, 42, 216, 118), Color("#0E0A09"))
	draw_rect(Rect2(60, 44, 212, 114), Color("#2A1810"))
	draw_rect(Rect2(60, 44, 212, 1), GOLD)
	draw_rect(Rect2(60, 157, 212, 1), Color("#5E1D10"))
	draw_rect(Rect2(LOOM_LEFT, LOOM_TOP, LOOM_W, LOOM_H), Color("#1A0F0A"))
	# Side posts.
	for post_x in [62, 262]:
		draw_rect(Rect2(post_x, 46, 8, 110), WOOD)
		draw_rect(Rect2(post_x, 46, 1, 110), WOOD_HIGHLIGHT)
		draw_rect(Rect2(post_x + 7, 46, 1, 110), WOOD_SHADOW)

func _draw_warp() -> void:
	for col in range(COLS):
		var x := LOOM_LEFT + col * CELL_W
		for k in WARP_X:
			draw_rect(Rect2(x + k, LOOM_TOP, 2, LOOM_H), WARP)
			draw_rect(Rect2(x + k, LOOM_TOP, 1, LOOM_H), WARP_HIGHLIGHT)

func _draw_beams() -> void:
	# Top beam and bottom beam; the warp threads wrap around both.
	for beam in [Rect2(62, 46, 208, 9), Rect2(62, 151, 208, 6)]:
		draw_rect(beam, WOOD)
		draw_rect(Rect2(beam.position.x, beam.position.y, beam.size.x, 1), WOOD_HIGHLIGHT)
		draw_rect(Rect2(beam.position.x, beam.end.y - 1, beam.size.x, 1), WOOD_SHADOW)
		for col in range(COLS):
			for k in WARP_X:
				draw_rect(Rect2(LOOM_LEFT + col * CELL_W + k, beam.position.y + 1, 2, beam.size.y - 2), Color(WARP, 0.55))

func _draw_rows() -> void:
	var last_row := mini(current_row, ROWS - 1)
	for row in range(last_row + 1):
		var top := _row_top(row)
		var is_current := row == current_row
		for col in range(COLS):
			var x := float(LOOM_LEFT + col * CELL_W)
			var target := int(pattern[row][col])
			var value := int(woven[row][col])
			if value < 0:
				if is_current:
					var ghost: Color = PATTERN_DATA_SCRIPT.yarn_color(target)
					ghost.a = GHOST_ALPHA
					draw_rect(Rect2(x, top, CELL_W, ROW_H), ghost)
				continue
			_draw_stitch(x, top, row, col, value)
			if is_current and value != target:
				var pulse := 0.65 + 0.35 * sin(_time * 9.0)
				draw_rect(Rect2(x + 1, top + 1, CELL_W - 2, ROW_H - 2), Color(WRONG_OUTLINE, pulse), false, 1.0)
		if row == _flash_row and _flash > 0.0:
			draw_rect(Rect2(LOOM_LEFT, top, LOOM_W, ROW_H), Color(1.0, 0.95, 0.8, _flash * 0.5))
		if is_current and not _locked:
			var glow := 0.6 + 0.4 * sin(_time * 5.0)
			draw_rect(Rect2(LOOM_LEFT - 2, top - 2, LOOM_W + 4, ROW_H + 4), Color(GOLD, glow), false, 1.0)

func _draw_stitch(x: float, top: float, row: int, col: int, color_id: int) -> void:
	var base: Color = PATTERN_DATA_SCRIPT.yarn_color(color_id)
	var shade := base.darkened(0.35)
	draw_rect(Rect2(x, top, CELL_W, ROW_H), base)
	draw_rect(Rect2(x, top + ROW_H - 1, CELL_W, 1), shade)
	draw_rect(Rect2(x, top, CELL_W, 1), PATTERN_DATA_SCRIPT.yarn_highlight(color_id))
	if (col + row) % 2 == 0:
		# Weft passes under the warp here, so the warp threads show through.
		var sliver := base.lerp(WARP, 0.45)
		for k in WARP_X:
			draw_rect(Rect2(x + k, top + 1, 2, 3), sliver)
	else:
		# Weft floats over the warp: show a little yarn twist.
		draw_rect(Rect2(x + 3, top + 2, 1, 1), shade)
		draw_rect(Rect2(x + 8, top + 3, 1, 1), shade)

func _draw_beater() -> void:
	var gap := lerpf(BEATER_REST_GAP, -1.0, beat)
	var y := roundf(_row_top(current_row) - 3.0 - gap)
	var left := float(LOOM_LEFT - 6)
	var width := float(LOOM_W + 12)
	draw_rect(Rect2(left, y, width, 3), WOOD)
	draw_rect(Rect2(left, y, width, 1), WOOD_HIGHLIGHT)
	draw_rect(Rect2(left, y + 2, width, 1), WOOD_SHADOW)
	for i in range(0, LOOM_W, 3):
		draw_rect(Rect2(LOOM_LEFT + i, y + 3, 1, 2), WOOD_SHADOW)

func _draw_shuttle() -> void:
	var alpha := 1.0 - beat
	if alpha <= 0.02:
		return
	var sx := roundf(_shuttle_x)
	var sy := roundf(_row_top(current_row) - 6.0)
	if is_dragging:
		sy += roundf(sin(_time * 40.0) * 0.6)
	var body := Color(WOOD_HIGHLIGHT, alpha)
	var points := PackedVector2Array([
		Vector2(sx - 9, sy), Vector2(sx - 5, sy - 3), Vector2(sx + 5, sy - 3),
		Vector2(sx + 9, sy), Vector2(sx + 5, sy + 3), Vector2(sx - 5, sy + 3),
	])
	draw_colored_polygon(points, body)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(WOOD_SHADOW, alpha), 1.0)
	var yarn: Color = PATTERN_DATA_SCRIPT.yarn_color(selected_yarn)
	draw_rect(Rect2(sx - 4, sy - 1, 8, 2), Color(yarn, alpha))

func _draw_hover() -> void:
	if _hover_col < 0 or is_dragging or _locked:
		return
	var rect := Rect2(LOOM_LEFT + _hover_col * CELL_W, _row_top(current_row), CELL_W, ROW_H)
	draw_rect(rect, Color("#F5E8C7", 0.85), false, 1.0)
