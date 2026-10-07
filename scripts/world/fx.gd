class_name Fx
extends RefCounted
## Small combat and world VFX. Kept tiny on purpose: magical, not a fireworks show.


static func hit_flash(host: Node2D, color := Palette.GOLD_SUN) -> void:
	if host == null or not host.is_inside_tree():
		return
	var flash := Sprite2D.new()
	flash.texture = _soft_dot()
	flash.modulate = Palette.alpha(color, 0.85)
	flash.scale = Vector2(0.35, 0.22)
	flash.z_index = 20
	flash.position = Vector2(0.0, -36.0)
	host.add_child(flash)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.1, 0.7), 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(flash.queue_free)


static func staff_trail(host: Node2D, facing: Vector2, reach: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var arc := Line2D.new()
	arc.width = 6.0
	arc.default_color = Palette.alpha(Palette.GOLD_SUN, 0.88)
	arc.z_index = 12
	var base := facing.angle()
	# Wide horizontal cut, not a poke.
	for i in range(10):
		var a := base + lerpf(-1.15, 1.15, float(i) / 9.0)
		arc.add_point(Vector2(cos(a), sin(a) * 0.48) * reach + Vector2(0.0, -28.0))
	host.add_child(arc)
	var tween := host.create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, 0.42)
	tween.tween_callback(arc.queue_free)


static func damage_number(host: Node, world_pos: Vector2, amount: int,
		color := Palette.RED_EMBER) -> void:
	if host == null or not host.is_inside_tree():
		return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.DREAM_ABYSS)
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 50
	label.position = world_pos + Vector2(-10.0, -72.0)
	host.add_child(label)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.55)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)


static func fiber_burst(host: Node2D, color := Palette.CREAM_PAPER) -> void:
	if host == null or not host.is_inside_tree():
		return
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 80.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 110.0
	mat.gravity = Vector3(0.0, 80.0, 0.0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	mat.color = color
	particles.process_material = mat
	particles.amount = 14
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = Vector2(0.0, -28.0)
	particles.z_index = 16
	host.add_child(particles)
	particles.emitting = true
	var tween := host.create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(particles.queue_free)


static func ring_pulse(host: Node2D, color := Palette.GOLD_SUN, radius := 150.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Palette.alpha(color, 0.9)
	ring.closed = true
	ring.z_index = 30
	var pts := PackedVector2Array()
	for i in range(28):
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a) * 0.55) * 16.0)
	ring.points = pts
	host.add_child(ring)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(radius / 16.0, radius / 16.0), 0.38)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.38)
	tween.chain().tween_callback(ring.queue_free)


## The chapter 5 colour burst, sized for a house coming back to life.
static func restoration_sparkle(host: Node2D) -> void:
	if host == null or not host.is_inside_tree():
		return
	var burst := GPUParticles2D.new()
	burst.name = "HouseSparkle"
	burst.texture = _soft_dot()
	burst.process_material = _restoration_material()
	burst.amount = 220
	burst.lifetime = 2.6
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.z_index = 60
	burst.position = Vector2(0.0, -40.0)
	host.add_child(burst)
	burst.emitting = true
	var glitter := house_glitter()
	glitter.amount = 36
	glitter.position = Vector2(0.0, -20.0)
	host.add_child(glitter)
	var tween := host.create_tween()
	tween.tween_interval(3.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
		if is_instance_valid(glitter):
			glitter.queue_free())


## Slow gold motes for a house that is already restored.
static func house_glitter() -> GPUParticles2D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(78.0, 18.0, 1.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 28.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 32.0
	mat.gravity = Vector3(0.0, -16.0, 0.0)
	mat.scale_min = 0.28
	mat.scale_max = 0.7
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1.0, 0.93, 0.62, 0.0))
	ramp.add_point(0.2, Color(1.0, 0.9, 0.55, 0.95))
	ramp.add_point(0.55, Color(0.86, 0.28, 0.22, 0.8))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(1.0, 0.86, 0.4, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	mat.color_ramp = ramp_texture
	var motes := GPUParticles2D.new()
	motes.name = "HouseGlitter"
	motes.texture = _soft_dot()
	motes.process_material = mat
	motes.amount = 18
	motes.lifetime = 1.7
	motes.preprocess = 0.6
	motes.z_index = 12
	motes.emitting = true
	return motes


static func _restoration_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 36.0
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 180.0
	material.initial_velocity_max = 560.0
	material.gravity = Vector3(0.0, 70.0, 0.0)
	material.scale_min = 1.6
	material.scale_max = 5.2
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1.0, 0.92, 0.6, 1.0))
	ramp.add_point(0.45, Color(0.85, 0.2, 0.16, 1.0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(0.15, 0.13, 0.13, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	return material


static func light_burst(host: Node2D, color := Palette.GOLD_SUN) -> void:
	if host == null or not host.is_inside_tree():
		return
	var flash := Sprite2D.new()
	flash.texture = _soft_dot()
	flash.modulate = Palette.alpha(color, 0.95)
	flash.scale = Vector2(0.2, 0.2)
	flash.z_index = 24
	flash.position = Vector2(0.0, -48.0)
	host.add_child(flash)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.4, 1.6), 0.22)
	tween.tween_property(flash, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(flash.queue_free)


static func pool_rise(host: Node2D) -> void:
	if host == null or not host.is_inside_tree():
		return
	fiber_burst(host, Color(0.18, 0.12, 0.22))
	var ring := Sprite2D.new()
	ring.texture = _soft_dot()
	ring.modulate = Color(0.18, 0.1, 0.22, 0.7)
	ring.scale = Vector2(0.15, 0.08)
	ring.z_index = 6
	host.add_child(ring)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.4, 0.55), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)


## Overlapping punches must return to the true rest scale, not to the squashed
## scale of the punch still in flight, or the body drifts out of shape.
static func punch(node: Node2D, amount := 0.12) -> void:
	if node == null or not node.is_inside_tree():
		return
	var home := node.scale
	var running: Variant = node.get_meta(&"punch_tween", null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
		home = node.get_meta(&"punch_home", home)
	node.set_meta(&"punch_home", home)
	var tween := node.create_tween()
	node.set_meta(&"punch_tween", tween)
	tween.tween_property(node, "scale", home * Vector2(1.0 + amount, 1.0 - amount), 0.05)
	tween.tween_property(node, "scale", home, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.remove_meta(&"punch_tween"))


static func _soft_dot() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var centre := Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var d := Vector2(x, y).distance_to(centre) / 16.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.8)))
	return ImageTexture.create_from_image(image)
