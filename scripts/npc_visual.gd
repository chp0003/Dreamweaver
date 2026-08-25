extends Node3D

var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _left_eye: MeshInstance3D
var _right_eye: MeshInstance3D
var _mouth: MeshInstance3D


func _ready() -> void:
	_build_humanoid()


func set_mood(mood: String) -> void:
	match mood:
		"happy":
			if _body_mat:
				_body_mat.albedo_color = Color(0.55, 0.75, 0.95)
			if _head_mat:
				_head_mat.albedo_color = Color(1.0, 0.88, 0.72)
			if _left_eye and _right_eye:
				_left_eye.scale = Vector3(1.1, 1.1, 1.1)
				_right_eye.scale = Vector3(1.1, 1.1, 1.1)
			if _mouth:
				_mouth.scale = Vector3(1.4, 0.6, 1.0)
				_mouth.position = Vector3(0.0, 1.52, 0.42)
		"sad":
			if _body_mat:
				_body_mat.albedo_color = Color(0.35, 0.38, 0.5)
			if _head_mat:
				_head_mat.albedo_color = Color(0.78, 0.72, 0.68)
			if _left_eye and _right_eye:
				_left_eye.scale = Vector3(1.0, 1.3, 1.0)
				_right_eye.scale = Vector3(1.0, 1.3, 1.0)
			if _mouth:
				_mouth.scale = Vector3(0.9, 0.4, 1.0)
				_mouth.position = Vector3(0.0, 1.42, 0.42)
		_:
			if _body_mat:
				_body_mat.albedo_color = Color(0.45, 0.62, 0.82)
			if _head_mat:
				_head_mat.albedo_color = Color(0.95, 0.82, 0.68)
			if _left_eye and _right_eye:
				_left_eye.scale = Vector3.ONE
				_right_eye.scale = Vector3.ONE
			if _mouth:
				_mouth.scale = Vector3(1.0, 0.5, 1.0)
				_mouth.position = Vector3(0.0, 1.48, 0.42)


func _build_humanoid() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.0
	body.mesh = body_mesh
	body.position = Vector3(0.0, 1.1, 0.0)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.45, 0.62, 0.82)
	body.material_override = _body_mat
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.32
	head_mesh.height = 0.64
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.85, 0.0)
	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = Color(0.95, 0.82, 0.68)
	head.material_override = _head_mat
	add_child(head)

	_left_eye = _make_face_part(Vector3(-0.11, 1.92, 0.26), Vector3(0.06, 0.06, 0.06), Color(0.08, 0.08, 0.12))
	_right_eye = _make_face_part(Vector3(0.11, 1.92, 0.26), Vector3(0.06, 0.06, 0.06), Color(0.08, 0.08, 0.12))
	_mouth = _make_face_part(Vector3(0.0, 1.48, 0.42), Vector3(0.14, 0.05, 0.04), Color(0.55, 0.25, 0.25))

	var left_arm := _make_limb(Vector3(-0.55, 1.25, 0.0), Vector3(0.12, 0.55, 0.12))
	var right_arm := _make_limb(Vector3(0.55, 1.25, 0.0), Vector3(0.12, 0.55, 0.12))
	var left_leg := _make_limb(Vector3(-0.18, 0.45, 0.0), Vector3(0.14, 0.55, 0.14))
	var right_leg := _make_limb(Vector3(0.18, 0.45, 0.0), Vector3(0.14, 0.55, 0.14))
	add_child(left_arm)
	add_child(right_arm)
	add_child(left_leg)
	add_child(right_leg)


func _make_face_part(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	part.material_override = mat
	add_child(part)
	return part


func _make_limb(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	limb.mesh = mesh
	limb.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.62, 0.82)
	limb.material_override = mat
	return limb
