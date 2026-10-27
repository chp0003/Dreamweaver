class_name Shuttle
extends Control

signal pass_completed(success: bool)

var dragging := false
var start_position := Vector2.ZERO
var yarn_color := Color("#713326")
var _trail: Array[Vector2] = []

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(74, 26)

func reset() -> void:
	position.x = start_position.x
	dragging = false
	_trail.clear()
	queue_redraw()

func set_start(point: Vector2) -> void:
	start_position = point
	position = point

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			dragging = true
			_trail.clear()
			accept_event()
		elif click.button_index == MOUSE_BUTTON_LEFT and not click.pressed and dragging:
			dragging = false
			var distance := position.x - start_position.x
			var required := maxf(get_parent_control().size.x * 0.55, 120.0)
			pass_completed.emit(distance >= required)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		position.x = clampf(position.x + motion.relative.x, start_position.x, get_parent_control().size.x - size.x - 8.0)
		_trail.append(Vector2(size.x * 0.5, size.y * 0.5))
		queue_redraw()

func _draw() -> void:
	for point in _trail:
		draw_circle(point, 3.0, yarn_color)
	draw_rect(Rect2(3, 5, size.x - 6, size.y - 10), Color("#d7b889"))
	draw_rect(Rect2(10, 9, size.x - 20, size.y - 18), yarn_color)
	draw_rect(Rect2(3, 5, 6, size.y - 10), Color("#9b5140"))
	draw_rect(Rect2(size.x - 9, 5, 6, size.y - 10), Color("#9b5140"))
