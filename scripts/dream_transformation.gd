extends Node

signal transformation_complete(is_positive: bool)

@export var transition_duration := 2.0

var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _ambient_particles: GPUParticles3D
var _flower_root: Node3D
var _npc_root: Node3D
var _water_mesh: MeshInstance3D
var _tween: Tween


func setup(
	world_environment: WorldEnvironment,
	directional_light: DirectionalLight3D,
	ambient_particles: GPUParticles3D,
	flower_root: Node3D,
	npc_root: Node3D,
	water_mesh: MeshInstance3D
) -> void:
	_world_environment = world_environment
	_directional_light = directional_light
	_ambient_particles = ambient_particles
	_flower_root = flower_root
	_npc_root = npc_root
	_water_mesh = water_mesh


func apply_choice(choice_id: String) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	var is_positive := choice_id == "comfort"
	if is_positive:
		_apply_positive(_tween)
	else:
		_apply_negative(_tween)

	_tween.chain().tween_callback(func() -> void:
		transformation_complete.emit(is_positive)
	)


func _apply_positive(tween: Tween) -> void:
	var env := _world_environment.environment
	tween.tween_method(
		func(value: float) -> void:
			env.fog_density = lerpf(0.035, 0.008, value)
			env.fog_light_color = Color(0.75, 0.88, 1.0).lerp(Color(0.9, 0.95, 1.0), value)
			env.ambient_light_color = Color(0.35, 0.4, 0.55).lerp(Color(0.55, 0.65, 0.85), value)
			env.ambient_light_energy = lerpf(0.45, 0.85, value)
			env.background_color = Color(0.12, 0.16, 0.28).lerp(Color(0.45, 0.65, 0.95), value),
		0.0, 1.0, transition_duration
	)

	tween.tween_property(_directional_light, "light_energy", 2.2, transition_duration)
	tween.tween_property(_directional_light, "light_color", Color(1.0, 0.98, 0.9), transition_duration)
	tween.tween_property(_ambient_particles, "amount_ratio", 1.0, transition_duration)

	if _flower_root:
		for child in _flower_root.get_children():
			child.visible = true
			tween.tween_property(child, "scale", Vector3.ONE * 1.3, transition_duration)
		_spawn_bonus_flowers(tween)

	if _npc_root and _npc_root.has_method("set_mood"):
		_npc_root.set_mood("happy")

	if _water_mesh and _water_mesh.material_override is StandardMaterial3D:
		var water_mat: StandardMaterial3D = _water_mesh.material_override
		tween.tween_method(
			func(value: float) -> void:
				water_mat.albedo_color = Color(0.08, 0.25, 0.45, 0.75).lerp(Color(0.15, 0.55, 0.85, 0.8), value),
			0.0, 1.0, transition_duration
		)


func _apply_negative(tween: Tween) -> void:
	var env := _world_environment.environment
	tween.tween_method(
		func(value: float) -> void:
			env.fog_density = lerpf(0.035, 0.09, value)
			env.fog_light_color = Color(0.75, 0.88, 1.0).lerp(Color(0.15, 0.12, 0.2), value)
			env.ambient_light_color = Color(0.35, 0.4, 0.55).lerp(Color(0.08, 0.06, 0.12), value)
			env.ambient_light_energy = lerpf(0.45, 0.15, value)
			env.background_color = Color(0.12, 0.16, 0.28).lerp(Color(0.03, 0.02, 0.06), value),
		0.0, 1.0, transition_duration
	)

	tween.tween_property(_directional_light, "light_energy", 0.35, transition_duration)
	tween.tween_property(_directional_light, "light_color", Color(0.45, 0.35, 0.55), transition_duration)
	tween.tween_property(_ambient_particles, "amount_ratio", 0.15, transition_duration)

	if _flower_root:
		for child in _flower_root.get_children():
			tween.tween_property(child, "scale", Vector3.ZERO, transition_duration * 0.6)
			tween.tween_callback(func() -> void: child.visible = false).set_delay(transition_duration * 0.6)

	if _npc_root and _npc_root.has_method("set_mood"):
		_npc_root.set_mood("sad")

	if _water_mesh and _water_mesh.material_override is StandardMaterial3D:
		var water_mat: StandardMaterial3D = _water_mesh.material_override
		tween.tween_method(
			func(value: float) -> void:
				water_mat.albedo_color = Color(0.08, 0.25, 0.45, 0.75).lerp(Color(0.02, 0.05, 0.12, 0.9), value),
			0.0, 1.0, transition_duration
		)


func _spawn_bonus_flowers(tween: Tween) -> void:
	if _flower_root == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var colors := [
		Color(0.95, 0.35, 0.55),
		Color(0.95, 0.85, 0.25),
		Color(0.65, 0.45, 0.95),
	]
	for i in 8:
		var flower := _make_bonus_flower(colors[i % colors.size()])
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(2.0, 10.0)
		flower.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		flower.scale = Vector3.ZERO
		_flower_root.add_child(flower)
		tween.tween_property(flower, "scale", Vector3.ONE, transition_duration).set_delay(rng.randf() * 0.5)


func _make_bonus_flower(color: Color) -> Node3D:
	var flower := Node3D.new()
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.04
	stem_mesh.height = 0.45
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, 0.22, 0.0)
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.15, 0.45, 0.15)
	stem.material_override = stem_mat
	flower.add_child(stem)
	var bloom := MeshInstance3D.new()
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = 0.12
	bloom.mesh = bloom_mesh
	bloom.position = Vector3(0.0, 0.48, 0.0)
	var bloom_mat := StandardMaterial3D.new()
	bloom_mat.albedo_color = color
	bloom.material_override = bloom_mat
	flower.add_child(bloom)
	return flower
