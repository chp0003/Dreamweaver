extends Node
## Keys the navy studio matte off the weave-bolt burst and recolors it gold.

const SRC := "res://assets/images/vfx/weave_bolt_burst.png"
const DEST := "res://assets/images/vfx/weave_bolt_burst.png"


func _ready() -> void:
	var image := Image.new()
	var err := image.load(SRC)
	if err != OK:
		push_error("Missing burst art")
		get_tree().quit(1)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var cleared := _key_navy(image)
	image = _crop_to_alpha(image)
	err = image.save_png(ProjectSettings.globalize_path(DEST))
	print("Weave bolt burst keyed: %dx%d cleared=%d corner_a=%.2f" % [
		image.get_width(), image.get_height(), cleared, image.get_pixel(0, 0).a])
	get_tree().quit(0 if image.get_pixel(0, 0).a < 0.05 else 1)


func _key_navy(image: Image) -> int:
	var cleared := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if _is_navy_matte(c):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				cleared += 1
				continue
			# Recolor blue energy into sacred gold while keeping luminance.
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var gold := Color(
				clampf(luma * 1.15 + 0.12, 0.0, 1.0),
				clampf(luma * 0.95 + 0.05, 0.0, 1.0),
				clampf(luma * 0.35, 0.0, 1.0),
				c.a
			)
			# Keep near-white core hot.
			if luma > 0.85:
				gold = Color(1.0, 0.97, 0.78, c.a)
			image.set_pixel(x, y, gold)
	return cleared


func _is_navy_matte(c: Color) -> bool:
	if c.a < 0.08:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	# Dark navy studio ground.
	if luma < 0.18 and c.b >= c.r and c.b >= c.g * 0.9:
		return true
	if luma < 0.12:
		return true
	return false


func _crop_to_alpha(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return image
	min_x = maxi(0, min_x - 2)
	min_y = maxi(0, min_y - 2)
	max_x = mini(w - 1, max_x + 2)
	max_y = mini(h - 1, max_y + 2)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
