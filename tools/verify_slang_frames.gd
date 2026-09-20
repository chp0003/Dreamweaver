extends SceneTree
## godot --headless --path . -s res://tools/verify_slang_frames.gd

func _init() -> void:
	var frames := SlangFrames.load_or_build()
	var names := frames.get_animation_names()
	names.sort()
	for anim in names:
		print("%s  frames=%d  loop=%s  fps=%.1f" % [
			anim,
			frames.get_frame_count(anim),
			frames.get_animation_loop(anim),
			frames.get_animation_speed(anim),
		])
	quit()
