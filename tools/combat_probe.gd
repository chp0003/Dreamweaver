extends Node
## Drives the Shadow Weaver and every minion style through their animations.
##   Headless (runtime errors only):
##     Godot_v4.x_console.exe --headless --path . res://tools/CombatProbe.tscn
##   Rendered (also writes frames to res://tools/shots/combat/):
##     Godot_v4.x_console.exe --path . res://tools/CombatProbe.tscn

const OUT_DIR := "res://tools/shots/combat"
const PLAYER_SCENE := "res://scenes/world/Player.tscn"
const SKILLS := [
	ShadowWeaverBoss.Skill.Claw,
	ShadowWeaverBoss.Skill.Lunge,
	ShadowWeaverBoss.Skill.Slam,
	ShadowWeaverBoss.Skill.Volley,
	ShadowWeaverBoss.Skill.Dash,
	ShadowWeaverBoss.Skill.Nova,
	ShadowWeaverBoss.Skill.Summon,
	ShadowWeaverBoss.Skill.Blind,
]

var _world: Node2D
var _boss: ShadowWeaverBoss
var _player: Slang
var _minions: Array[ShadowMinion] = []
var _rendered := false
var _shots := 0
var _ai_lines: Array[String] = []


func _ready() -> void:
	_rendered = DisplayServer.get_name() != "headless"
	if _rendered:
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	_build_arena()
	await _run()
	_report()


func _build_arena() -> void:
	_world = Node2D.new()
	_world.name = "ProbeWorld"
	get_tree().root.add_child(_world)

	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.16, 0.14, 0.2)
	floor_rect.position = Vector2(-1400, -1000)
	floor_rect.size = Vector2(2800, 2000)
	floor_rect.z_index = -50
	_world.add_child(floor_rect)

	var camera := Camera2D.new()
	camera.position = Vector2(0.0, -60.0)
	camera.zoom = Vector2(0.9, 0.9)
	_world.add_child(camera)
	camera.make_current()

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Slang
	_player.position = Vector2(0.0, 150.0)
	_world.add_child(_player)
	_player.max_health = 1000000.0
	_player.health = 1000000.0
	_player.has_staff = true

	_boss = ShadowWeaverBoss.new()
	_boss.position = Vector2(0.0, -40.0)
	_world.add_child(_boss)
	_boss.set_arena(_boss.position, 260.0)
	_boss.scale = Vector2(1.25, 1.25)
	_boss.z_index = 8


func _run() -> void:
	_boss.play_entrance_roar()
	await _wait(0.5)
	await _shot("00_roar")
	await _wait(0.9)
	_boss.begin_duel()

	for skill in SKILLS:
		await _until_approach()
		_boss._start_skill(skill)
		var skill_name := _boss.current_move()
		await _wait(_boss._windup * 0.75)
		await _shot("%02d_%s_windup" % [_shots, skill_name])
		await _wait(_boss._windup * 0.25 + 0.12)
		await _shot("%02d_%s_active" % [_shots, skill_name])
		await _wait(0.6)

	# Let the blind veil clear before the close-ups.
	await _wait(3.2)
	await _until_approach()
	_boss.take_damage(12.0, _player)
	await _wait(0.08)
	await _shot("%02d_boss_hurt" % _shots)
	_boss.stagger()
	await _wait(0.4)
	await _shot("%02d_boss_stunned" % _shots)
	_boss.end_stagger_early()
	await _probe_ai()
	_boss.end_duel()

	var styles := ["chaser", "stalker", "dasher", "caster"]
	for i in range(styles.size()):
		var minion := ShadowMinion.new()
		minion.combat_style = styles[i]
		minion.position = Vector2(-260.0 + 170.0 * i, 40.0)
		minion.scale = Vector2(1.15, 1.15)
		_world.add_child(minion)
		_minions.append(minion)
	await _wait(0.3)
	await _shot("%02d_minions_spawning" % _shots)
	await _wait(2.4)
	await _shot("%02d_minions_fighting" % _shots)
	for minion in _minions:
		if is_instance_valid(minion):
			minion.take_damage(5.0, _player)
	await _wait(0.07)
	await _shot("%02d_minions_hurt" % _shots)
	for minion in _minions:
		if is_instance_valid(minion):
			minion.take_damage(999.0, _player)
	await _wait(0.4)
	await _shot("%02d_minions_dying" % _shots)
	await _wait(1.2)


