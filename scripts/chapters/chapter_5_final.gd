extends "res://scripts/chapters/house_quest.gd"
## Chapter 5 - The Final Stand at the Sacred Loom.
##
## Three phases, no puzzle screens:
##
##   Phase 1  The Breach          growing packs of Shadow Minions rise from
##                                darkness pools. WASD to move, Space for a
##                                staff sweep, Q for the sonic shockwave. The
##                                loom is sealed until every sprite is gone.
##   Phase 2  The Duel            Defend: roll and ward the bleach tells.
##                                Weave: a heavy stun opens the loom. E starts
##                                the rhythm track; clean notes damage him.
##   Phase 3  The Finishing Stitch  a W A S D stitch, then the Color Burst.

const COLLISION_SCENE := "res://scenes/world/House5Collision.tscn"

const STEPS: Array[String] = [
	"Kill the shadows",
	"Defeat the Weaver",
	"Colour returns",
]

## Three breach waves, then the Weaver. Packs get bigger and meaner.
const WAVE_GROUPS: Array = [
	[5, 6],
	[6, 7, 7],
	[6, 7, 7],
]
const WAVE_LABELS: Array[String] = ["I", "II", "III"]

const APPROACH_RADIUS := 220.0
## Flat heal after breach waves 1 and 2. Wave 3 still fills her before the duel.
const WAVE_HEAL_PARTIAL := 14.0
const BOSS_MUSIC := "res://assets/audio/music/boss_shadow_weaver.wav"
const RHYTHM_TRACK := "res://scenes/minigames/RhythmTrack.tscn"
const FINISHING_STITCH := "res://scenes/minigames/QteSequence.tscn"
## One clean rhythm note, before the stagger damage bonus.
const WEAVE_NOTE_DAMAGE := 72.0
const LOOM_MAX := 100.0
const LOOM_BLEACH_HIT := 16.0
const WEAVE_WAIT := 12.0
## Weave is a rare punish, not the main fight. Stagger still opens a melee window.
const WEAVE_STAGGERS_NEEDED := 3
const WEAVE_COOLDOWN := 26.0
const STAGE_LINES := {
	2: "ENOUGH! You will drown in the dark!",
	3: "No! I will not fade! I will not be forgotten!",
}

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
var _e_prompt: Control
var _e_key: Label
var _e_pulse: Tween
var _shadows_alive := 0
var _shadows_total := 0
var _wave_index := 0
var _pack_index := 0
var _spawn_cursor := 0
var _style_cursor := 0
var _duel_over := false
var _phase := 0
var _block_taught := false
var _weave_taught := false
var _perfect_taught := false
var _weaving := false
var _loom_pressed := false
var _loom_hp := LOOM_MAX
var _burst_live := false
var _finisher_play := false
var _finisher_done := false
var _staggers_since_weave := 0
var _weave_cd := 0.0


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


func _process(delta: float) -> void:
	if _plate != null and player != null and is_instance_valid(player):
		_plate.set_player_world(player.global_position)
	if _phase == 2 and not _weaving:
		_weave_cd = maxf(0.0, _weave_cd - delta)
	_update_duel_camera()


func _input(event: InputEvent) -> void:
	if not _weaving or _loom_pressed or _duel_over or _phase != 2:
		return
	if event.is_echo() or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_on_loom_used()


func _build_world() -> void:
	if host != null:
		host.max_shadows_alive = 28
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
	strip_editor_marks(root)
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
	if _loom_trigger != null:
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
	_boss.max_health = 4000.0
	_boss.poise_to_stagger = 640.0
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


func _show_e_prompt() -> void:
	_ensure_e_prompt()
	_e_prompt.visible = true
	_e_prompt.modulate.a = 1.0
	if _e_pulse != null:
		_e_pulse.kill()
	_e_pulse = create_tween().set_loops()
	_e_pulse.tween_property(_e_key, "scale", Vector2(1.12, 1.12), 0.42).set_trans(Tween.TRANS_SINE)
	_e_pulse.tween_property(_e_key, "scale", Vector2(1.0, 1.0), 0.42).set_trans(Tween.TRANS_SINE)


func _hide_e_prompt() -> void:
	if _e_pulse != null:
		_e_pulse.kill()
		_e_pulse = null
	if _e_prompt != null:
		_e_prompt.visible = false


