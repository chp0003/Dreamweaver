extends Control
## Small rotating arc — the loading spindle on boot and transition screens.

const LINE_WIDTH := 3.0


func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	var start := fmod(float(Time.get_ticks_msec()) * 0.004, TAU)
	draw_arc(center, radius, start, start + TAU * 0.62, 40,
		Palette.GOLD_SACRED, LINE_WIDTH, true)
