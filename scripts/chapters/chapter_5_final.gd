extends "res://scripts/chapters/house_quest.gd"
## Chapter 5 - The Final Stand at the Sacred Loom.
##
## Three phases, no puzzle screens:
##
##   Phase 1  The Breach          growing packs of Shadow Minions rise from
##                                darkness pools. WASD to move, Space for a
##                                staff sweep, Q for the sonic shockwave. The
##                                loom is sealed until every sprite is gone.
##   Phase 2  The Duel            the Shadow Weaver fights with a real skill kit
##                                (claw, lunge, slam, volley, dash, nova).
##                                Dodge the red tells, punish the recover.
##   Phase 3  Colour returns      beating the Weaver triggers the Color Burst.

const COLLISION_SCENE := "res://scenes/world/House5Collision.tscn"

const STEPS: Array[String] = [
	"Kill the shadows",
	"Defeat the Weaver",
	"Colour returns",
]

## Growing packs so the floor stays readable. Wave 1 is 3, then 4, then 5, then 6.
## Later waves start one size higher and close on bigger packs.
const WAVE_GROUPS: Array = [
	[3, 4, 5, 6],
	[4, 5, 6],
	[6, 7],
]

const LOOM_BLEACH_DAMAGE := 0.18
const APPROACH_RADIUS := 220.0
const BOSS_MUSIC := "res://assets/audio/music/boss_shadow_weaver.ogg"

var _plate: Chapter5Plate
var _loom: Node2D
var _loom_trigger: Interactable
var _loom_aura: AncestralAura
var _veil_barrier: StaticBody2D
var _pools: Array[Node2D] = []
var _boss: ShadowWeaverBoss
var _ancestor: PlaceholderProp
var _beacon: QuestBeacon
var _loom_mark: StationMarker
var _hint: TutorialPrompt
var _shadows_alive := 0
var _shadows_total := 0
var _wave_index := 0
var _pack_index := 0
var _spawn_cursor := 0
var _style_cursor := 0
var _loom_integrity := 1.0
var _weave_mode := false
var _in_weave_game := false
var _duel_over := false
var _phase := 0
var _block_taught := false
var _weave_taught := false


func uses_painted_plate() -> bool:
	return true


func player_spawn_world() -> Vector2:
	if _plate != null:
		return _plate.spawn_world()
	return super.player_spawn_world()


func threshold_world() -> Vector2:
	if _plate != null:
		return _plate.exit_world()
	return Vector2.ZERO


func plate_world_rect() -> Rect2:
	if _plate != null:
		return _plate.global_world_rect()
	return Rect2()


func painted_player_scale() -> float:
	return 2.6


func _process(_delta: float) -> void:
	if _plate != null and player != null and is_instance_valid(player):
		_plate.set_player_world(player.global_position)
	_update_duel_camera()


func _build_world() -> void:
	if host != null:
		host.max_shadows_alive = 18
	_mount_plate()
	_build_hall()
	_beacon = QuestBeacon.new()
	_beacon.name = "QuestBeacon"
	if world != null:
		world.add_child(_beacon)
	else:
		add_child(_beacon)
	if host != null and host.register_as_current_chapter:
		_bind_host_camera()


func _mount_plate() -> void:
	var standalone := host != null and host.register_as_current_chapter
	if standalone:
		if host.floor_node != null:
			host.floor_node.visible = false
		if host.stage != null:
			host.stage.visible = false
	_plate = Chapter5Plate.new()
	_plate.name = "Chapter5Plate"
	_plate.position = Iso.cell_to_world(region_origin)
	add_child(_plate)
	if world != null:
		_plate.attach_solids(world)
	_mount_collision()
	if standalone and player != null:
		var spawn := _plate.spawn_world()
		player.global_position = spawn
		host._spawn_position = spawn


func _mount_collision() -> void:
	var packed := load(COLLISION_SCENE) as PackedScene
	if packed == null:
		if _plate != null:
			_plate.add_fallback_solids()
			if world != null:
				_plate.attach_solids(world)
		return
	var root := packed.instantiate() as Node2D
	root.name = "House5Collision"
	var hall := root.get_node_or_null("HallCollision") as StaticBody2D
	if hall != null:
		hall.set("show_collision_debug", false)
	var host_node: Node2D = world if world != null else self
	host_node.add_child(root)
	if _plate != null:
		root.global_transform = _plate.global_transform
	if hall != null and hall.get_parent() != host_node:
		var xf := hall.global_transform
		hall.reparent(host_node)
		hall.global_transform = xf
		hall.name = "House5Collision"
		root.queue_free()