func _ensure_e_prompt() -> void:
	if _e_prompt != null:
		return
	var font := preload("res://assets/fonts/Cinzel-Bold.ttf")
	_e_prompt = Control.new()
	_e_prompt.name = "WeaveEPrompt"
	_e_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_e_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: Node = ui_layer if ui_layer != null else self
	layer.add_child(_e_prompt)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.offset_left = -140.0
	stack.offset_right = 140.0
	stack.offset_top = -160.0
	stack.offset_bottom = 160.0
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_e_prompt.add_child(stack)

	var press := Label.new()
	press.text = "PRESS"
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.add_theme_font_override("font", font)
	press.add_theme_font_size_override("font_size", 22)
	press.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(press)

	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(120.0, 120.0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.08, 0.92)
	box.set_border_width_all(4)
	box.border_color = Palette.GOLD_SUN
	box.set_corner_radius_all(16)
	box.shadow_color = Color(0.95, 0.82, 0.35, 0.55)
	box.shadow_size = 18
	plate.add_theme_stylebox_override("panel", box)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(plate)

	_e_key = Label.new()
	_e_key.text = "E"
	_e_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_e_key.add_theme_font_override("font", font)
	_e_key.add_theme_font_size_override("font_size", 72)
	_e_key.add_theme_color_override("font_color", Palette.GOLD_SUN)
	_e_key.pivot_offset = Vector2(60.0, 60.0)
	_e_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_e_key)

	var hint := Label.new()
	hint.text = "He's open"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hint)
	_e_prompt.visible = false


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
		"Shadows are climbing out of the floor. Kill them, then walk to the loom.",
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
	_point_loom(false)
	_shadows_alive = 0
	_shadows_total = _count_planned_shadows()
	_spawn_cursor = 0
	_style_cursor = 0
	_set_steps(0)
	objective("Kill the dark figures. Press [Space] to swing.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "SPACE swing   SHIFT roll   Q shock", Color(0.92, 0.82, 0.5))
	if not Audio.set_house(house_id):
		Audio.set_combat_drums(0.85, 148.0)
	Audio.set_ambience(0.55, 0.0)
	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", true)

	for wave_index in range(WAVE_GROUPS.size()):
		if is_finished():
			return false
		_wave_index = wave_index
		var packs: Array = WAVE_GROUPS[wave_index]
		banner("Wave %d  ·  %s" % [wave_index + 1, WAVE_LABELS[wave_index]], 2.0)
		for pack_index in range(packs.size()):
			if is_finished():
				return false
			_pack_index = pack_index
			var pack_size := int(packs[pack_index])
			if pack_index > 0:
				counter("A larger pack rises  ·  Wave %d of %d  ·  %s" % [
					wave_index + 1,
					WAVE_GROUPS.size(),
					WAVE_LABELS[wave_index],
				])
				await wait(0.4)
			_spawn_pack(pack_size)
			var remain_gate := 0
			if pack_index < packs.size() - 1:
				remain_gate = 2 if wave_index < 2 else 3
			await until(func() -> bool: return _shadows_alive <= remain_gate or is_finished())
		if is_finished():
			return false
		_heal_after_wave()
		if wave_index == WAVE_GROUPS.size() - 1:
			_grant_light_beam()
		if wave_index < WAVE_GROUPS.size() - 1:
			counter("Wave %d  ·  %s" % [wave_index + 2, WAVE_LABELS[wave_index + 1]])
			await wait(0.85)

	_clear_coach()
	counter("")
	_unlock_loom_approach()
	_point_loom(true, "WALK")
	if not Audio.is_house_theme_playing(house_id):
		Audio.set_combat_drums(0.25, 110.0)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "1 ward    2 light beam", Color(0.98, 0.9, 0.55))
	objective("Walk to the loom.")
	await until(func() -> bool: return _player_near_loom() or is_finished())
	return not is_finished()


