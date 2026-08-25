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


static func punch(node: Node2D, amount := 0.12) -> void:
	if node == null or not node.is_inside_tree():
		return
	var home := node.scale
	var tween := node.create_tween()
	tween.tween_property(node, "scale", home * Vector2(1.0 + amount, 1.0 - amount), 0.05)
	tween.tween_property(node, "scale", home, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


static func _soft_dot() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var centre := Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var d := Vector2(x, y).distance_to(centre) / 16.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.8)))
	return ImageTexture.create_from_image(image)
