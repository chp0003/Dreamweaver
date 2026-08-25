extends Node3D

@export var terrain_size := 40.0
@export var tree_count := 14
@export var rock_count := 10
@export var flower_count := 18

var flower_root: Node3D
var water_mesh: MeshInstance3D


func _ready() -> void:
	_build_terrain()
	_build_water()
	flower_root = Node3D.new()
	flower_root.name = "Flowers"
	add_child(flower_root)
	_build_trees()
	_build_rocks()
	_build_flowers()
	_build_particles()


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(terrain_size, terrain_size)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	ground.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.48, 0.22)
	mat.roughness = 0.95
	ground.material_override = mat
	ground.position = Vector3(0.0, 0.0, 0.0)
	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(terrain_size, 0.5, terrain_size)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.25, 0.0)
	body.add_child(collision)
	add_child(body)


func _build_water() -> void:
	water_mesh = MeshInstance3D.new()
	water_mesh.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 8.0)
	water_mesh.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.25, 0.45, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.1
	water_mesh.material_override = mat
	water_mesh.position = Vector3(-8.0, -0.05, 6.0)
	add_child(water_mesh)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in tree_count:
		var tree := _make_tree(rng)
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(6.0, terrain_size * 0.42)
		tree.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)


func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()
	tree.name = "Tree"

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 2.0
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 1.0, 0.0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.12)
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	var foliage := MeshInstance3D.new()
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = rng.randf_range(0.9, 1.4)
	foliage_mesh.height = foliage_mesh.radius * 1.6
	foliage.mesh = foliage_mesh
	foliage.position = Vector3(0.0, 2.4, 0.0)
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.12, 0.42, 0.18)
	foliage.material_override = foliage_mat
	tree.add_child(foliage)

	return tree


func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 84
	for i in rock_count:
		var rock := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var scale := rng.randf_range(0.3, 0.9)
		mesh.size = Vector3(scale, scale * rng.randf_range(0.4, 0.8), scale * rng.randf_range(0.7, 1.2))
		rock.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.45, 0.48).lerp(Color(0.3, 0.3, 0.35), rng.randf())
		rock.material_override = mat
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(4.0, terrain_size * 0.4)
		rock.position = Vector3(cos(angle) * radius, mesh.size.y * 0.5, sin(angle) * radius)
		rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
		add_child(rock)


func _build_flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 126
	var colors := [
		Color(0.95, 0.35, 0.55),
		Color(0.95, 0.85, 0.25),
		Color(0.65, 0.45, 0.95),
		Color(0.95, 0.55, 0.25),
	]
	for i in flower_count:
		var flower := _make_flower(rng, colors[rng.randi() % colors.size()])
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(2.0, 12.0)
		flower.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		flower_root.add_child(flower)


func _make_flower(rng: RandomNumberGenerator, petal_color: Color) -> Node3D:
	var flower := Node3D.new()
	flower.name = "Flower"

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
	bloom_mat.albedo_color = petal_color
	bloom.material_override = bloom_mat
	flower.add_child(bloom)

	return flower


func _build_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "DreamParticles"
	particles.amount = 80
	particles.lifetime = 6.0
	particles.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 20, 50))
	particles.position = Vector3(0.0, 3.0, 0.0)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 4, 18)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 35.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.0, -0.05, 0.0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	mat.color = Color(0.75, 0.85, 1.0, 0.6)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	add_child(particles)