func _build_hall() -> void:
	_loom = _anchor("SacredLoom", _plate.loom_reach_world())
	_loom_aura = AncestralAura.new()
	_loom_aura.aura_color = Color(0.96, 0.82, 0.48, 0.9)
	_loom_aura.mote_count = 22
	_loom_aura.start_energy = 0.5
	_loom.add_child(_loom_aura)
	_loom_trigger = place_interactable("Use the loom", _plate.loom_reach_world(), {
		"enabled": false,
		"radius": 120.0,
	})
	_loom_trigger.interacted.connect(_on_loom_used)
	_loom_mark = StationMarker.new()
	_loom_mark.title = "THE LOOM"
	_loom.add_child(_loom_mark)
	_loom_mark.position = Vector2(0.0, -88.0)
	_loom_mark.set_lit(false)
	if _color_anchor != null:
		_color_anchor.global_position = _plate.loom_reach_world()
	_lock_loom_approach()

	for i in range(Chapter5Plate.SPAWN_UVS.size()):
		var pool := _anchor("ShadowPool_%d" % i, _plate.spawn_point(i))
		_dress_shadow_pool(pool)
		_pools.append(pool)

	_ancestor = place_prop("FUN KDUNGON", _plate.ghost_world(), {
		"texture_path": "res://assets/images/characters/fun_kdungon.png",
		"prop_size": Vector2(110.0, 188.0),
		"body_color": Palette.BLACK_CHARCOAL,
		"accent_color": Palette.GOLD_SACRED,
		"show_label": false,
		"float_amplitude": 0.0,
		"float_speed": 0.7,
		"blocks_movement": false,
		"cast_shadow": true,
	})
	_ancestor.modulate.a = 0.0
	_ancestor.visible = false

	_boss = ShadowWeaverBoss.new()
	_boss.max_health = 680.0
	if world != null:
		world.add_child(_boss)
	else:
		add_child(_boss)
	_boss.global_position = _plate.boss_world()
	_boss.set_arena(_plate.boss_world(), 268.0)
	# The generated boss already fills a 320px frame. At 2.15x most of its
	# upper body was outside the camera; 1.25x remains imposing but readable.
	_boss.scale = Vector2(1.25, 1.25)
	_boss.modulate = Color(1, 1, 1, 0)
	_boss.visible = false


