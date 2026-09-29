class_name HubAmbience
extends Node2D

## Living layer over the hub painting: birds that cross the sky or drop in to
## perch on roofs, trees, and the plaza, drifting leaves, and spray rising off
## the two falls. Lives under HubPlate, so it shares its origin and hides with the ridge.

const FALL_BASES_UV: Array[Vector2] = [Vector2(0.12, 0.295), Vector2(0.20, 0.295)]
const FALL_WIDTH_UV := 0.032
## Painted landing spots on hub_background.png. Ground perches get pecking and hopping.
const PERCHES: Array[Dictionary] = [
	{"uv": Vector2(0.504, 0.040), "ground": false},
	{"uv": Vector2(0.440, 0.130), "ground": false},
	{"uv": Vector2(0.570, 0.130), "ground": false},
	{"uv": Vector2(0.206, 0.268), "ground": false},
	{"uv": Vector2(0.786, 0.268), "ground": false},
	{"uv": Vector2(0.198, 0.556), "ground": false},
	{"uv": Vector2(0.771, 0.556), "ground": false},
	{"uv": Vector2(0.496, 0.345), "ground": false},
	{"uv": Vector2(0.260, 0.870), "ground": false},
	{"uv": Vector2(0.700, 0.870), "ground": false},
	{"uv": Vector2(0.900, 0.820), "ground": false},
	{"uv": Vector2(0.336, 0.090), "ground": false},
	{"uv": Vector2(0.672, 0.070), "ground": false},
	{"uv": Vector2(0.900, 0.140), "ground": false},
	{"uv": Vector2(0.030, 0.400), "ground": false},
	{"uv": Vector2(0.975, 0.600), "ground": false},
	{"uv": Vector2(0.400, 0.570), "ground": true},
	{"uv": Vector2(0.610, 0.610), "ground": true},
	{"uv": Vector2(0.500, 0.690), "ground": true},
	{"uv": Vector2(0.350, 0.480), "ground": true},
	{"uv": Vector2(0.640, 0.470), "ground": true},
	{"uv": Vector2(0.500, 0.820), "ground": true},
]
const BIRD_INK := Color(0.07, 0.07, 0.09, 0.88)
const BIRD_PLUMAGE: Array[Color] = [
	Color(0.36, 0.25, 0.17), Color(0.22, 0.20, 0.22), Color(0.44, 0.32, 0.20),
]
const SKY_Z := 40
const SPRAY_Z := -110

var _plate: HubPlate
var _sky: _Sky


func _ready() -> void:
	_plate = get_parent() as HubPlate
	if _plate == null:
		return
	for base_uv in FALL_BASES_UV:
		_add_fall_spray(base_uv)
	_add_leaves()
	_sky = _Sky.new()
	_sky.name = "Sky"
	_sky.z_index = SKY_Z
	_sky.z_as_relative = false
	_sky.bounds = _plate.world_rect()
	for perch in PERCHES:
		_sky.perches.append({
			"pos": _plate.uv_to_world(perch["uv"] as Vector2),
			"ground": perch["ground"],
			"taken": false,
		})
	add_child(_sky)


func _add_fall_spray(base_uv: Vector2) -> void:
	var width := FALL_WIDTH_UV * _plate.displayed_size().x
	var spray := CPUParticles2D.new()
	spray.name = "FallSpray"
	spray.z_index = SPRAY_Z
	spray.z_as_relative = false
	spray.position = _plate.uv_to_world(base_uv)
	spray.amount = 46
	spray.lifetime = 2.4
	spray.preprocess = 2.4
	spray.texture = _soft_dot(24)
	spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spray.emission_rect_extents = Vector2(width * 0.5, 6.0)
	spray.direction = Vector2(0.0, -1.0)
	spray.spread = 38.0
	spray.initial_velocity_min = 8.0
	spray.initial_velocity_max = 26.0
	spray.gravity = Vector2(4.0, -6.0)
	spray.damping_min = 4.0
	spray.damping_max = 8.0
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	spray.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.97, 1.0, 0.0))
	fade.set_color(1, Color(0.92, 0.97, 1.0, 0.0))
	fade.add_point(0.18, Color(0.92, 0.97, 1.0, 0.34))
	fade.add_point(0.6, Color(0.88, 0.94, 1.0, 0.16))
	spray.color_ramp = fade
	add_child(spray)


