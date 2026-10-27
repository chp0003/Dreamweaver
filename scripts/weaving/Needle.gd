class_name Needle
extends Node2D

signal drag_started
signal drag_moved(x: float)
signal drag_released

const GRAB_RADIUS := 14.0
var is_dragging := false
var _pulse := 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func set_dragging(value: bool) -> void:
	is_dragging = value
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_try_start(get_global_mouse_position())
		elif is_dragging:
			is_dragging = false
			drag_released.emit()
	elif event is InputEventMouseMotion and is_dragging:
		var point: Vector2 = get_parent().to_local(get_global_mouse_position())
		position.x = clampf(point.x, 88.0, 232.0)
		drag_moved.emit(position.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_try_start(touch.position)
		elif is_dragging:
			is_dragging = false
			drag_released.emit()
	elif event is InputEventScreenDrag and is_dragging:
		var drag := event as InputEventScreenDrag
		var local_point: Vector2 = get_parent().to_local(drag.position)
		position.x = clampf(local_point.x, 88.0, 232.0)
		drag_moved.emit(position.x)

func _try_start(point: Vector2) -> void:
	if point.distance_to(global_position) > GRAB_RADIUS:
		return
	is_dragging = true
	drag_started.emit()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var pulse := 0.4 + (sin(_pulse * TAU) + 1.0) * 0.3
	var glow := Color(0.96, 0.91, 0.78, pulse)
	draw_rect(Rect2(-11, -6, 22, 12), glow, false, 1.0)
	draw_rect(Rect2(-7, -3, 14, 6), Color("#E8D5A8"))
	draw_rect(Rect2(-5, -2, 10, 4), Color("#8B2E1A"))
	draw_rect(Rect2(7, 0, 6, 1), Color("#F5E8C7"))