func _anchor(anchor_name: String, world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = anchor_name
	if world != null:
		world.add_child(node)
	else:
		add_child(node)
	node.global_position = world_pos
	return node


func _bind_host_camera() -> void:
	if host == null or _plate == null:
		return
	host.camera_limit_rect = _plate.global_world_rect()
	var z := plate_camera_zoom()
	var rect := _plate.global_world_rect()
	if host.camera != null:
		host.camera_zoom = Vector2(z, z)
		host.camera.zoom = Vector2(z, z)
		var view := host.get_viewport_rect().size / Vector2(z, z)
		host.camera_follows_player = view.x < rect.size.x or view.y < rect.size.y
		if host.camera_follows_player and player != null:
			host.camera.global_position = player.global_position
		else:
			host.camera.global_position = rect.get_center()
		if player != null and player.has_method("apply_depth_scale"):
			player.apply_depth_scale(painted_player_scale())
	host.apply_camera_world_limits()
	host._clamp_camera()


func _bind_player_combat() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_staff:
		player.equip_staff()
	if not player.chimed.is_connected(_on_player_chimed):
		player.chimed.connect(_on_player_chimed)
	if not player.attack_hit.is_connected(_on_player_attack_hit):
		player.attack_hit.connect(_on_player_attack_hit)
	_ensure_hint()


func _ensure_hint() -> void:
	if _hint != null:
		return
	_hint = TutorialPrompt.new()
	_hint.name = "ChapterCoach"
	var layer: Node = ui_layer if ui_layer != null else self
	layer.add_child(_hint)


func _coach(title: String, body: String, keys: Array = []) -> void:
	_ensure_hint()
	_hint.show_hint(title, body, keys, 1, 1, "row", "WHAT TO DO")


func _clear_coach() -> void:
	if _hint != null:
		_hint.hide_prompt()


func _point_loom(lit: bool, action := "[E]") -> void:
	if _beacon != null:
		if lit:
			_beacon.pin(_loom)
		else:
			_beacon.clear()
	if _loom_mark != null:
		_loom_mark.set_lit(lit, action)


func apply_restored_color() -> void:
	super.apply_restored_color()
	if _plate != null:
		_plate.set_restore(1.0)
		_plate.set_sanctity(1.0)
		_plate.set_loom_energy(1.2)


# --------------------------------------------------------------------------
# Chapter flow
# --------------------------------------------------------------------------

func _run_chapter() -> void:
	_bind_player_combat()
	_set_steps(0)
	objective("Kill the shadows on the floor.")
	Audio.set_ambience(0.35, 0.0)

	await say([
		"The Sacred Loom is the big wooden frame at the back of this hall. Shadows are climbing out of the floor. Kill them first. Then walk to the loom.",
	])

	if not await _phase_one_breach():
		_stop_combat_audio()
		return
	if not await _phase_two_duel():
		_stop_combat_audio()
		return
	await _phase_three_finish()
	_stop_combat_audio()


## PHASE 1 - clear every shadow before the Loom can be approached.
func _phase_one_breach() -> bool:
	_phase = 1
	_shadows_alive = 0
	_shadows_total = _count_planned_shadows()
	_spawn_cursor = 0
	_style_cursor = 0
	_set_steps(0)
	objective("Kill the dark figures. Press [Space] to swing.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "SPACE  swing     Q  shockwave", Color(0.92, 0.82, 0.5))
	Audio.set_combat_drums(0.85, 148.0)
	Audio.set_ambience(0.55, 0.0)
	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", true)
	_coach(
		"Kill the shadows",
		"Walk with WASD. Press Space to swing the staff. Press Q if they pile on you.",
		["SPACE", "Q"]
	)

	for wave_index in range(WAVE_GROUPS.size()):
		if is_finished():
			return false
		_wave_index = wave_index
		var packs: Array = WAVE_GROUPS[wave_index]
		for pack_index in range(packs.size()):
			if is_finished():
				return false
			_pack_index = pack_index
			var pack_size := int(packs[pack_index])
			if pack_index > 0:
				counter("A larger pack rises  ·  Wave %d of %d" % [
					wave_index + 1,
					WAVE_GROUPS.size(),
				])
				await wait(0.4)
			_spawn_pack(pack_size)
			# Next pack overlaps the last survivor so the siege never fully idles.
			# The last pack of a wave must die out before the next wave begins.
			var remain_gate := 0 if pack_index == packs.size() - 1 else 1
			await until(func() -> bool: return _shadows_alive <= remain_gate or is_finished())
		if is_finished():
			return false
		_heal_after_wave()
		if wave_index < WAVE_GROUPS.size() - 1:
			counter("More shadows  ·  wave %d of %d" % [wave_index + 2, WAVE_GROUPS.size()])
			await wait(0.85)

	_clear_coach()
	counter("")
	_unlock_loom_approach()
	_point_loom(true, "WALK")
	Audio.set_combat_drums(0.25, 110.0)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")
	await say([
		"The floor is clear. Walk to the big loom at the back of the hall.",
	])
	objective("Walk to the big loom at the back.")
	_coach("Walk to the loom", "Go to the gold mark in front of the loom.", [])
	await until(func() -> bool: return _player_near_loom() or is_finished())
	_clear_coach()
	return not is_finished()


## PHASE 2 - a chasing melee duel.
func _phase_two_duel() -> bool:
	_phase = 2
	_set_steps(1)
	_point_loom(false)
	await _materialize_boss()

	await say([
		{"speaker": "The Shadow Weaver", "text": "I am only what is left when nobody remembers."},
		{"speaker": "S'lang", "text": "Then I will remember."},
	])
	GameState.unlock_lore("shadow_weaver")

	_play_boss_music()
	Audio.set_combat_drums(0.7, 128.0)
	if hud != null:
		if hud.has_method("show_boss_health"):
			hud.call("show_boss_health", true)
		elif hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", true)
		_sync_boss_hud()

	if not _boss.telegraph_started.is_connected(_on_telegraph_started):
		_boss.telegraph_started.connect(_on_telegraph_started)
		_boss.telegraph_resolved.connect(_on_telegraph_resolved)
		_boss.staggered.connect(_on_boss_staggered)
		_boss.recovered.connect(_on_boss_recovered)
		_boss.health_changed.connect(_on_boss_health_changed)
		_boss.defeated.connect(_on_boss_defeated)

	_enter_fight_stance()
	_coach(
		"Dodge, then hit",
		"Red on the floor is a skill. Shift to roll out. Space when it recovers. Q if you are crowded.",
		["SHIFT", "SPACE"]
	)
	_boss.begin_duel()

	await until(func() -> bool: return _duel_over or is_finished())
	clear_camera_focus()
	return not is_finished()


## PHASE 3 - the Weaver is down. Colour returns. No minigame.
func _phase_three_finish() -> void:
	_phase = 3
	_set_steps(2)
	_boss.end_duel()
	if _boss.has_method("kneel"):
		_boss.kneel()
	counter("")
	_clear_coach()
	_point_loom(false)
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")
	if hud != null:
		if hud.has_method("show_boss_health"):
			hud.call("show_boss_health", false)
		elif hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", false)
	if player != null and is_instance_valid(player) and not player.is_dead():
		player.heal_full()
	objective("")
	Audio.set_combat_drums(0.25, 104.0)
	if is_instance_valid(_loom):
		focus_camera_on(_loom.global_position + Vector2(0.0, -40.0), Vector2(1.12, 1.12))
	await say([
		{"speaker": "S'lang", "text": "I remember you. That is enough."},
	])
	await _color_burst()
	await _closing_cutscene()


# --------------------------------------------------------------------------
# Phase 1 helpers
# --------------------------------------------------------------------------

func _count_planned_shadows() -> int:
	var total := 0
	for packs in WAVE_GROUPS:
		for pack_size in packs:
			total += int(pack_size)
	return total


func _spawn_pack(count: int) -> void:
	var slots := Chapter5Plate.SPAWN_UVS.size()
	var start := _spawn_cursor
	shake_camera(4.0 + float(count) * 0.35)
	for i in range(count):
		var pool_index := (start + i) % slots
		var origin := _plate.spawn_point(pool_index) if _plate != null else Vector2.ZERO
		origin += Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 18.0))
		if pool_index < _pools.size() and is_instance_valid(_pools[pool_index]):
			Fx.pool_rise(_pools[pool_index])
		var style := _next_combat_style()
		var minion := place_minion(origin, {
			"combat_style": style,
			"max_health": 38.0 if style == "caster" else 42.0,
			"speed": 84.0 if style == "caster" else (108.0 if style == "dasher" else 96.0),
			"touch_damage": 9.0 if style == "caster" else 11.0,
			"spawn_delay": 0.22 + float(i) * 0.10,
		})
		if minion == null:
			_shadows_total = maxi(0, _shadows_total - 1)
			continue
		minion.scale = Vector2(1.15, 1.15)
		minion.died.connect(_on_minion_died)
		_shadows_alive += 1
	_spawn_cursor = (start + count) % slots
	_refresh_shadow_counter()


