extends "res://scripts/chapters/house_quest.gd"
## Chapter 5 - The Final Stand at the Sacred Loom.
##
## Three phases, no puzzle screens:
##
##   Phase 1  The Breach          dozens of Shadow Minions rise from darkness
##                                pools. WASD to move, Space for a staff sweep,
##                                Q for the sonic shockwave. The loom is sealed
##                                until every sprite is gone.
##   Phase 2  The Duel of Rhythms approaching the loom materialises the Shadow
##                                Weaver. Defend Mode parries Bleach Attacks;
##                                a heavy overextend staggers it into Weave Mode
##                                where the rhythm track damages the boss.
##   Phase 3  The Finishing Stitch a W/A/S/D QTE over a T'nalak overlay, then
##                                the Color Burst that restores the whole world.

const RHYTHM_TRACK := "res://scenes/minigames/RhythmTrack.tscn"
const QTE_SEQUENCE := "res://scenes/minigames/QteSequence.tscn"
const COLLISION_SCENE := "res://scenes/world/House5Collision.tscn"

const STEPS: Array[String] = [
	"Kill the shadows",
	"Block, then use the loom",
	"Press the letters",
]

## Three waves. Small enough to read the hall, large enough to feel like a siege.
const WAVES: Array[int] = [5, 5, 6]

const RHYTHM_DAMAGE := 9.0
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


func plate_camera_zoom() -> float:
	return 0.86


func painted_player_scale() -> float:
	return 2.6


func _process(_delta: float) -> void:
	if _plate != null and player != null and is_instance_valid(player):
		_plate.set_player_world(player.global_position)


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
		_pools.append(_anchor("ShadowPool_%d" % i, _plate.spawn_point(i)))

	_ancestor = place_prop("MASTER WEAVER", _plate.ghost_world(), {
		"texture_path": "res://assets/images/characters/master_weaver_ghost.png",
		"prop_size": Vector2(110.0, 188.0),
		"body_color": Color(0.55, 0.52, 0.48),
		"accent_color": Color(0.82, 0.74, 0.5),
		"show_label": false,
		"float_amplitude": 5.0,
		"float_speed": 0.9,
		"blocks_movement": false,
		"cast_shadow": false,
	})
	_ancestor.modulate.a = 0.0
	_ancestor.visible = false

	_boss = ShadowWeaverBoss.new()
	_boss.max_health = 100.0
	if world != null:
		world.add_child(_boss)
	else:
		add_child(_boss)
	_boss.global_position = _plate.boss_world()
	_boss.scale = Vector2(2.15, 2.15)
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

	for wave_index in range(WAVES.size()):
		if is_finished():
			return false
		_wave_index = wave_index
		_spawn_wave(WAVES[wave_index])
		await until(func() -> bool: return _shadows_alive <= 0 or is_finished())
		if is_finished():
			return false
		if wave_index < WAVES.size() - 1:
			counter("More shadows  ·  wave %d of %d" % [wave_index + 2, WAVES.size()])
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


## PHASE 2 - the hybrid boss fight.
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
		if hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", true)
		if hud.has_method("set_loom_integrity"):
			hud.call("set_loom_integrity", _loom_integrity)

	if not _boss.telegraph_started.is_connected(_on_telegraph_started):
		_boss.telegraph_started.connect(_on_telegraph_started)
		_boss.telegraph_resolved.connect(_on_telegraph_resolved)
		_boss.staggered.connect(_on_boss_staggered)
		_boss.recovered.connect(_on_boss_recovered)
		_boss.health_changed.connect(_on_boss_health_changed)
		_boss.defeated.connect(_on_boss_defeated)

	_enter_defend_mode()
	_coach(
		"Block the ring",
		"A white ring shrinks around the boss. When it gets small, press Space.",
		["SPACE"]
	)
	_boss.begin_duel()

	await until(func() -> bool: return _duel_over or is_finished())
	return not is_finished()


