extends SceneTree

func _init() -> void:
	var actor := NpcActor.new()
	print("actor stride=%s accel=%s" % [actor.stride_length, actor.accel])
	actor.free()
	for id in ["chief", "queen", "fun"]:
		var frames := NpcFrames.load_or_build(id)
		for dir in NpcFrames.UNIQUE_DIRS:
			var walk: String = "walk_" + str(dir)
			var n := 0
			var fps := 0.0
			if frames.has_animation(walk):
				n = frames.get_frame_count(walk)
				fps = frames.get_animation_speed(walk)
			print("%s %s frames=%d fps=%.1f" % [id, walk, n, fps])
	quit()
