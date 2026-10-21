extends Node2D
## Headless cruise check. One NPC, 400 px along each compass direction.
## Prints cadence, stride, extra facing changes, start delay, and stop coast.

const TRAVEL := 400.0
const DT := 1.0 / 60.0
const NAMES := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]


func _ready() -> void:
	NpcNav.bake_world(self, Rect2(Vector2(-400, -400), Vector2(2400, 2400)))
	var actor := NpcActor.new()
	actor.sheet_id = "fun"
	actor.use_avoidance = false
	actor.wander_radius = 0.0
	actor.position = Vector2(800, 800)
	add_child(actor)
	for _i in 30:
		await get_tree().physics_frame
		if actor._map_synced():
			break
	actor.set_physics_process(false)
	if not actor._map_synced():
		print("nav map never synced")
	_print_ground(actor)
	_print_anchors()
	print("dir | cadence | stride_px | extra_faces | start_ticks | coast_px")
	for i in NAMES.size():
		var heading := _heading(i)
		_run_leg(actor, heading, NAMES[i])
	get_tree().quit()


func _heading(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(float(i) * PI * 0.25)


func _run_leg(actor: NpcActor, heading: Vector2, label: String) -> void:
	actor.global_position = Vector2(800, 800)
	actor.velocity = Vector2.ZERO
	var goal := actor.global_position + heading * TRAVEL
	var start_tick := -1
	var faces := 0
	var locked := ""
	var phase_sum := 0.0
	var phase_time := 0.0
	var arrived_at := Vector2.INF
	var coast := 0.0
	var idle_seen := false
	actor.walk_to(goal)
	for tick in 900:
		var before := actor.global_position
		var prev_dir := actor.last_direction
		actor._physics_process(DT)
		var step := actor.global_position - before
		if start_tick < 0 and actor._walking:
			start_tick = tick + 1
		if actor._walking and prev_dir != actor.last_direction:
			faces += 1
			if locked.is_empty() and actor.last_direction == _name_for(heading):
				locked = actor.last_direction
		if actor._walking and actor.get_real_velocity().length() > 70.0:
			phase_sum += actor._animated.speed_scale * NpcFrames.WALK_CYCLES_PER_SEC * DT
			phase_time += DT
		if arrived_at == Vector2.INF and actor.state == NpcActor.State.IDLE and tick > 5:
			arrived_at = before
		if arrived_at != Vector2.INF:
			coast += step.length()
			if not actor._walking and actor.get_real_velocity().length() < 1.0:
				idle_seen = true
				break
	var extra := maxi(faces - 1, 0)
	var cadence := phase_sum / phase_time if phase_time > 0.0 else 0.0
	var stride := actor.walk_speed / NpcFrames.WALK_CYCLES_PER_SEC
	print("%s | %.3f | %.2f | %d | %d | %.2f%s" % [
		label, cadence, stride, extra, start_tick, coast, "" if idle_seen else " (no idle)",
	])


func _name_for(heading: Vector2) -> String:
	var idx := posmod(int(round(heading.angle() / (PI * 0.25))), 8)
	return NAMES[idx]


func _print_ground(actor: NpcActor) -> void:
	var sole := actor._sole_local_y()
	var feet := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var center := feet.position if feet != null else Vector2.ZERO
	var radius := 14.0
	if feet != null and feet.shape is CircleShape2D:
		radius = (feet.shape as CircleShape2D).radius
	var shadow_low := sole
	print("A.12 sole_local_y=%.2f collision_center=(%.2f, %.2f) r=%.1f circle_bottom=%.2f shadow_low=%.2f origin_y=0" % [
		sole, center.x, center.y, radius, center.y + radius, shadow_low,
	])


func _print_anchors() -> void:
	print("A.8 feet anchor x on the placed 256 canvas (target 128)")
	for who in ["chief", "fun", "queen"]:
		var sheet := str(who)
		var frames := NpcFrames.load_or_build(sheet)
		for dir_name in ["down", "down_right", "right", "up_right", "up"]:
			var anim: String = "idle_" + str(dir_name)
			if frames == null or not frames.has_animation(anim):
				print("  %s %s missing" % [who, dir_name])
				continue
			var tex := frames.get_frame_texture(anim, 0)
			var img := tex.get_image()
			var ax := NpcFrames._feet_anchor_x(img)
			print("  %s %s anchor_x=%.1f dx=%+.1f" % [who, dir_name, ax, ax - 128.0])