func _add_leaves() -> void:
	var rect := _plate.world_rect()
	var leaves := CPUParticles2D.new()
	leaves.name = "DriftingLeaves"
	leaves.z_index = SKY_Z - 1
	leaves.z_as_relative = false
	leaves.position = rect.get_center() - Vector2(rect.size.x * 0.08, rect.size.y * 0.1)
	leaves.amount = 34
	leaves.lifetime = 9.0
	leaves.preprocess = 9.0
	leaves.texture = _leaf_texture()
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = rect.size * Vector2(0.5, 0.42)
	leaves.direction = Vector2(1.0, 0.4)
	leaves.spread = 30.0
	leaves.initial_velocity_min = 10.0
	leaves.initial_velocity_max = 26.0
	leaves.gravity = Vector2(5.0, 9.0)
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -90.0
	leaves.angular_velocity_max = 90.0
	leaves.tangential_accel_min = -6.0
	leaves.tangential_accel_max = 6.0
	leaves.scale_amount_min = 0.7
	leaves.scale_amount_max = 1.3
	var tint := Gradient.new()
	tint.set_color(0, Color(0.56, 0.66, 0.28))
	tint.set_color(1, Color(0.86, 0.62, 0.26))
	tint.add_point(0.5, Color(0.72, 0.70, 0.30))
	leaves.color_initial_ramp = tint
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.12, Color(1, 1, 1, 0.9))
	fade.add_point(0.85, Color(1, 1, 1, 0.8))
	leaves.color_ramp = fade
	add_child(leaves)