## Four melee, then one ranged — 80 / 20, spread through the siege.
func _next_combat_style() -> String:
	var slot := _style_cursor % 5
	_style_cursor += 1
	if slot == 4:
		return "caster"
	var melee: Array[String] = ["chaser", "dasher", "stalker"]
	return melee[slot % melee.size()]


func _on_minion_died(_minion: ShadowMinion) -> void:
	_shadows_alive = maxi(0, _shadows_alive - 1)
	_shadows_total = maxi(0, _shadows_total - 1)
	_refresh_shadow_counter()


func _heal_after_wave() -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	player.heal_full()
	Fx.hit_flash(player, Palette.GOLD_SUN)
	Fx.punch(player, 0.08)


func _refresh_shadow_counter() -> void:
	counter("Shadows Remaining: %d   ·   Wave %d of %d" % [
		_shadows_total,
		_wave_index + 1,
		WAVE_GROUPS.size(),
	])


func _dress_shadow_pool(node: Node2D) -> void:
	var stain := Sprite2D.new()
	stain.name = "Stain"
	stain.texture = _soft_blob()
	stain.modulate = Color(0.07, 0.03, 0.10, 0.78)
	stain.scale = Vector2(1.35, 0.48)
	stain.z_index = -6
	node.add_child(stain)
	var wisps := GPUParticles2D.new()
	wisps.name = "Wisps"
	wisps.texture = _soft_blob()
	wisps.amount = 10
	wisps.lifetime = 1.8
	wisps.preprocess = 0.6
	wisps.randomness = 0.8
	wisps.z_index = -4
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 50.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.scale_min = 0.18
	mat.scale_max = 0.42
	mat.color = Color(0.16, 0.07, 0.20, 0.55)
	wisps.process_material = mat
	wisps.emitting = true
	node.add_child(wisps)


