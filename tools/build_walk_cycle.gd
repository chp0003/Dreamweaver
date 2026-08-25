extends Node
## One-shot: builds a clean 4-frame walk strip for S'lang from the generated
## collage, keys out checkerboard/white mattes, writes:
##   res://assets/images/characters/slang_walk_cycle.png

const SRC := "C:/Users/Admin/.cursor/projects/e-dreamweaver/assets/slang_walk_v2.png"
const DEST := "res://assets/images/characters/slang_walk_cycle.png"
const FRAME_W := 64
const FRAME_H := 96
const FRAMES := 4


func _ready() -> void:
	var img := Image.new()
	if img.load(SRC) != OK:
		push_error("BuildWalkCycle: missing %s" % SRC)
		get_tree().quit(1)
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_key_matte(img)

	var strip := Image.create(FRAME_W * FRAMES, FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	# Scale the keyed collage into the classic strip box.
	var scaled := Image.new()
	scaled.copy_from(img)
	scaled.resize(FRAME_W * FRAMES, FRAME_H, Image.INTERPOLATE_LANCZOS)
	_key_matte(scaled)
	strip.blit_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()), Vector2i.ZERO)

	DirAccess.make_dir_recursive_absolute(DEST.get_base_dir())
	var err := strip.save_png(DEST)
	print("BuildWalkCycle: %s (%s)" % [DEST, "ok" if err == OK else str(err)])
	get_tree().quit(0 if err == OK else 1)


func _key_matte(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var sum := c.r + c.g + c.b
			var grey := absf(c.r - c.g) < 0.08 and absf(c.g - c.b) < 0.08
			if sum > 2.7 or sum < 0.14 or (grey and c.r > 0.42):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