## PHASE 2 - a chasing melee duel.
func _phase_two_duel() -> bool:
	_phase = 2
	_set_steps(1)
	_point_loom(false)
	await _materialize_boss()

	Audio.set_combat_drums(0.0)
	Audio.set_ambience(0.2, 0.0)
	await say([
		{"speaker": "The Shadow Weaver", "text": "So. The little weaver comes to the loom, at last.", "voice": "weaver_intro_1"},
		{"speaker": "S'lang", "text": "Give the colour back."},
		{"speaker": "The Shadow Weaver", "text": "I am what is left when nobody remembers. I have swallowed a thousand forgotten names.", "voice": "weaver_intro_2"},
		{"speaker": "The Shadow Weaver", "text": "Your village. Your ancestors. Your colour. All of it... is mine.", "voice": "weaver_intro_3"},
		{"speaker": "S'lang", "text": "Then I will remember them. Every one."},
		{"speaker": "The Shadow Weaver", "text": "Then come, child. And be forgotten.", "voice": "weaver_intro_4"},
	])
	GameState.unlock_lore("shadow_weaver")

	if not _play_boss_music():
		Audio.set_combat_drums(0.7, 128.0)
	if hud != null:
		if hud.has_method("show_boss_health"):
			hud.call("show_boss_health", true)
		if hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", true)
		_loom_hp = LOOM_MAX
		_sync_boss_hud()
		_sync_loom_hud()

	if not _boss.telegraph_started.is_connected(_on_telegraph_started):
		_boss.telegraph_started.connect(_on_telegraph_started)
		_boss.telegraph_resolved.connect(_on_telegraph_resolved)
		_boss.staggered.connect(_on_boss_staggered)
		_boss.recovered.connect(_on_boss_recovered)
		_boss.health_changed.connect(_on_boss_health_changed)
		_boss.defeated.connect(_on_boss_defeated)
		_boss.stage_changed.connect(_on_boss_stage_changed)
		_boss.perfect_dodged.connect(_on_boss_perfect_dodged)

	_enter_fight_stance()
	_boss.begin_duel()

	await until(func() -> bool: return (_duel_over and not _weaving) or is_finished())
	clear_camera_focus()
	return not is_finished()


## PHASE 3 - the Weaver kneels. The last stitch, then the Color Burst.
func _phase_three_finish() -> void:
	_phase = 3
	_set_leave_enabled(true)
	_set_steps(2)
	_boss.end_duel()
	if _boss_alive() or (_boss != null and is_instance_valid(_boss)):
		_boss.kneel()
	counter("")
	_clear_coach()
	_point_loom(false)
	if hud != null:
		if hud.has_method("show_boss_health"):
			hud.call("show_boss_health", false)
		if hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", false)
	if player != null and is_instance_valid(player) and not player.is_dead():
		player.heal_full()
	Audio.set_combat_drums(0.25, 104.0)
	if player != null and is_instance_valid(player) and _boss != null and is_instance_valid(_boss):
		focus_camera_on(
			player.global_position.lerp(_boss.global_position, 0.45) + Vector2(0.0, -36.0),
			Vector2(1.08, 1.08)
		)
	await say([
		{"speaker": "S'lang", "text": "I remember you. That is enough."},
	])
	objective("The last stitch.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "W A S D", Color(0.98, 0.9, 0.55))
	var stitched := false
	while not stitched and not is_finished():
		stitched = await run_mini_game(FINISHING_STITCH, {
			"start_window": 1.7,
			"end_window": 0.95,
		}, _wire_finish)
		if not stitched and not is_finished():
			_burst_live = false
			await say(["The thread slips."])
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")
	objective("")
	if not _finisher_done:
		await _play_finisher()
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
	var stats := _wave_stats()
	for i in range(count):
		var pool_index := (start + i) % slots
		var origin := _plate.spawn_point(pool_index) if _plate != null else Vector2.ZERO
		origin += Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 18.0))
		if pool_index < _pools.size() and is_instance_valid(_pools[pool_index]):
			Fx.pool_rise(_pools[pool_index])
		var style := _next_combat_style()
		var minion := place_minion(origin, {
			"combat_style": style,
			"max_health": float(stats["caster_hp"]) if style == "caster" else float(stats["hp"]),
			"speed": float(stats["caster_speed"]) if style == "caster" else (float(stats["dash_speed"]) if style == "dasher" else float(stats["speed"])),
			"touch_damage": float(stats["caster_damage"]) if style == "caster" else float(stats["damage"]),
			"spawn_delay": 0.18 + float(i) * 0.08,
		})
		if minion == null:
			_shadows_total = maxi(0, _shadows_total - 1)
			continue
		minion.scale = Vector2(1.15, 1.15)
		minion.died.connect(_on_minion_died)
		_shadows_alive += 1
	_spawn_cursor = (start + count) % slots
	_refresh_shadow_counter()


func _wave_stats() -> Dictionary:
	match _wave_index:
		0:
			return {hp = 52.0, caster_hp = 44.0, speed = 128.0, dash_speed = 156.0, caster_speed = 96.0, damage = 13.0, caster_damage = 11.0}
		1:
			return {hp = 72.0, caster_hp = 60.0, speed = 148.0, dash_speed = 184.0, caster_speed = 112.0, damage = 17.0, caster_damage = 14.0}
		_:
			return {hp = 76.0, caster_hp = 62.0, speed = 152.0, dash_speed = 188.0, caster_speed = 114.0, damage = 18.0, caster_damage = 14.5}