func _dress_veil(body: StaticBody2D) -> void:
	var mist := Sprite2D.new()
	mist.name = "VeilMist"
	mist.texture = _soft_blob()
	mist.modulate = Color(0.08, 0.04, 0.12, 0.7)
	mist.scale = Vector2(5.4, 0.85)
	mist.z_index = 4
	body.add_child(mist)
	var sparks := GPUParticles2D.new()
	sparks.texture = _soft_blob()
	sparks.amount = 16
	sparks.lifetime = 1.6
	sparks.preprocess = 0.5
	sparks.z_index = 5
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(210.0, 10.0, 1.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 40.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 26.0
	mat.gravity = Vector3(0.0, -14.0, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.3
	mat.color = Color(0.28, 0.12, 0.34, 0.5)
	sparks.process_material = mat
	sparks.emitting = true
	body.add_child(sparks)


func _soft_blob() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var centre := Vector2(31.5, 31.5)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x, y).distance_to(centre) / 32.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 2.1)))
	return ImageTexture.create_from_image(image)


func _lock_loom_approach() -> void:
	_loom_trigger.set_enabled(false)
	if _veil_barrier != null and is_instance_valid(_veil_barrier):
		return
	_veil_barrier = StaticBody2D.new()
	_veil_barrier.name = "ShadowVeil"
	_veil_barrier.collision_layer = PhysicsLayers.LAYER_WORLD
	_veil_barrier.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(460.0, 36.0)
	shape.shape = box
	_veil_barrier.add_child(shape)
	if world != null:
		world.add_child(_veil_barrier)
	else:
		add_child(_veil_barrier)
	if _plate != null:
		_veil_barrier.global_position = _plate.veil_world()
	_dress_veil(_veil_barrier)


func _unlock_loom_approach() -> void:
	if _veil_barrier != null and is_instance_valid(_veil_barrier):
		var fade := create_tween()
		fade.tween_property(_veil_barrier, "modulate:a", 0.0, 0.35)
		fade.tween_callback(_veil_barrier.queue_free)
	_veil_barrier = null
	if _plate != null:
		_plate.set_loom_energy(0.9)
	if _loom_aura != null:
		_loom_aura.set_energy(0.85, 0.8)


func _player_near_loom() -> bool:
	if player == null or not is_instance_valid(player) or _loom == null:
		return false
	return player.global_position.distance_to(_loom.global_position) <= APPROACH_RADIUS


# --------------------------------------------------------------------------
# Phase 2 helpers
# --------------------------------------------------------------------------

func _materialize_boss() -> void:
	_boss.visible = true
	_boss.z_index = 8
	Audio.play_wind_whistle()
	Audio.play_sfx(Audio.Sfx.THUD)
	shake_camera(12.0)
	var appear := create_tween()
	appear.tween_property(_boss, "modulate:a", 1.0, 1.15)
	await wait(1.25)


func _play_boss_music() -> void:
	if ResourceLoader.exists(BOSS_MUSIC) or FileAccess.file_exists(BOSS_MUSIC):
		Audio.play_music(BOSS_MUSIC, -8.0)


