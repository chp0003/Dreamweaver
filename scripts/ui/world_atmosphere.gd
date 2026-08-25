class_name WorldAtmosphere
extends CanvasLayer
## Painterly twilight behind every House. Replaces the flat grey void.
##
## Lives on a canvas *behind* the world (layer -8) and does not follow the
## camera, so the isometric diamond drifts across a still dream-sky the way
## Child of Light's stages sit on a watercolor backdrop. The grayscale veil
## still covers it (layer 100), which is what we want: a cursed House is a
## drained night, a restored one is a living dusk.

const SKY_BANDS := 36
const MIST_COUNT := 5


func _ready() -> void:
	layer = -8
	follow_viewport_enabled = false

	var sky := _Sky.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var motes := LightMotes.new()
	motes.mote_count = 28
	motes.warm = true
	motes.cool_mix = 0.4
	add_child(motes)


class _Sky extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		_paint_sky(w, h)
		_paint_aurora(w, h)
		_paint_mist(w, h)
		_paint_vignette(w, h)

	func _paint_sky(w: float, h: float) -> void:
		var top := Palette.DREAM_INDIGO
		var mid := Palette.DREAM_COBALT
		var horizon := Palette.DREAM_VIOLET.lerp(Palette.CREAM_STONE, 0.22)
		for i in range(SKY_BANDS):
			var t := float(i) / float(SKY_BANDS - 1)
			var color: Color
			if t < 0.55:
				color = top.lerp(mid, t / 0.55)
			else:
				color = mid.lerp(horizon, (t - 0.55) / 0.45)
			draw_rect(Rect2(0.0, h * t, w, h / float(SKY_BANDS) + 1.5), color)

	func _paint_aurora(w: float, h: float) -> void:
		var y := h * 0.38
		var amp := h * 0.045
		var step := w / 18.0
		for row in range(3):
			var points := PackedVector2Array()
			var yy := y + float(row) * amp * 1.4
			for i in range(19):
				var lift := sin(float(i) * 0.7 + float(row)) * amp
				points.append(Vector2(float(i) * step, yy + lift))
			var ink := Palette.DREAM_AURORA if row == 1 else Palette.GOLD_BRASS
			draw_polyline(points, Palette.alpha(ink, 0.07 + float(row) * 0.02), 3.0, true)

	func _paint_mist(w: float, h: float) -> void:
		for i in range(MIST_COUNT):
			var t := float(i) / float(MIST_COUNT)
			var rect := Rect2(
				-w * 0.05,
				h * (0.55 + t * 0.18),
				w * 1.1,
				h * 0.22
			)
			draw_rect(rect, Palette.alpha(Palette.DREAM_COBALT, 0.07 + t * 0.04))

	func _paint_vignette(w: float, h: float) -> void:
		draw_rect(Rect2(0.0, 0.0, w, h * 0.10), Palette.alpha(Palette.DREAM_INDIGO, 0.28))
		draw_rect(Rect2(0.0, h * 0.86, w, h * 0.14), Palette.alpha(Palette.DREAM_INDIGO, 0.32))
