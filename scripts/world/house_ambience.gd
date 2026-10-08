class_name HouseAmbience
extends Node2D
## Living layer over a painted house, in the same spirit as the hub:
## dust in the sun shaft, leaves drifting across the garden porch.
## Sits above the plate and behind S'lang.

const DUST_Z := -40
const LEAF_Z := -36


func _ready() -> void:
	var plate := get_parent()
	if plate == null or not plate.has_method("uv_to_world") or not plate.has_method("displayed_size"):
		return
	_add_dust(plate)
	_add_garden_leaves(plate)


func _add_dust(plate: Node) -> void:
	var size: Vector2 = plate.call("displayed_size")
	var dust := CPUParticles2D.new()
	dust.name = "SunDust"
	dust.z_index = DUST_Z
	dust.z_as_relative = false
	dust.position = plate.call("uv_to_world", Vector2(0.50, 0.48))
	dust.amount = 28
	dust.lifetime = 7.5
	dust.preprocess = 7.5
	dust.texture = HubAmbience._soft_dot(16)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = size * Vector2(0.06, 0.20)
	dust.direction = Vector2(0.35, -0.8)
	dust.spread = 28.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.gravity = Vector2(2.0, 3.0)
	dust.scale_amount_min = 0.35
	dust.scale_amount_max = 0.9
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.92, 0.72, 0.0))
	fade.set_color(1, Color(1.0, 0.92, 0.72, 0.0))
	fade.add_point(0.2, Color(1.0, 0.94, 0.78, 0.42))
	fade.add_point(0.7, Color(1.0, 0.90, 0.70, 0.22))
	dust.color_ramp = fade
	add_child(dust)


func _add_garden_leaves(plate: Node) -> void:
	var size: Vector2 = plate.call("displayed_size")
	var leaves := CPUParticles2D.new()
	leaves.name = "GardenLeaves"
	leaves.z_index = LEAF_Z
	leaves.z_as_relative = false
	leaves.position = plate.call("uv_to_world", Vector2(0.50, 0.82))
	leaves.amount = 16
	leaves.lifetime = 8.0
	leaves.preprocess = 8.0
	leaves.texture = HubAmbience._leaf_texture()
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = size * Vector2(0.42, 0.12)
	leaves.direction = Vector2(1.0, 0.25)
	leaves.spread = 26.0
	leaves.initial_velocity_min = 8.0
	leaves.initial_velocity_max = 20.0
	leaves.gravity = Vector2(4.0, 8.0)
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -80.0
	leaves.angular_velocity_max = 80.0
	leaves.scale_amount_min = 0.65
	leaves.scale_amount_max = 1.15
	var tint := Gradient.new()
	tint.set_color(0, Color(0.42, 0.58, 0.24))
	tint.set_color(1, Color(0.78, 0.62, 0.22))
	tint.add_point(0.5, Color(0.62, 0.58, 0.20))
	leaves.color_initial_ramp = tint
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.85))
	fade.add_point(0.8, Color(1, 1, 1, 0.7))
	leaves.color_ramp = fade
	add_child(leaves)