## PHASE 3 - the quick-time finale and the Color Burst.
func _phase_three_finish() -> void:
	_phase = 3
	_set_steps(2)
	_boss.end_duel()
	if _boss.has_method("kneel"):
		_boss.kneel()
	counter("")
	_clear_coach()
	_point_loom(true, "[KEYS]")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")
	if hud != null and hud.has_method("show_loom_integrity"):
		hud.call("show_loom_integrity", false)

	objective("Press the letter on screen before the bar empties.")
	Audio.set_combat_drums(0.4, 118.0)
	if is_instance_valid(_loom):
		focus_camera_on(_loom.global_position + Vector2(0.0, -40.0), Vector2(1.12, 1.12))
	await say([
		{"speaker": "S'lang", "text": "One last stitch. Hit the letters as they appear."},
	])

	# If the finale is fluffed entirely, the Shadow Weaver reforms rather than
	# dead-ending the run: the player goes back to Phase 2 with a weakened boss.
	while true:
		var stitched: bool = await run_mini_game(QTE_SEQUENCE, {
			"prompt_count": 8,
			"start_window": 1.05,
			"end_window": 0.48,
		})
		if stitched:
			break
		clear_camera_focus()
		await say([
			{"speaker": "The Shadow Weaver", "text": "You missed a letter. Block again, then try the keys once more."},
		])
		if not await _reform_boss():
			return
		if is_instance_valid(_loom):
			focus_camera_on(_loom.global_position + Vector2(0.0, -40.0), Vector2(1.12, 1.12))

	await _color_burst()
	await _closing_cutscene()


# --------------------------------------------------------------------------
# Phase 1 helpers
# --------------------------------------------------------------------------

func _spawn_wave(count: int) -> void:
	var slots := Chapter5Plate.SPAWN_UVS.size()
	for i in range(count):
		var pool_index := i % slots
		var origin := _plate.spawn_point(pool_index) if _plate != null else Vector2.ZERO
		origin += Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 18.0))
		if pool_index < _pools.size() and is_instance_valid(_pools[pool_index]):
			Fx.pool_rise(_pools[pool_index])
		var minion := place_minion(origin, {
			"max_health": 42.0,
			"speed": 96.0,
			"touch_damage": 11.0,
			"spawn_delay": 0.45 + float(i) * 0.16,
		})
		if minion == null:
			continue
		minion.scale = Vector2(2.15, 2.15)
		minion.died.connect(_on_minion_died)
		_shadows_alive += 1
		_shadows_total += 1
	_refresh_shadow_counter()


func _on_minion_died(_minion: ShadowMinion) -> void:
	_shadows_alive = maxi(0, _shadows_alive - 1)
	_refresh_shadow_counter()


func _refresh_shadow_counter() -> void:
	counter("Wave %d of %d   ·   %d left" % [_wave_index + 1, WAVES.size(), _shadows_alive])


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


func _enter_defend_mode() -> void:
	_weave_mode = false
	_loom_trigger.set_enabled(false)
	_point_loom(false)
	objective("When the white ring gets small, press [Space].")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "SPACE when the ring is small", Color(0.94, 0.72, 0.48))
	counter("Watch the ring around the boss.")
	if _plate != null:
		_plate.set_loom_energy(0.45)


func _enter_weave_mode() -> void:
	_weave_mode = true
	_loom_trigger.set_enabled(true)
	_point_loom(true, "[E]")
	objective("The boss is stunned. Run to the loom and press [E].")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "E at the loom  —  now", Color(0.92, 0.84, 0.5))
	counter("Go to the loom. Press E.")
	if not _weave_taught:
		_weave_taught = true
		_coach("Use the loom", "The boss is stunned. Run to the gold mark and press E.", ["E"])
	if _plate != null:
		_plate.set_loom_energy(1.4)
	if _loom_aura != null:
		_loom_aura.set_energy(1.3, 0.4)
		_loom_aura.burst()


