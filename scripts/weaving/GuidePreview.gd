class_name GuidePreview
extends Node2D

# Small pattern preview (top right) and the large finished-cloth view (complete panel).

const PATTERN_DATA_SCRIPT = preload("res://scripts/weaving/PatternData.gd")
const PREVIEW_CELL := 2
const CLOTH_CELL := 5
const GOLD := Color("#C99A4B")
const FRINGE := Color("#BFA878")

var pattern: Array = []
var current_row := 0
var cloth_mode := false
var stars := 0

func set_pattern(new_pattern: Array) -> void:
	pattern = new_pattern
	current_row = 0
	cloth_mode = false
	stars = 0
	queue_redraw()

func set_current_row(row: int) -> void:
	current_row = row
	queue_redraw()

func show_cloth() -> void:
	cloth_mode = true
	queue_redraw()

func set_stars(count: int) -> void:
	stars = clampi(count, 0, 3)
	queue_redraw()

func _draw() -> void:
	if pattern.is_empty():
		return
	if cloth_mode:
		_draw_cloth()
	else:
		_draw_preview()

func _draw_preview() -> void:
	var size := PATTERN_DATA_SCRIPT.COLS * PREVIEW_CELL
	draw_rect(Rect2(-2, -2, size + 4, size + 4), GOLD)
	draw_rect(Rect2(-1, -1, size + 2, size + 2), Color("#1A0F0A"))
	for row in range(PATTERN_DATA_SCRIPT.ROWS):
		var y := (PATTERN_DATA_SCRIPT.ROWS - 1 - row) * PREVIEW_CELL
		for col in range(PATTERN_DATA_SCRIPT.COLS):
			var color: Color = PATTERN_DATA_SCRIPT.yarn_color(int(pattern[row][col]))
			if row > current_row:
				color = color.darkened(0.55)
			draw_rect(Rect2(col * PREVIEW_CELL, y, PREVIEW_CELL, PREVIEW_CELL), color)
	var marker_y := (PATTERN_DATA_SCRIPT.ROWS - 1 - current_row) * PREVIEW_CELL
	draw_rect(Rect2(-5, marker_y, 2, PREVIEW_CELL), GOLD)
	draw_rect(Rect2(size + 3, marker_y, 2, PREVIEW_CELL), GOLD)

func _draw_cloth() -> void:
	var size := PATTERN_DATA_SCRIPT.COLS * CLOTH_CELL
	var origin := Vector2(-size / 2.0, -size / 2.0)
	# Fringe of loose warp ends above and below the cloth.
	for i in range(0, size, 3):
		draw_rect(Rect2(origin.x + i, origin.y - 4, 1, 4), FRINGE)
		draw_rect(Rect2(origin.x + i, origin.y + size, 1, 4), FRINGE)
	draw_rect(Rect2(origin.x - 3, origin.y - 1, size + 6, size + 2), Color("#0E0A09"))
	for row in range(PATTERN_DATA_SCRIPT.ROWS):
		var y := origin.y + (PATTERN_DATA_SCRIPT.ROWS - 1 - row) * CLOTH_CELL
		for col in range(PATTERN_DATA_SCRIPT.COLS):
			var id := int(pattern[row][col])
			var x := origin.x + col * CLOTH_CELL
			var base: Color = PATTERN_DATA_SCRIPT.yarn_color(id)
			draw_rect(Rect2(x, y, CLOTH_CELL, CLOTH_CELL), base)
			draw_rect(Rect2(x, y, CLOTH_CELL, 1), PATTERN_DATA_SCRIPT.yarn_highlight(id))
			draw_rect(Rect2(x, y + CLOTH_CELL - 1, CLOTH_CELL, 1), base.darkened(0.3))
	for i in range(3):
		var lit := i < stars
		var color := GOLD if lit else Color("#3A2C27")
		_draw_star(Vector2(-14 + i * 14, size / 2.0 + 9.0), 6.0, color)

func _draw_star(center: Vector2, outer: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var radius := outer if i % 2 == 0 else outer * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
