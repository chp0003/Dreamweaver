extends Node
## Keys the black plate on the dungeon gate sprites and crops them.

const PATHS := [
	"res://assets/images/props/guno_door_closed.png",
	"res://assets/images/props/guno_door_open.png",
]


func _ready() -> void:
	var failed := false
	for path in PATHS:
		if not _key(path):
			failed = true
	get_tree().quit(1 if failed else 0)


func _key(path: String) -> bool:
	var image := Image.new()
	if image.load(path) != OK:
		push_error("load failed: " + path)
		return false
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var plate := image.get_pixel(0, 0)
	_flood(image, plate, 0.10)
	image = _crop(image)
	var err := image.save_png(ProjectSettings.globalize_path(path))
	print("%s saved err=%d size=%dx%d corner_a=%.2f" % [
		path, err, image.get_width(), image.get_height(), image.get_pixel(0, 0).a
	])
	return err == OK and image.get_pixel(0, 0).a < 0.08


func _flood(image: Image, plate: Color, tol: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var stack: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if seen[idx] == 1:
			continue
		seen[idx] = 1
		var c := image.get_pixel(p.x, p.y)
		if c.a < 0.05:
			stack.append_array([
				Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y),
				Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1),
			])
			continue
		var dr := absf(c.r - plate.r)
		var dg := absf(c.g - plate.g)
		var db := absf(c.b - plate.b)
		if dr > tol or dg > tol or db > tol:
			continue
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)
		stack.append_array([
			Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y),
			Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1),
		])


func _crop(image: Image) -> Image:
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
	min_x = maxi(0, min_x - 4)
	min_y = maxi(0, min_y - 4)
	max_x = mini(w - 1, max_x + 4)
	max_y = mini(h - 1, max_y + 4)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
