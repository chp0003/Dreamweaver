extends Node

func _ready() -> void:
	for path in [
		"res://assets/images/characters/slang.png",
		"res://assets/images/characters/slang_8dir/idle_down.png",
		"res://assets/images/characters/slang_8dir/idle_right.png",
		"res://assets/images/characters/slang_8dir/idle_down_right.png",
		"res://assets/images/characters/slang_8dir_src/slang_idle_right.png",
	]:
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) != OK:
			print("FAIL ", path)
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var c0 := img.get_pixel(2, 2)
		var cx := img.get_pixel(int(w * 0.5), int(h * 0.45))
		var bright := 0
		var max_a_bright := 0.0
		for y in range(h):
			for x in range(w):
				var c := img.get_pixel(x, y)
				var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
				if c.a > 0.2 and luma > 0.70 and chroma < 0.10:
					bright += 1
					max_a_bright = maxf(max_a_bright, c.a)
		print("%s %dx%d corner_a=%.2f centre=rgba(%.2f,%.2f,%.2f,%.2f) pale_islands=%d pale_a=%.2f" % [
			path, w, h, c0.a, cx.r, cx.g, cx.b, cx.a, bright, max_a_bright])
	get_tree().quit(0)
