class_name StoryProgress
extends Control
## Hairline slide tracker for the prologue. Drawn by hand so a parent
## HBox/VBox can never stretch the segments into tall muddy blocks.

const GAP := 6.0
const THICKNESS := 3.0

var count: int = 5
var index: int = 0
var _pulse: float = 1.0
var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, THICKNESS + 2.0)
	resized.connect(queue_redraw)
	_start_pulse()


func set_progress(slide_index: int, slide_count: int) -> void:
	count = maxi(slide_count, 1)
	index = clampi(slide_index, 0, count - 1)
	queue_redraw()
	_start_pulse()


func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse = 0.85
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_method(_set_pulse, 0.85, 1.0, 0.85)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.72, 0.85)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _draw() -> void:
	if count <= 0:
		return
	var total_gap := GAP * float(count - 1)
	var seg_w := maxf((size.x - total_gap) / float(count), 8.0)
	var y := (size.y - THICKNESS) * 0.5
	for i in range(count):
		var x := float(i) * (seg_w + GAP)
		var rect := Rect2(x, y, seg_w, THICKNESS)
		var color: Color
		if i == index:
			color = Palette.GOLD_SUN
			color.a = _pulse
		elif i < index:
			color = Palette.alpha(Palette.GOLD_SACRED, 0.85)
		else:
			color = Palette.alpha(Palette.GOLD_BRASS, 0.38)
		draw_rect(rect, color, true)