## Every staff swing during a wind-up is a parry attempt.
func _on_player_attacked(_swing_position: Vector2, _facing: Vector2) -> void:
	shake_camera(4.5)
	if _phase == 1:
		Audio.play_brass_shock()
	if _boss != null and is_instance_valid(_boss) and _boss.is_telegraphing():
		_boss.try_parry()


func _on_player_chimed(_origin: Vector2, _radius: float) -> void:
	if _phase < 1:
		return
	Audio.play_brass_shock()
	shake_camera(8.0)


func _on_player_attack_hit(_hit: Node2D) -> void:
	if _phase == 1:
		_clear_coach()
		Audio.play_brass_shock()


func _on_telegraph_started(_window: float) -> void:
	if _weave_mode:
		return
	if not _block_taught:
		_block_taught = true
		_clear_coach()
	if _boss != null and _boss.is_heavy_attack():
		counter("NOW — Space  (big one)")
	else:
		counter("NOW — press Space")


func _on_telegraph_resolved(parried: bool) -> void:
	if parried:
		counter("Blocked.")
		_clear_coach()
		return

	var damage := _boss.bleach_damage
	if _boss.is_heavy_attack():
		damage *= 1.4
	counter("Too early or too late. Wait until the ring is small.")
	if player != null and is_instance_valid(player):
		player.take_damage(damage, _boss)
	_damage_loom(LOOM_BLEACH_DAMAGE * (1.35 if _boss.is_heavy_attack() else 1.0))


func _on_boss_staggered(_duration: float) -> void:
	_enter_weave_mode()


func _on_boss_recovered() -> void:
	if _duel_over or _in_weave_game:
		return
	_clear_coach()
	_enter_defend_mode()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if _weave_mode or _duel_over:
		return
	if _boss != null and _boss.is_telegraphing():
		return
	counter("Boss  %d%%" % roundi(current / maximum * 100.0))


func _on_boss_defeated() -> void:
	_duel_over = true


## Player reached the loom during Weave Mode: open the rhythm track.
func _on_loom_used() -> void:
	if not _weave_mode or _in_weave_game or _duel_over or is_finished():
		return
	if _phase < 2:
		return
	_in_weave_game = true
	_loom_trigger.set_enabled(false)
	_clear_coach()
	_point_loom(false)
	objective("Press W A S D as the notes hit the glowing line.")

	await run_mini_game(RHYTHM_TRACK, {
		"note_count": 12,
		"note_speed": 320.0,
		"spawn_interval": 0.46875,
	}, func(game: Node) -> void:
		if game.has_signal("note_resolved"):
			game.note_resolved.connect(_on_rhythm_note))

	_in_weave_game = false
	if _duel_over or is_finished():
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.end_stagger_early()
	_enter_defend_mode()


func _on_rhythm_note(hit: bool) -> void:
	if not hit or _boss == null or not is_instance_valid(_boss):
		return
	_boss.take_damage(RHYTHM_DAMAGE, player)
	Fx.light_burst(_boss, Palette.GOLD_SUN)
	if _loom != null:
		ColorRestoration.bloom_zone("rhythm_hit", _loom, 160.0, 0.55, 0.28)
	if _plate != null:
		_plate.set_loom_energy(1.2)
	shake_camera(5.0)


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


## After a failed finale the boss stands back up at a fraction of its strength.
func _reform_boss() -> bool:
	if _boss == null or not is_instance_valid(_boss):
		return false
	_duel_over = false
	_phase = 2
	_boss.rotation_degrees = 0.0
	_boss.scale = Vector2(2.15, 2.15)
	_boss.modulate = Color.WHITE
	_boss.health = _boss.max_health * 0.25
	_boss.health_changed.emit(_boss.health, _boss.max_health)
	_boss.begin_duel()
	_enter_defend_mode()
	_set_steps(1)

	await until(func() -> bool: return _duel_over or is_finished())
	if is_finished():
		return false

	_phase = 3
	_boss.end_duel()
	if _boss.has_method("kneel"):
		_boss.kneel()
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")
	return true


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
		"The Master Weaver nods once, then is only light.",
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
