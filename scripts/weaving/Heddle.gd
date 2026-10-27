class_name Heddle
extends Control

signal toggled(is_up: bool)

var is_up := false
var _hover := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 34)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			is_up = not is_up
			toggled.emit(is_up)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		_hover = true
		queue_redraw()

func _draw() -> void:
	var bar := Rect2(4, 5, maxf(size.x - 8, 24), 22)
	var wood := Color("#713326") if not _hover else Color("#9b5140")
	draw_rect(bar, Color("#110e10"))
	draw_rect(bar.grow(-2), wood)
	draw_rect(Rect2(bar.position + Vector2(0, 2), Vector2(bar.size.x, 2)), Color("#f0d7a7"))
	for x in range(0, int(bar.size.x), 14):
		draw_rect(Rect2(bar.position.x + x + 3, bar.position.y - 5 if is_up else bar.position.y + 16, 5, 14), Color("#d7b889"))