func _enter_fight_stance() -> void:
	_weave_mode = false
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	objective("Dodge the skills. Kill the Weaver.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "SHIFT dodge   SPACE strike   Q shock", Color(0.94, 0.72, 0.48))
	counter("Roll the red. Hit the recover.")
	if _plate != null:
		_plate.set_loom_energy(0.55)


func _enter_defend_mode() -> void:
	_enter_fight_stance()


func _enter_weave_mode() -> void:
	_enter_punish_window()


func _enter_punish_window() -> void:
	_weave_mode = false
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	objective("It's stunned. Hit it. Press [Space].")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "HIT  —  now", Color(0.92, 0.84, 0.5))
	counter("Stunned — swing.")
	if not _weave_taught:
		_weave_taught = true
		_coach("Punish", "The Weaver is down. Stay on it and swing.", ["SPACE"])
	if _plate != null:
		_plate.set_loom_energy(1.4)
	if _loom_aura != null:
		_loom_aura.set_energy(1.3, 0.4)
		_loom_aura.burst()


## Staff swings shake the hall. Defence is the dodge, not a parry QTE.
func _on_player_attacked(_swing_position: Vector2, _facing: Vector2) -> void:
	shake_camera(4.5)
	if _phase == 1:
		Audio.play_brass_shock()


func _on_player_chimed(_origin: Vector2, _radius: float) -> void:
	if _phase < 1:
		return
	Audio.play_brass_shock()
	shake_camera(8.0)


func _on_player_attack_hit(_hit: Node2D) -> void:
	if _phase == 1:
		_clear_coach()
		Audio.play_brass_shock()
	elif _phase == 2:
		shake_camera(5.5)
		Audio.play_sfx(Audio.Sfx.HIT)


func _on_telegraph_started(_window: float) -> void:
	if not _block_taught:
		_block_taught = true
		_clear_coach()
	var move_name := _boss.current_move() if _boss != null else "claw"
	match move_name:
		"lunge":
			counter("LUNGE — roll aside")
		"slam":
			counter("SLAM — get out of the circle")
		"volley":
			counter("VOLLEY — dodge the bolts")
		"dash":
			counter("DASH — it will reappear")
		"nova":
			counter("NOVA — roll through the ring")
		"summon":
			counter("SUMMON — kill the shadows")
		"blind":
			counter("BLIND — the hall goes dark")
		_:
			counter("CLAW — roll aside")


func _on_telegraph_resolved(parried: bool) -> void:
	if parried:
		counter("Interrupted.")
		_clear_coach()
		shake_camera(6.0)
		return
	shake_camera(10.0 if _boss != null and _boss.is_heavy_attack() else 6.0)
	if _boss != null and _boss.is_heavy_attack():
		counter("Missed — now hit it")
	else:
		counter("Keep swinging")


func _on_boss_staggered(_duration: float) -> void:
	_enter_punish_window()
	shake_camera(8.0)


func _on_boss_recovered() -> void:
	if _duel_over:
		return
	_clear_coach()
	_enter_fight_stance()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	_sync_boss_hud()
	if _duel_over:
		return
	if _boss != null and _boss.is_telegraphing():
		return
	counter("Weaver  %d%%" % roundi(current / maximum * 100.0))


func _sync_boss_hud() -> void:
	if hud == null or _boss == null:
		return
	if hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _boss.health, _boss.max_health)
	elif hud.has_method("set_loom_integrity"):
		hud.call("set_loom_integrity", _boss.health_ratio())


func _update_duel_camera() -> void:
	if _phase != 2 or _duel_over or is_finished():
		return
	if player == null or not is_instance_valid(player):
		return
	if _boss == null or not is_instance_valid(_boss) or not _boss.visible:
		return
	var mid := player.global_position.lerp(_boss.global_position, 0.42)
	focus_camera_on(mid + Vector2(0.0, -40.0), Vector2(1.04, 1.04))


func _on_boss_defeated() -> void:
	_duel_over = true


func _on_loom_used() -> void:
	return


## The loom's own health bar. Losing it costs a life, not the run.
func _damage_loom(amount: float) -> void:
	_loom_integrity = maxf(0.0, _loom_integrity - amount)
	if hud != null and hud.has_method("set_loom_integrity"):
		hud.call("set_loom_integrity", _loom_integrity)
	if _loom_integrity > 0.0:
		return

	if not GameState.lose_life():
		_duel_over = true
		await fail_chapter()
		return

	banner("The loom took a hit. You lost a life.", 1.8)
	_loom_integrity = 0.5
	if hud != null and hud.has_method("set_loom_integrity"):
		hud.call("set_loom_integrity", _loom_integrity)