## Skill variety per stage, armour vs punish damage, perfect dodge, stage
## shifts, and a stretch of the boss fighting on his own.
func _probe_ai() -> void:
	_boss._clear_adds()
	for stage in [1, 2, 3]:
		_boss._stage = stage
		var counts := {}
		for i in range(600):
			for key in _boss._cds.keys():
				_boss._cds[key] = 0.0
			var dist: float = [80.0, 180.0, 300.0][i % 3]
			var pick: int = _boss._pick_skill(dist)
			_boss._last_skill = pick
			for key in ShadowWeaverBoss.SKILL_STAGE.keys():
				_boss._since_used[key] = int(_boss._since_used.get(key, 4)) + 1
			_boss._since_used[pick] = 0
			var skill_name: String = ShadowWeaverBoss.Skill.keys()[pick]
			counts[skill_name] = int(counts.get(skill_name, 0)) + 1
		_ai_lines.append("stage %d picks: %s" % [stage, str(counts)])
	_boss._stage = 1

	await _until_approach()
	var before := _boss.health
	_boss.take_damage(100.0, _player)
	var guarded := before - _boss.health
	_boss._phase = ShadowWeaverBoss.Phase.Recover
	_boss._phase_t = 0.0
	_boss._recover_len = 0.5
	before = _boss.health
	_boss.take_damage(100.0, _player)
	_ai_lines.append("100 dmg -> guarded %.0f, punished %.0f" % [guarded, before - _boss.health])
	await _until_approach()

	var dodged := [false]
	_boss.perfect_dodged.connect(func() -> void: dodged[0] = true)
	_player._dodge_timer = Slang.DODGE_COOLDOWN
	_player._invulnerable = Slang.DODGE_IFRAMES
	ShadowWeaverBoss.strike_player(_player, 20.0, _boss)
	_ai_lines.append("perfect dodge fired: %s, exposed: %s" % [dodged[0], _boss.is_exposed()])
	await _wait(0.5)
	await _until_approach()

	dodged[0] = false
	_player._dodge_timer = 0.0
	_player._dodge_left = 0.0
	_player._invulnerable = 0.0
	_player._ward_timer = 0.0
	_boss._dodge_gap = 0.0
	var hp_before := _player.health
	var raised := _player.try_ward()
	ShadowWeaverBoss.strike_player(_player, 20.0, _boss, true)
	await _shot("%02d_ward_block" % _shots)
	_ai_lines.append("ward raised: %s, blocked: %s, perfect guard: %s" % [raised, is_equal_approx(hp_before, _player.health), dodged[0]])
	await _wait(0.8)
	_player._invulnerable = 0.0
	_boss._laugh_cd = 0.0
	Audio.stop_voice()
	await _wait(0.3)
	var spell_laughs := 0
	var melee_laughs := 0
	for i in range(400):
		_boss._laugh_cd = 0.0
		spell_laughs += int(_boss._gloat(_player, true))
		_boss._laugh_cd = 0.0
		melee_laughs += int(_boss._gloat(_player, false))
	_boss._laugh_cd = 0.0
	var held_back := not _boss._gloat(_player, true) or not _boss._gloat(_player, true)
	_ai_lines.append("laughs per 400 hits: spell %d, melee %d, cooldown holds: %s" % [spell_laughs, melee_laughs, held_back])
	_player.health = _player.max_health
	await _until_approach()

	var stages_seen: Array[int] = []
	_boss.stage_changed.connect(func(stage: int, _line: String) -> void: stages_seen.append(stage))
	_boss.health = _boss.max_health * 0.67
	_boss.take_damage(40.0, _player)
	await _wait(0.5)
	await _shot("%02d_phase_shift" % _shots)
	await _until_approach()
	_boss.health = _boss.max_health * 0.34
	_boss.take_damage(40.0, _player)
	await _until_approach()
	_ai_lines.append("stage shifts: %s (now stage %d)" % [str(stages_seen), _boss.stage()])

	var used := {}
	_boss.telegraph_started.connect(func(_w: float) -> void:
		used[_boss.current_move()] = int(used.get(_boss.current_move(), 0)) + 1)
	var shot_at := 3.0
	var elapsed := 0.0
	while elapsed < 14.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed >= shot_at:
			shot_at += 4.0
			await _shot("%02d_stage3_%s" % [_shots, _boss.current_move()])
	_ai_lines.append("stage 3 live (14s): %s" % str(used))
	await _wait(3.3)


func _report() -> void:
	var leftovers := 0
	for node in _world.find_children("*", "AnimatedSprite2D", true, false):
		if (node as AnimatedSprite2D).material == ShadowFx.additive():
			leftovers += 1
	var minions_left := get_tree().get_nodes_in_group("shadow_minion").size()
	print("\n===== COMBAT PROBE =====")
	print("shots: %d%s" % [_shots, "" if _rendered else " (headless, none saved)"])
	print("boss anims: %s" % ", ".join(_boss._sprite.sprite_frames.get_animation_names()))
	print("minion anims: %s" % ", ".join(ShadowMinion._shared_body_frames().get_animation_names()))
	for line in _ai_lines:
		print(line)
	print("leftover vfx sprites: %d   minions alive: %d" % [leftovers, minions_left])
	print("RESULT: %s" % ("OK" if leftovers == 0 and minions_left == 0 else "CHECK"))
	print("========================\n")
	get_tree().quit(0)


func _until_approach() -> void:
	var guard := 0
	while _boss._phase != ShadowWeaverBoss.Phase.Approach and guard < 400:
		guard += 1
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.0, seconds)).timeout


func _shot(shot_name: String) -> void:
	_shots += 1
	if not _rendered:
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])
