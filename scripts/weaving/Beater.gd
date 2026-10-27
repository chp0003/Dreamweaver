class_name Beater
extends Control

signal beaten

var _hover := false
var _pressed := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 38)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_pressed = true
			beaten.emit()
			queue_redraw()
			accept_event()
		elif not click.pressed:
			_pressed = false
			queue_redraw()
	elif event is InputEventMouseMotion:
		_hover = true
		queue_redraw()

func _draw() -> void:
	var color := Color("#9b5140") if _hover else Color("#713326")
	var y := 16.0 if _pressed else 5.0
	draw_rect(Rect2(4, y, maxf(size.x - 8, 24), 18), Color("#110e10"))
	draw_rect(Rect2(6, y + 2, maxf(size.x - 12, 20), 14), color)
	draw_rect(Rect2(6, y + 2, maxf(size.x - 12, 20), 2), Color("#f0d7a7"))
