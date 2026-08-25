extends Node
## Quick check that the imported sprites actually load at runtime.

func _ready() -> void:
	var paths := [
		"res://assets/images/characters/slang.png",
		"res://assets/images/props/guno_bong_1.png",
		"res://assets/images/props/highland_grass.png",
	]
	for path in paths:
		var exists := ResourceLoader.exists(path)
		var tex := load(path)
		var size := Vector2.ZERO
		if tex is Texture2D:
			size = (tex as Texture2D).get_size()
		print("%s  exists=%s  type=%s  size=%s" % [path, exists, typeof(tex), size])
	get_tree().quit(0)
