class_name StoryProgress
extends Control
## Slide tracker for the prologue. Drawn by hand so a parent container
## can never stretch child ColorRects into tall muddy blocks.

const GAP := 8.0
const THICKNESS := 6.0
const TRACK_PAD_Y := 4.0
const TRACK_PAD_X := 4.0
const RADIUS := 3.0

var count: int = 5
var index: int = 0
var _pulse: float = 1.0
var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, THICKNESS + TRACK_PAD_Y * 2.0)
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
	_pulse = 1.0
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.7, 0.9)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_pulse, 0.7, 1.0, 0.9)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _draw() -> void:
	if count <= 0 or size.x < 8.0:
		return

	# Dark rail behind the ticks so they stay readable on black portraits
	# and bright village slides alike.
	var rail := Rect2(
		0.0,
		0.0,
		size.x,
		size.y
	)
	draw_rect(rail, Palette.alpha(Palette.DREAM_ABYSS, 0.72), true)

	var inner_w := maxf(size.x - TRACK_PAD_X * 2.0, 8.0)
	var total_gap := GAP * float(count - 1)
	var seg_w := maxf((inner_w - total_gap) / float(count), 12.0)
	var y := (size.y - THICKNESS) * 0.5

	for i in range(count):
		var x := TRACK_PAD_X + float(i) * (seg_w + GAP)
		var rect := Rect2(x, y, seg_w, THICKNESS)
		var color: Color
		if i == index:
			color = Palette.GOLD_SUN
			color.a = _pulse
		elif i < index:
			color = Palette.GOLD_SACRED
		else:
			color = Palette.alpha(Palette.GOLD_BRASS, 0.55)
		_draw_round_rect(rect, color)


func _draw_round_rect(rect: Rect2, color: Color) -> void:
	# Godot 4 has no draw_rect rounded helper — approximate with a filled
	# rect plus end caps so the ticks read as soft capsules.
	var r := minf(RADIUS, rect.size.y * 0.5)
	var body := Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y)
	if body.size.x > 0.0:
		draw_rect(body, color, true)
	draw_circle(Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5), r, color)
	draw_circle(Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5), r, color)