static func _soft_dot(size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := (Vector2(x + 0.5, y + 0.5) - centre).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(image)


static func _leaf_texture() -> Texture2D:
	var w := 10
	var h := 5
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var nx := (x + 0.5) / w * 2.0 - 1.0
			var ny := (y + 0.5) / h * 2.0 - 1.0
			var edge := nx * nx + ny * ny * (1.0 + nx * 0.6)
			var a := clampf((1.0 - edge) * 3.0, 0.0, 1.0)
			var vein := 0.82 if absf(ny) < 0.22 and nx > -0.8 else 1.0
			image.set_pixel(x, y, Color(vein, vein, vein, a))
	return ImageTexture.create_from_image(image)


## Birds are "pass" (flock crossing), "arrive" (gliding in to a perch),
## "perch" (hopping, pecking, looking around), or "leave" (flushed or bored).
class _Sky extends Node2D:
	const MAX_PERCHED := 7
	const FLUSH_RADIUS := 110.0
	const CRUISE_SPEED := 95.0

	var bounds := Rect2()
	var perches: Array[Dictionary] = []
	var _birds: Array[Dictionary] = []
	var _flock_timer := 4.0
	var _arrival_timer := 1.0

	func _ready() -> void:
		for i in range(3):
			var perch := _free_perch()
			if perch.is_empty():
				break
			var bird := _new_bird("perch", perch["pos"] as Vector2)
			_settle(bird, perch)
			_birds.append(bird)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_flock_timer -= delta
		if _flock_timer <= 0.0:
			_flock_timer = randf_range(9.0, 18.0)
			_spawn_flock()
		_arrival_timer -= delta
		if _arrival_timer <= 0.0:
			_arrival_timer = randf_range(2.5, 7.0)
			_spawn_arrivals()
		var threat: Variant = _player_local()
		for i in range(_birds.size() - 1, -1, -1):
			var bird: Dictionary = _birds[i]
			match str(bird["state"]):
				"arrive":
					_step_arrive(bird, delta)
				"perch":
					_step_perch(bird, delta, threat)
				_:
					_step_flight(bird, delta)
			if bird["state"] != "perch" and bird["state"] != "arrive" \
					and not bounds.grow(160.0).has_point(bird["pos"] as Vector2):
				_birds.remove_at(i)
		queue_redraw()

	func _new_bird(state: String, pos: Vector2) -> Dictionary:
		return {
			"state": state,
			"pos": pos,
			"vel": Vector2.ZERO,
			"phase": randf() * TAU,
			"flap": randf_range(9.0, 12.0),
			"size": randf_range(6.5, 9.0),
			"bob": 0.0,
			"height": 1.0,
			"facing": 1.0 if randf() < 0.5 else -1.0,
			"color": BIRD_PLUMAGE[randi() % BIRD_PLUMAGE.size()],
			"perch": {},
			"timer": 0.0,
			"hop": 0.0,
			"hop_from": Vector2.ZERO,
			"hop_to": Vector2.ZERO,
			"peck": 0.0,
			"idle": 0.0,
		}

	func _player_local() -> Variant:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null or not player.is_visible_in_tree():
			return null
		return to_local(player.global_position)

	func _free_perch() -> Dictionary:
		var open: Array[Dictionary] = []
		for perch in perches:
			if not perch["taken"]:
				open.append(perch)
		if open.is_empty():
			return {}
		return open[randi() % open.size()]

	func _perched_count() -> int:
		var count := 0
		for bird in _birds:
			if bird["state"] == "perch" or bird["state"] == "arrive":
				count += 1
		return count

	func _spawn_arrivals() -> void:
		var count := 2 if randf() < 0.3 else 1
		for i in range(count):
			if _perched_count() >= MAX_PERCHED:
				return
			var perch := _free_perch()
			if perch.is_empty():
				return
			perch["taken"] = true
			var target: Vector2 = perch["pos"]
			var from_left := randf() < 0.5
			var start := Vector2(
				bounds.position.x - 80.0 if from_left else bounds.end.x + 80.0,
				clampf(target.y - randf_range(160.0, 320.0), bounds.position.y - 60.0, bounds.end.y))
			var bird := _new_bird("arrive", start)
			bird["perch"] = perch
			_birds.append(bird)

	func _spawn_flock() -> void:
		var from_left := randf() < 0.5
		var dir := Vector2(1.0 if from_left else -1.0, randf_range(-0.28, 0.22)).normalized()
		var start_x := bounds.position.x - 100.0 if from_left else bounds.end.x + 100.0
		var start := Vector2(start_x, randf_range(bounds.position.y + bounds.size.y * 0.08,
			bounds.position.y + bounds.size.y * 0.7))
		var speed := randf_range(70.0, 110.0)
		var side := Vector2(-dir.y, dir.x)
		for i in range(randi_range(3, 7)):
			var rank := floorf((i + 1) * 0.5)
			var wing := -1.0 if i % 2 == 0 else 1.0
			var offset := -dir * rank * 26.0 + side * wing * rank * 20.0
			offset += Vector2(randf_range(-6, 6), randf_range(-6, 6))
			var bird := _new_bird("pass", start + offset)
			bird["vel"] = dir * speed * randf_range(0.95, 1.05)
			_birds.append(bird)

	func _step_flight(bird: Dictionary, delta: float) -> void:
		var vel: Vector2 = bird["vel"]
		if bird["state"] == "leave":
			vel = (vel + vel.normalized() * 140.0 * delta).limit_length(CRUISE_SPEED * 1.4)
			bird["vel"] = vel
			bird["height"] = minf(1.0, float(bird["height"]) + delta * 0.8)
		bird["pos"] = (bird["pos"] as Vector2) + vel * delta
		bird["phase"] = float(bird["phase"]) + delta * float(bird["flap"])
		bird["bob"] = sin(float(bird["phase"]) * 0.21) * 6.0 * float(bird["height"])
		if absf(vel.x) > 1.0:
			bird["facing"] = signf(vel.x)

	func _step_arrive(bird: Dictionary, delta: float) -> void:
		var target: Vector2 = (bird["perch"] as Dictionary)["pos"]
		var pos: Vector2 = bird["pos"]
		var to_target := target - pos
		var dist := to_target.length()
		if dist < 2.5:
			_settle(bird, bird["perch"] as Dictionary)
			return
		var speed := lerpf(22.0, CRUISE_SPEED, clampf(dist / 140.0, 0.0, 1.0))
		var vel := to_target / dist * speed
		bird["vel"] = vel
		bird["pos"] = pos + vel * minf(delta, dist / speed)
		bird["height"] = clampf(dist / 140.0, 0.0, 1.0)
		var flap_rate := float(bird["flap"]) * (0.45 if dist < 70.0 else 1.0)
		bird["phase"] = float(bird["phase"]) + delta * flap_rate
		bird["bob"] = sin(float(bird["phase"]) * 0.21) * 5.0 * float(bird["height"])
		if absf(vel.x) > 1.0:
			bird["facing"] = signf(vel.x)

	func _settle(bird: Dictionary, perch: Dictionary) -> void:
		perch["taken"] = true
		bird["perch"] = perch
		bird["state"] = "perch"
		bird["pos"] = perch["pos"]
		bird["vel"] = Vector2.ZERO
		bird["height"] = 0.0
		bird["bob"] = 0.0
		bird["timer"] = randf_range(8.0, 20.0)
		bird["idle"] = randf_range(0.6, 1.8)

	func _step_perch(bird: Dictionary, delta: float, threat: Variant) -> void:
		var perch: Dictionary = bird["perch"]
		var pos: Vector2 = bird["pos"]
		bird["timer"] = float(bird["timer"]) - delta
		if threat is Vector2 and pos.distance_to(threat as Vector2) < FLUSH_RADIUS:
			_take_off(bird, pos - (threat as Vector2))
			return
		if float(bird["timer"]) <= 0.0:
			_take_off(bird, Vector2(randf_range(-1.0, 1.0), -1.0))
			return
		bird["peck"] = maxf(0.0, float(bird["peck"]) - delta * 4.0)
		if float(bird["hop"]) > 0.0:
			var hop := maxf(0.0, float(bird["hop"]) - delta * 4.5)
			bird["hop"] = hop
			bird["pos"] = (bird["hop_to"] as Vector2).lerp(bird["hop_from"] as Vector2, hop)
			return
		bird["idle"] = float(bird["idle"]) - delta
		if float(bird["idle"]) > 0.0:
			return
		bird["idle"] = randf_range(0.5, 1.8)
		var roll := randf()
		var turn_chance := 0.9 if perch["ground"] else 0.35
		if perch["ground"] and roll < 0.45:
			bird["peck"] = 1.0
		elif perch["ground"] and roll < 0.8:
			var home: Vector2 = perch["pos"]
			var step := Vector2(randf_range(-9.0, 9.0), randf_range(-4.0, 4.0))
			var next := (pos + step - home).limit_length(22.0) + home
			bird["hop_from"] = pos
			bird["hop_to"] = next
			bird["hop"] = 1.0
			if absf(next.x - pos.x) > 0.5:
				bird["facing"] = signf(next.x - pos.x)
		elif roll < turn_chance:
			bird["facing"] = -float(bird["facing"])

	func _take_off(bird: Dictionary, away: Vector2) -> void:
		(bird["perch"] as Dictionary)["taken"] = false
		bird["perch"] = {}
		bird["state"] = "leave"
		var dir := away.normalized() if away.length() > 0.01 else Vector2.UP
		dir = (dir + Vector2(0.0, -0.8)).normalized()
		bird["vel"] = dir * 60.0
		bird["flap"] = randf_range(13.0, 16.0)
		bird["height"] = 0.1

	func _draw() -> void:
		for bird in _birds:
			if bird["state"] == "perch":
				_draw_perched(bird)
			else:
				_draw_flying(bird)

	func _draw_flying(bird: Dictionary) -> void:
		var pos: Vector2 = (bird["pos"] as Vector2) + Vector2(0.0, float(bird["bob"]))
		var size: float = bird["size"]
		var height: float = bird["height"]
		var flap := sin(float(bird["phase"]))
		if bird["state"] == "arrive" and height < 0.12:
			flap = 1.0
		var ink: Color = BIRD_INK.lerp(bird["color"] as Color, 1.0 - height)
		var tip_y := -flap * size * 0.7
		var elbow_y := -flap * size * 0.25 - size * 0.12
		draw_polyline(PackedVector2Array([
			pos + Vector2(-size, tip_y), pos + Vector2(-size * 0.45, elbow_y), pos,
		]), ink, 1.8, true)
		draw_polyline(PackedVector2Array([
			pos, pos + Vector2(size * 0.45, elbow_y), pos + Vector2(size, tip_y),
		]), ink, 1.8, true)
		draw_circle(pos + Vector2(float(bird["facing"]) * 1.2, 0.4), 1.6, ink)
		var shadow_pos := pos + Vector2(size * 1.4, size * 5.0) * height
		draw_line(shadow_pos - Vector2(size * 0.7, 0.0), shadow_pos + Vector2(size * 0.7, 0.0),
			Color(0.0, 0.0, 0.0, 0.12), 2.2)

	func _draw_perched(bird: Dictionary) -> void:
		var s: float = float(bird["size"]) / 8.0
		var f: float = bird["facing"]
		var hop_lift := sin(float(bird["hop"]) * PI) * 4.0 * s
		var pos: Vector2 = (bird["pos"] as Vector2) - Vector2(0.0, hop_lift)
		var peck: float = sin(float(bird["peck"]) * PI)
		var plumage: Color = bird["color"]
		var ground: Vector2 = bird["pos"]
		_draw_ellipse(ground + Vector2(0.0, 0.6 * s), Vector2(4.2, 1.3) * s, Color(0.0, 0.0, 0.0, 0.22))
		draw_line(pos + Vector2(-0.9 * s, -1.2 * s), pos + Vector2(-0.9 * s, 0.4 * s), BIRD_INK, 0.9)
		draw_line(pos + Vector2(0.9 * s, -1.2 * s), pos + Vector2(0.9 * s, 0.4 * s), BIRD_INK, 0.9)
		var tail_root := pos + Vector2(-f * 3.2, -3.4) * s
		draw_line(tail_root, tail_root + Vector2(-f * 3.4, 1.2 + peck * -1.5) * s, plumage.darkened(0.3), 1.6 * s)
		var body := pos + Vector2(f * peck * 0.8, -3.6) * s
		_draw_ellipse(body, Vector2(4.0, 2.8) * s, plumage)
		_draw_ellipse(body + Vector2(f * 0.8, 1.0) * s, Vector2(2.4, 1.5) * s, plumage.lightened(0.28))
		var head := pos + Vector2(f * (3.2 + peck * 1.2), -5.8 + peck * 3.2) * s
		draw_circle(head, 1.9 * s, plumage.darkened(0.12))
		draw_circle(head + Vector2(f * 0.7, -0.4) * s, 0.45 * s, Color(0.02, 0.02, 0.02))
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(f * 1.6, -0.5) * s,
			head + Vector2(f * 3.2, 0.2 + peck) * s,
			head + Vector2(f * 1.6, 0.7) * s,
		]), Color(0.86, 0.66, 0.30))

	func _draw_ellipse(centre: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for i in range(14):
			var a := TAU * i / 14.0
			points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
		draw_colored_polygon(points, color)
