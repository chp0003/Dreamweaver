class_name AncestralAura
extends Node2D
## Cream-gold dust and a soft lantern for ghosts, statues, and the Ablun loom.

@export var aura_color := Color(0.93, 0.86, 0.62, 0.85)
@export var mote_count := 18
@export var start_energy := 0.0

var _light: PointLight2D
var _dust: GPUParticles2D
var _energy := 0.0


func _ready() -> void:
	z_index = 8
	_light = PointLight2D.new()
	_light.name = "AuraLight"
	_light.texture = _radial_light()
	_light.color = aura_color
	_light.energy = 0.0
	_light.texture_scale = 1.8
	_light.position = Vector2(0.0, -48.0)
	add_child(_light)

	_dust = GPUParticles2D.new()
	_dust.name = "AuraDust"
	_dust.texture = _soft_dot()
	_dust.amount = mote_count
	_dust.lifetime = 2.4
	_dust.preprocess = 0.8
	_dust.explosiveness = 0.0
	_dust.randomness = 0.7
	_dust.position = Vector2(0.0, -56.0)
	_dust.process_material = _dust_material()
	_dust.emitting = false
	add_child(_dust)

	set_energy(start_energy, 0.0)


func set_energy(value: float, duration := 0.55) -> void:
	_energy = clampf(value, 0.0, 2.0)
	if _dust != null:
		_dust.emitting = _energy > 0.08
	if _light == null:
		return
	if duration <= 0.0:
		_light.energy = _energy
		return
	var tween := create_tween()
	tween.tween_property(_light, "energy", _energy, duration).set_ease(Tween.EASE_OUT)


func burst() -> void:
	if not is_inside_tree():
		return
	var flash := GPUParticles2D.new()
	flash.texture = _soft_dot()
	flash.amount = 22
	flash.lifetime = 0.7
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.position = Vector2(0.0, -52.0)
	flash.z_index = 12
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 90.0
	mat.initial_velocity_min = 28.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3(0.0, 30.0, 0.0)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	mat.color = aura_color
	flash.process_material = mat
	add_child(flash)
	flash.emitting = true
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(flash.queue_free)


func _dust_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 70.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = aura_color
	return mat


func _radial_light() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _soft_dot() -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var centre := Vector2(11.5, 11.5)
	for y in range(24):
		for x in range(24):
			var d := Vector2(x, y).distance_to(centre) / 12.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.7)))
	return ImageTexture.create_from_image(image)