func _next_combat_style() -> String:
	match _wave_index:
		0:
			var early := _style_cursor % 3
			_style_cursor += 1
			return ["chaser", "dasher", "chaser"][early]
		1:
			var mid := _style_cursor % 4
			_style_cursor += 1
			return ["chaser", "dasher", "stalker", "caster"][mid]
		_:
			var late := _style_cursor % 5
			_style_cursor += 1
			return ["dasher", "stalker", "chaser", "caster", "dasher"][late]


func _on_minion_died(_minion: ShadowMinion) -> void:
	_shadows_alive = maxi(0, _shadows_alive - 1)
	_shadows_total = maxi(0, _shadows_total - 1)
	_refresh_shadow_counter()


func _grant_light_beam() -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("unlock_light_beam"):
		return
	if player.has_light_beam:
		return
	player.unlock_light_beam()
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	Audio.play_sfx(Audio.Sfx.CHIME)
	shake_camera(6.0)
	Fx.light_burst(player, Palette.GOLD_SUN)
	Fx.hit_flash(player, Palette.GOLD_SUN)
	banner("NEW SKILL  ·  LIGHT BEAM", 3.2)
	if hud != null:
		if hud.has_method("set_mode"):
			hud.call("set_mode", "PRESS  2  ·  LIGHT BEAM", Color(1.0, 0.92, 0.45))
		if hud.has_method("pulse_beam_unlock"):
			hud.call("pulse_beam_unlock")
	_coach("Light Beam unlocked", "Press [2]. A beam of remembered sunlight — hold your facing, then fire.", ["2"])


func _heal_after_wave() -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	if _wave_index >= WAVE_GROUPS.size() - 1:
		player.heal_full()
	else:
		player.heal(WAVE_HEAL_PARTIAL)
	Fx.hit_flash(player, Palette.GOLD_SUN)
	Fx.punch(player, 0.08)


func _refresh_shadow_counter() -> void:
	var grade := WAVE_LABELS[_wave_index] if _wave_index < WAVE_LABELS.size() else ""
	counter("Shadows Remaining: %d   ·   Wave %d of %d  ·  %s" % [
		_shadows_total,
		_wave_index + 1,
		WAVE_GROUPS.size(),
		grade,
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


static var _blob: Texture2D


func _soft_blob() -> Texture2D:
	if _blob != null:
		return _blob
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var centre := Vector2(31.5, 31.5)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x, y).distance_to(centre) / 32.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 2.1)))
	_blob = ImageTexture.create_from_image(image)
	return _blob


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
	_boss.global_position = _plate.boss_world()
	_boss.z_index = 0
	_boss.visible = true
	if player != null and is_instance_valid(player):
		player.global_position = _boss.global_position + Vector2(0.0, 220.0)
		player.velocity = Vector2.ZERO
	_boss.play_entrance_roar()
	shake_camera(12.0)
	var appear := create_tween()
	appear.tween_property(_boss, "modulate:a", 1.0, 1.15)
	await wait(1.25)


func _play_boss_music() -> bool:
	if not ResourceLoader.exists(BOSS_MUSIC) and not FileAccess.file_exists(BOSS_MUSIC):
		return false
	Audio.play_music(BOSS_MUSIC, -7.0)
	return Audio.is_music_playing()


func _enter_fight_stance() -> void:
	_set_leave_enabled(false)
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	objective("Defeat the Weaver.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "", Color(0.94, 0.72, 0.48))
	counter("")
	if _plate != null:
		_plate.set_loom_energy(0.55)


func _set_leave_enabled(enabled: bool) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().root.find_children("*", "Interactable", true, false):
		var prompt := str(node.get("prompt"))
		if prompt.begins_with("Leave"):
			node.call("set_enabled", enabled)


func _on_loom_used() -> void:
	if _phase != 2 or not _weaving:
		return
	_loom_pressed = true
	_hide_e_prompt()
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)