# --------------------------------------------------------------------------
# Phase 3 - the payoff
# --------------------------------------------------------------------------

## Full-screen particle bloom, then the grayscale shader is switched off for
## good and the save is marked complete.
func _color_burst() -> void:
	set_player_input(false)
	counter("")
	objective("")
	banner("Colour returns.")
	Audio.play_sfx(Audio.Sfx.CHIME)
	Audio.play_brass_shock()
	shake_camera(10.0)

	if is_instance_valid(_boss):
		if _boss.has_method("dissolve_into_light"):
			_boss.dissolve_into_light()
		else:
			Fx.fiber_burst(_boss, Palette.GOLD_SUN)
			var dissolve := create_tween()
			dissolve.set_parallel(true)
			dissolve.tween_property(_boss, "modulate:a", 0.0, 1.15)
			dissolve.tween_property(_boss, "scale", Vector2(1.7, 0.12), 1.15)
	await wait(0.85)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 280.0, 1.0, 1.1)
	await wait(1.0)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 720.0, 1.0, 1.4)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	Audio.play_sfx(Audio.Sfx.BELL)

	var burst := _make_burst()
	burst.global_position = _loom.global_position if is_instance_valid(_loom) else Vector2.ZERO
	world.add_child(burst)
	burst.emitting = true
	shake_camera(16.0)

	var flash := ColorRect.new()
	flash.color = Color(1, 0.96, 0.82, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash)

	var flare := create_tween()
	flare.tween_property(flash, "color:a", 0.88, 0.45)
	await flare.finished

	# The moment the whole world comes back.
	ColorRestoration.restore_world(2.4)
	if _plate != null:
		_plate.bloom_restore(2.6)
		_plate.bloom_sanctity(1.0, 2.2)
		_plate.set_loom_energy(1.8)
	GameState.complete_house(house_id)
	GameState.complete_game()
	if _loom_aura != null:
		_loom_aura.set_energy(1.6, 0.6)
		_loom_aura.burst()

	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 1.8)
	await fade.finished
	flash.queue_free()
	await wait(1.0)


func _make_burst() -> GPUParticles2D:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 24.0
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 260.0
	material.initial_velocity_max = 740.0
	material.gravity = Vector3(0.0, 80.0, 0.0)
	material.scale_min = 2.2
	material.scale_max = 7.0
	material.angular_velocity_min = -220.0
	material.angular_velocity_max = 220.0

	# The three sacred colours, thrown outward at once.
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1.0, 0.92, 0.6, 1.0))
	ramp.add_point(0.45, Color(0.85, 0.2, 0.16, 1.0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(0.15, 0.13, 0.13, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture

	var particles := GPUParticles2D.new()
	particles.name = "ColorBurst"
	particles.process_material = material
	particles.amount = 900
	particles.lifetime = 2.8
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.emitting = false
	particles.z_index = 60
	return particles


## Gray statues become living NPCs, the land turns green, then the credits.
func _closing_cutscene() -> void:
	clear_camera_focus()
	Audio.set_combat_drums(0.0)
	Audio.set_ambience(0.4, 11.0)
	Audio.stop_music()

	await say([
		"Colour runs back into the cloth, the hall, the mountain paths.",
	])

	if is_instance_valid(_ancestor):
		_ancestor.visible = true
		var arrive := create_tween()
		arrive.tween_property(_ancestor, "modulate:a", 1.0, 0.9)
		await arrive.finished
		# A single nod of gratitude.
		var nod := create_tween()
		nod.tween_property(_ancestor, "rotation_degrees", 14.0, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		nod.tween_property(_ancestor, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await nod.finished

	await wait(0.6)

	await say([
		"Fun Kdungon nods once, then is only light.",
		{"speaker": "S'lang", "text": "I will teach it. To anyone who will sit still and learn."},
	])

	objective("")
	_quest_finished = true
	SceneFader.fade_to_scene(AccountManager.ENDING_SCENE)


func _set_steps(current: int) -> void:
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", STEPS, current)


func _stop_combat_audio() -> void:
	Audio.set_combat_drums(0.0)
	Audio.set_ambience(0.3, 0.0)
