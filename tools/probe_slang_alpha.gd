extends Node

func _ready() -> void:
	for path in [
		"res://assets/images/characters/slang.png",
		"res://assets/images/characters/slang_8dir/idle_down.png",
		"res://assets/images/characters/slang_8dir/idle_down_right.png",
		"res://assets/images/characters/slang_8dir_src/slang_idle_down.png",
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
		print("%s %dx%d corner=rgba(%.2f,%.2f,%.2f,%.2f) centre=rgba(%.2f,%.2f,%.2f,%.2f)" % [
			path, w, h, c0.r, c0.g, c0.b, c0.a, cx.r, cx.g, cx.b, cx.a])
	get_tree().quit(0)