func _open_weave() -> void:
	if _weaving or _duel_over or _phase != 2:
		return
	_weaving = true
	_loom_pressed = false
	if _boss != null and is_instance_valid(_boss):
		_boss.set_combat_paused(true)
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	objective("Press [E].")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "PRESS  E", Color(0.95, 0.84, 0.45))
	counter("")
	_show_e_prompt()
	if _plate != null:
		_plate.set_loom_energy(1.4)
	if _loom_aura != null:
		_loom_aura.set_energy(1.3, 0.4)
		_loom_aura.burst()

	var waited := 0.0
	while waited < WEAVE_WAIT and not _loom_pressed and not _duel_over and not is_finished():
		await wait(0.1)
		waited += 0.1
	_hide_e_prompt()
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	_clear_coach()
	if _loom_pressed and not _duel_over and not is_finished() and _boss_alive():
		if hud != null and hud.has_method("set_mode"):
			hud.call("set_mode", "WEAVE  —  W A S D", Color(0.95, 0.84, 0.45))
		await run_mini_game(RHYTHM_TRACK, {}, _wire_rhythm)
	_close_weave()


func _wire_rhythm(game: Node) -> void:
	if game.has_signal("note_resolved"):
		game.connect("note_resolved", _on_rhythm_note)


func _on_rhythm_note(hit: bool) -> void:
	if not hit or not _boss_alive():
		return
	_boss.take_damage(WEAVE_NOTE_DAMAGE, player)
	Fx.light_burst(_boss, Palette.GOLD_SUN)
	_repair_loom(4.0)


func _close_weave() -> void:
	var was_weaving := _weaving
	_weaving = false
	_loom_pressed = false
	_hide_e_prompt()
	if _loom_trigger != null:
		_loom_trigger.set_enabled(false)
	_point_loom(false)
	if _boss_alive():
		if was_weaving:
			_boss.resume_after_weave()
		else:
			_boss.set_combat_paused(false)
	if not _duel_over and not is_finished():
		_enter_fight_stance()


func _boss_alive() -> bool:
	return _boss != null and is_instance_valid(_boss) and _boss.health > 0.0


func _damage_loom(amount: float) -> void:
	_loom_hp = maxf(0.0, _loom_hp - amount)
	_sync_loom_hud()
	if _plate != null:
		_plate.set_loom_energy(0.25 + 0.75 * (_loom_hp / LOOM_MAX))
	if _loom_hp > 0.0:
		return
	banner("The loom frays.", 1.4)
	shake_camera(8.0)
	if player != null and is_instance_valid(player) and not player.is_dead():
		player.take_damage(22.0, _boss)
	_loom_hp = 40.0
	_sync_loom_hud()


func _repair_loom(amount: float) -> void:
	_loom_hp = minf(LOOM_MAX, _loom_hp + amount)
	_sync_loom_hud()


func _sync_loom_hud() -> void:
	if hud != null and hud.has_method("set_loom_integrity"):
		hud.call("set_loom_integrity", _loom_hp / LOOM_MAX)


## Staff swings shake the hall. Defence is the dodge, not a parry QTE.
func _on_player_attacked(_swing_position: Vector2, _facing: Vector2) -> void:
	# House 5's swing cue is already house5_brass_shockwave. A second call here doubled it.
	shake_camera(4.5)


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
		shake_camera(5.5 if _boss != null and _boss.is_exposed() else 2.5)


func _on_telegraph_started(_window: float) -> void:
	Audio.play_wind_whistle()
	_clear_coach()
	counter("")


func _on_telegraph_resolved(parried: bool) -> void:
	if parried:
		_clear_coach()
		shake_camera(6.0)
		return
	shake_camera(10.0 if _boss != null and _boss.is_heavy_attack() else 6.0)
	_damage_loom(LOOM_BLEACH_HIT if _boss != null and _boss.is_heavy_attack() else LOOM_BLEACH_HIT * 0.5)


func _on_boss_staggered(_duration: float) -> void:
	shake_camera(8.0)
	_staggers_since_weave += 1
	# Most staggers are a melee punish. The loom only opens rarely.
	if _weaving or _weave_cd > 0.0 or _staggers_since_weave < WEAVE_STAGGERS_NEEDED:
		if not _weaving and not _duel_over:
			objective("He's open — strike!")
		return
	_staggers_since_weave = 0
	_weave_cd = WEAVE_COOLDOWN
	_open_weave()


func _on_boss_stage_changed(stage: int, _line: String) -> void:
	if _duel_over:
		return
	shake_camera(16.0)
	banner(STAGE_LINES.get(stage, "The Weaver rages."), 2.4)
	if _plate != null:
		_plate.set_loom_energy(0.35 if stage >= 3 else 0.45)


