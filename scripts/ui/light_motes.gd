class_name LightMotes
extends GPUParticles2D
## Slow fireflies. The cheapest way to make a still screen feel like a dream.
##
## Child of Light's menus never sit dead: dust, fireflies and brush-stroke motes
## drift across every pause. These are the same idea, drawn as a handful of
## warm (and a few cool) dots so they read as lantern light, not snow.

@export var mote_count := 42
@export var warm := true
@export var cool_mix := 0.28


func _ready() -> void:
	z_index = 8
	amount = mote_count
	lifetime = 9.0
	preprocess = 6.0
	explosiveness = 0.0
	randomness = 0.7
	visibility_rect = Rect2(-2000, -2000, 4000, 4000)
	texture = _dot_texture()
	process_material = _build_material()
	emitting = true
	_fit_to_parent()
	var host := get_parent()
	if host is Control:
		(host as Control).resized.connect(_fit_to_parent)
	elif get_viewport() != null:
		get_viewport().size_changed.connect(_fit_to_parent)


func _fit_to_parent() -> void:
	var area := Vector2(1280.0, 720.0)
	var host := get_parent()
	if host is Control:
		area = (host as Control).size
		if area.x < 8.0 or area.y < 8.0:
			area = get_viewport().get_visible_rect().size
	elif get_viewport() != null:
		area = get_viewport().get_visible_rect().size
	position = area * 0.5
	var mat := process_material as ParticleProcessMaterial
	if mat != null:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(area.x * 0.55, area.y * 0.55, 1.0)


func _build_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(720.0, 420.0, 1.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0.0, -6.0, 0.0)
	mat.damping_min = 0.4
	mat.damping_max = 1.6
	mat.scale_min = 0.35
	mat.scale_max = 1.35
	mat.color = Palette.DREAM_LANTERN if warm else Palette.DREAM_AURORA

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
	var a := Palette.alpha(Palette.DREAM_LANTERN, 0.0)
	var b := Palette.alpha(Palette.DREAM_LANTERN, 0.85)
	var c := Palette.alpha(Palette.GOLD_SUN, 0.55)
	var d := Palette.alpha(Palette.DREAM_AURORA if cool_mix > 0.0 else Palette.DREAM_LANTERN, 0.0)
	grad.colors = PackedColorArray([a, b, c, d])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	return mat


func _dot_texture() -> Texture2D:
	var size := 14
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(centre) / (size * 0.5)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.6)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)