func _on_boss_perfect_dodged() -> void:
	if _duel_over:
		return
	shake_camera(5.0)
	var guarded := player != null and player.is_warding()
	_repair_loom(8.0)


func _on_boss_recovered() -> void:
	if _duel_over or _weaving:
		return
	_clear_coach()
	_enter_fight_stance()


func _on_boss_health_changed(_current: float, _maximum: float) -> void:
	_sync_boss_hud()


func _sync_boss_hud() -> void:
	if hud == null or _boss == null:
		return
	if hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _boss.health, _boss.max_health)
	_sync_loom_hud()


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
	_loom_pressed = true
	if _weaving and ui_layer != null:
		for child in ui_layer.get_children():
			if child.has_signal("finished"):
				child.finished.emit(true)
				break


# --------------------------------------------------------------------------
# Phase 3 - the payoff
# --------------------------------------------------------------------------

func _wire_finish(game: Node) -> void:
	if game.has_signal("final_stitch"):
		game.final_stitch.connect(_play_finisher)


func _play_finisher() -> void:
	if _finisher_play:
		await until(func() -> bool: return _finisher_done or is_finished())
		return
	_finisher_play = true
	Engine.time_scale = 1.0
	set_player_input(false)
	if player == null or not is_instance_valid(player) or _boss == null or not is_instance_valid(_boss):
		_finisher_done = true
		return
	focus_camera_on(
		player.global_position.lerp(_boss.global_position, 0.5) + Vector2(0.0, -36.0),
		Vector2(1.12, 1.12)
	)
	if player.global_position.distance_to(_boss.global_position) > 90.0:
		await player.run_finisher_approach(_boss)
	if not is_instance_valid(player) or not is_instance_valid(_boss):
		_finisher_done = true
		return
	player.play_finisher_strike(_boss)
	shake_camera(12.0)
	Fx.hit_flash(_boss, Palette.GOLD_SUN)
	Fx.light_burst(_boss, Palette.GOLD_SUN)
	Fx.punch(_boss, 0.12)
	await wait(0.22)
	if is_instance_valid(player):
		player.force_chime_pulse()
	if is_instance_valid(_boss):
		Fx.fiber_burst(_boss, Palette.GOLD_SUN)
		Fx.light_burst(_boss, Palette.GOLD_SACRED)
		if _boss.has_method("dissolve_into_light"):
			_boss.dissolve_into_light()
	shake_camera(16.0)
	await wait(0.18)
	_finisher_done = true


## The last correct key throws the burst out from the loom.
func _launch_color_burst() -> void:
	if _burst_live:
		return
	_burst_live = true
	Audio.play_sfx(Audio.Sfx.CHIME)
	Audio.play_brass_shock()
	shake_camera(16.0)
	if _plate != null:
		_plate.set_loom_energy(1.8)
	if _loom_aura != null:
		_loom_aura.set_energy(1.6, 0.6)
		_loom_aura.burst()
	var burst := _make_burst()
	burst.global_position = _loom.global_position if is_instance_valid(_loom) else Vector2.ZERO
	var host: Node = world if world != null else self
	host.add_child(burst)
	burst.emitting = true


## Full-screen particle bloom, then the grayscale shader is switched off for
## good and the save is marked complete.
func _color_burst() -> void:
	set_player_input(false)
	counter("")
	objective("")
	banner("Colour returns.")
	_launch_color_burst()
	shake_camera(10.0)

	if is_instance_valid(_boss) and _boss.modulate.a > 0.45:
		if _boss.has_method("dissolve_into_light"):
			Fx.fiber_burst(_boss, Palette.GOLD_SUN)
			_boss.dissolve_into_light()
		else:
			Fx.fiber_burst(_boss, Palette.GOLD_SUN)
			var dissolve := create_tween()
			dissolve.set_parallel(true)
			dissolve.tween_property(_boss, "modulate:a", 0.0, 1.15)
			dissolve.tween_property(_boss, "scale", Vector2(1.7, 0.12), 1.15)
	await wait(0.2)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 280.0, 1.0, 0.45)
	await wait(0.2)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 720.0, 1.0, 1.4)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	Audio.play_sfx(Audio.Sfx.BELL)

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
	material.emission_sphere_radius = 18.0
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 480.0
	material.initial_velocity_max = 1100.0
	material.gravity = Vector3.ZERO
	material.radial_accel_min = 40.0
	material.radial_accel_max = 160.0
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
	particles.amount = 1100
	particles.lifetime = 1.7
	particles.one_shot = true
	particles.explosiveness = 1.0
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
