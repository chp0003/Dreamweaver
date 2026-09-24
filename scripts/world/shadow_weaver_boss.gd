class_name ShadowWeaverBoss
extends CharacterBody2D
## Action duel: Elden Ring tells, God of War punish windows, DOTA skill kit.
## Dodge red, hit the recover. No parry QTE, no letter minigame.

signal health_changed(current: float, maximum: float)
signal telegraph_started(window: float)
signal telegraph_resolved(parried: bool)
signal staggered(duration: float)
signal recovered
signal defeated

enum Skill { None, Claw, Lunge, Slam, Volley, Dash, Nova, Summon, Blind }
enum Phase { Approach, Windup, Active, Recover, Stagger, Dead }

const BODY_SIZE := Vector2i(360, 460)
const BODY_DRAW_H := 300
const FRAME_GUTTER := 12
const STRIKE_SPLIT := 4
const SPRITE_SCALE := Vector2(0.78, 0.78)
const STRIP_FRAMES := 8
const ORIGINAL_SHEET := "res://assets/images/enemies/shadow_weaver_boss_sheet.png"
const SHEET_IDLE := "res://assets/images/enemies/shadow_weaver_idle.png"
const SHEET_WALK := "res://assets/images/enemies/shadow_weaver_walk.png"
const SHEET_CLAW := "res://assets/images/enemies/shadow_weaver_claw.png"
const SHEET_LUNGE := "res://assets/images/enemies/shadow_weaver_lunge.png"
const SHEET_SLAM := "res://assets/images/enemies/shadow_weaver_slam.png"
const SHEET_CAST := "res://assets/images/enemies/shadow_weaver_cast.png"
const SHEET_DASH := "res://assets/images/enemies/shadow_weaver_dash.png"
const SHEET_NOVA := "res://assets/images/enemies/shadow_weaver_nova.png"
const SHEET_SUMMON := "res://assets/images/enemies/shadow_weaver_summon.png"
const SHEET_STAGGER := "res://assets/images/enemies/shadow_weaver_stagger.png"
const SHEET_DEATH := "res://assets/images/enemies/shadow_weaver_death.png"
const SHEET_BLIND := "res://assets/images/enemies/shadow_weaver_blind.png"
const SHEET_COLS := 4
const SHEET_ROWS := 3
const VFX_SLASH := "res://assets/images/vfx/weaver_claw_slash.png"
const VFX_SLAM := "res://assets/images/vfx/weaver_slam_ring.png"
const VFX_BOLT := "res://assets/images/vfx/weaver_shadow_bolt.png"
const VFX_NOVA := "res://assets/images/vfx/weaver_nova_ring.png"

@export var max_health := 680.0
@export var chase_speed := 168.0
@export var keep_range := 72.0
@export var stagger_duration := 1.28
@export var poise_to_stagger := 175.0

var health := 100.0

var _active := false
var _dead := false
var _phase := Phase.Approach
var _skill := Skill.None
var _timer := 0.55
var _phase_t := 0.0
var _windup := 0.0
var _active_len := 0.0
var _recover_len := 0.0
var _stagger_left := 0.0
var _poise := 0.0
var _heavy := false
var _home := Vector2.ZERO
var _arena_radius := 280.0
var _aim := Vector2(0, 1)
var _strike_at := Vector2.ZERO
var _lunge_vel := Vector2.ZERO
var _hits_landed := 0
var _volleys_shot := 0
var _adds: Array[Node] = []
var _cds := {
	Skill.Claw: 0.0,
	Skill.Lunge: 0.0,
	Skill.Slam: 0.0,
	Skill.Volley: 0.0,
	Skill.Dash: 0.0,
	Skill.Nova: 0.0,
	Skill.Summon: 0.0,
	Skill.Blind: 0.0,
}

var _art: PlaceholderProp
var _sprite: AnimatedSprite2D
var _tell: Node2D
var _danger: Polygon2D
var _smoke: GPUParticles2D
var _select_ring: Polygon2D
var _vfx_frames: Dictionary = {}
var _flash_left := 0.0
var _ghost_cd := 0.0
var _nova_flashed := false
var _pose_tween: Tween
var _dash_dest := Vector2.ZERO
var _hp_bar: ProgressBar
var _hp_label: Label
var _veil: CanvasLayer


func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_home = global_position
	_ensure_feet()
	_build_visuals()
	_sync_hp_bar()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	for key in _cds.keys():
		_cds[key] = maxf(0.0, float(_cds[key]) - delta)
	velocity = Vector2.ZERO
	if not _active or _dead:
		move_and_slide()
		return
	match _phase:
		Phase.Stagger:
			_stagger_left -= delta
			if _stagger_left <= 0.0:
				_end_stagger()
		Phase.Windup:
			_phase_t += delta
			_update_tell(clampf(_phase_t / maxf(0.001, _windup), 0.0, 1.0))
			if _skill == Skill.Nova and not _nova_flashed and _phase_t >= _windup * 0.72:
				_nova_flashed = true
				Fx.light_burst(self, _skill_color())
			if _skill == Skill.Blind and not _nova_flashed and _phase_t >= _windup * 0.8:
				_nova_flashed = true
				Fx.light_burst(self, _skill_color())
			if _phase_t >= _windup:
				_enter_active()
		Phase.Active:
			_phase_t += delta
			_tick_active(delta)
			if _phase_t >= _active_len:
				_enter_recover()
		Phase.Recover:
			_phase_t += delta
			_face_player()
			if _phase_t >= _recover_len:
				_enter_approach(0.16)
		Phase.Approach:
			_timer -= delta
			_chase_player(delta)
			if _timer <= 0.0:
				_try_start_skill()
	if _phase == Phase.Windup or _phase == Phase.Active or _phase == Phase.Recover:
		_drive_skill_pose()
	move_and_slide()
	_clamp_arena()


func begin_duel() -> void:
	_active = true
	_dead = false
	_phase = Phase.Approach
	_skill = Skill.None
	_timer = 0.28
	_poise = 0.0
	_home = global_position
	_cds[Skill.Lunge] = 1.0
	_cds[Skill.Volley] = 1.6
	_cds[Skill.Slam] = 3.4
	_cds[Skill.Dash] = 2.4
	_cds[Skill.Nova] = 7.0
	_cds[Skill.Summon] = 5.5
	_cds[Skill.Blind] = 4.5
	_sync_hp_bar()
	if not is_in_group("hittable"):
		add_to_group("hittable")
	_play_visual("idle", true)
	if _smoke != null:
		_smoke.emitting = true


func end_duel() -> void:
	_active = false
	_lunge_vel = Vector2.ZERO
	_hide_tell()
	_clear_adds()
	if is_in_group("hittable"):
		remove_from_group("hittable")
	if _smoke != null:
		_smoke.emitting = false
	_clear_blind()
	_sync_hp_bar()


func is_hittable() -> bool:
	return _active and not _dead and visible and modulate.a > 0.2


func set_arena(home: Vector2, radius: float) -> void:
	_home = home
	_arena_radius = radius


func is_staggered() -> bool:
	return _phase == Phase.Stagger


func is_telegraphing() -> bool:
	return _phase == Phase.Windup


func current_move() -> String:
	match _skill:
		Skill.Lunge:
			return "lunge"
		Skill.Slam:
			return "slam"
		Skill.Volley:
			return "volley"
		Skill.Dash:
			return "dash"
		Skill.Nova:
			return "nova"
		Skill.Summon:
			return "summon"
		Skill.Claw:
			return "claw"
		Skill.Blind:
			return "blind"
		_:
			return "idle"


func hit_radius() -> float:
	return 150.0


## Points up the body so a click on the cloak, not only the feet, locks him.
func click_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for height in [0.0, 46.0, 96.0, 148.0, 200.0, 252.0]:
		pts.append(to_global(Vector2(0.0, -height)))
	return pts


func try_parry() -> bool:
	return false


func is_heavy_attack() -> bool:
	return _heavy


func health_ratio() -> float:
	return health / maxf(1.0, max_health)


func set_selected(on: bool) -> void:
	if _select_ring != null:
		_select_ring.visible = on


func take_damage(amount: float, _source: Node = null) -> bool:
	if not is_hittable() or amount <= 0.0:
		return false
	if _phase == Phase.Stagger:
		amount *= 1.4
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_sync_hp_bar()
	_flash(Color(1.8, 1.5, 1.5))
	_poise += amount
	if _phase != Phase.Stagger and _poise >= poise_to_stagger:
		stagger()
	if health <= 0.0:
		_die()
	return true


func stagger(duration: float = -1.0) -> void:
	if _dead or _phase == Phase.Stagger:
		return
	_phase = Phase.Stagger
	_lunge_vel = Vector2.ZERO
	_hide_tell()
	if _pose_tween != null:
		_pose_tween.kill()
	if _sprite != null:
		_sprite.scale = SPRITE_SCALE
	_stagger_left = stagger_duration if duration < 0.0 else duration
	_poise = 0.0
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_flash(Color(1.4, 1.3, 0.9))
	_play_visual("stagger", true)
	staggered.emit(_stagger_left)


func end_stagger_early() -> void:
	if _phase == Phase.Stagger:
		_end_stagger()


func kneel() -> void:
	_active = false
	_hide_tell()
	_clear_adds()
	if _smoke != null:
		_smoke.emitting = false
	_play_visual("stagger", true)


func dissolve_into_light() -> void:
	_active = false
	_dead = true
	_hide_tell()
	_clear_adds()
	if _smoke != null:
		_smoke.emitting = false
	_play_visual("death", true)
	Fx.fiber_burst(self, Palette.GOLD_SUN)
	var home := scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.6, 1.5, 1.1, 0.0), 1.35)
	tween.tween_property(self, "scale", Vector2(home.x * 1.7, home.y * 0.18), 1.35)


func _die() -> void:
	_dead = true
	_active = false
	_phase = Phase.Dead
	remove_from_group("hittable")
	_hide_tell()
	_clear_adds()
	_play_visual("death", true)
	_sync_hp_bar()
	_clear_blind()
	defeated.emit()


func _end_stagger() -> void:
	_phase = Phase.Approach
	_stagger_left = 0.0
	_timer = 0.55
	_play_visual("idle", true)
	recovered.emit()


func _enter_approach(delay: float) -> void:
	_phase = Phase.Approach
	_skill = Skill.None
	_timer = delay
	_lunge_vel = Vector2.ZERO
	_hide_tell()
	if _pose_tween != null:
		_pose_tween.kill()
	if _sprite != null:
		_sprite.scale = SPRITE_SCALE
		_sprite.modulate = Color.WHITE
	_play_visual("idle")


func _try_start_skill() -> void:
	var player := _player()
	if player == null:
		_timer = 0.2
		return
	_face_player()
	var dist := Iso.iso_distance(global_position, player.global_position)
	var next := _pick_skill(dist)
	if next == Skill.None:
		_timer = 0.16
		return
	_start_skill(next)


func _pick_skill(dist: float) -> Skill:
	_prune_adds()
	var late := health_ratio() <= 0.35
	var mid := health_ratio() <= 0.65
	var options: Array[Skill] = []
	if dist <= 128.0:
		options.append(Skill.Claw)
		options.append(Skill.Claw)
		if _ready_cd(Skill.Lunge):
			options.append(Skill.Lunge)
		if mid and _ready_cd(Skill.Slam):
			options.append(Skill.Slam)
	elif dist <= 250.0:
		if _ready_cd(Skill.Lunge):
			options.append(Skill.Lunge)
		if _ready_cd(Skill.Volley):
			options.append(Skill.Volley)
		if mid and _ready_cd(Skill.Slam):
			options.append(Skill.Slam)
		options.append(Skill.Claw)
	else:
		if _ready_cd(Skill.Dash):
			options.append(Skill.Dash)
		if _ready_cd(Skill.Volley):
			options.append(Skill.Volley)
		if _ready_cd(Skill.Lunge):
			options.append(Skill.Lunge)
	if (mid or dist > 90.0) and _ready_cd(Skill.Blind) and dist < 320.0:
		options.append(Skill.Blind)
		if late:
			options.append(Skill.Blind)
	if late and _ready_cd(Skill.Nova) and dist < 280.0:
		options.append(Skill.Nova)
		options.append(Skill.Nova)
	if (mid or late) and _ready_cd(Skill.Summon) and _adds.size() < 2:
		options.append(Skill.Summon)
	if options.is_empty():
		return Skill.Claw if dist < 130.0 else Skill.None
	return options[randi() % options.size()]


func _ready_cd(skill: Skill) -> bool:
	return float(_cds.get(skill, 0.0)) <= 0.0


func _start_skill(skill: Skill) -> void:
	var plan := _plan(skill)
	_skill = skill
	_heavy = bool(plan["heavy"])
	_windup = float(plan["windup"])
	_active_len = float(plan["active"])
	_recover_len = float(plan["recover"])
	_cds[skill] = float(plan["cd"])
	_phase = Phase.Windup
	_phase_t = 0.0
	_hits_landed = 0
	_volleys_shot = 0
	_lunge_vel = Vector2.ZERO
	_face_player()
	var player := _player()
	_strike_at = player.global_position if player != null else global_position + _aim * 90.0
	_show_tell()
	_nova_flashed = false
	_ghost_cd = 0.0
	_arm_skill_anim(String(plan["anim"]))
	Audio.play_wind_whistle()
	telegraph_started.emit(_windup)


func _plan(skill: Skill) -> Dictionary:
	var haste := 0.76 if health_ratio() <= 0.35 else (0.88 if health_ratio() <= 0.65 else 1.0)
	match skill:
		Skill.Lunge:
			return {windup = 0.52 * haste, active = 0.30, recover = 0.62 * haste, cd = 3.1, anim = "lunge", heavy = true}
		Skill.Slam:
			return {windup = 0.72 * haste, active = 0.42, recover = 0.82 * haste, cd = 6.6, anim = "slam", heavy = true}
		Skill.Volley:
			return {windup = 0.48 * haste, active = 0.62, recover = 0.42 * haste, cd = 4.6, anim = "cast", heavy = false}
		Skill.Dash:
			return {windup = 0.26 * haste, active = 0.28, recover = 0.34 * haste, cd = 5.0, anim = "dash", heavy = false}
		Skill.Nova:
			return {windup = 0.95 * haste, active = 0.70, recover = 0.95 * haste, cd = 14.0, anim = "nova", heavy = true}
		Skill.Summon:
			return {windup = 0.66 * haste, active = 0.30, recover = 0.48 * haste, cd = 13.0, anim = "summon", heavy = false}
		Skill.Blind:
			return {windup = 0.86 * haste, active = 0.34, recover = 0.62 * haste, cd = 11.5, anim = "blind", heavy = true}
		_:
			return {windup = 0.46 * haste, active = 0.46, recover = 0.40 * haste, cd = 0.35, anim = "claw", heavy = false}


func _enter_active() -> void:
	_phase = Phase.Active
	_phase_t = 0.0
	match _skill:
		Skill.Lunge:
			var to := _strike_at - global_position
			_lunge_vel = (to.normalized() if to.length() > 4.0 else _aim) * 620.0
		Skill.Dash:
			_begin_dash()
		Skill.Blind:
			_cast_blind()
		Skill.Slam:
			_spawn_slam_ring()
		Skill.Nova:
			_spawn_nova_ring()
		Skill.Summon:
			_spawn_adds()
			Fx.pool_rise(self)
			Fx.ring_pulse(self, _skill_color(), 90.0)
		_:
			pass
	if _skill != Skill.Claw and _skill != Skill.Volley:
		_strike_flourish()
	_hide_tell()


func _tick_active(delta: float) -> void:
	if (_skill == Skill.Lunge or _skill == Skill.Dash) and _lunge_vel != Vector2.ZERO:
		velocity = _lunge_vel
		if _skill == Skill.Dash:
			var remain := _dash_dest - global_position
			if remain.length() < 16.0 or remain.dot(_lunge_vel) <= 0.0:
				_lunge_vel = Vector2.ZERO
				velocity = Vector2.ZERO
	match _skill:
		Skill.Claw:
			if _hits_landed == 0 and _phase_t >= 0.08:
				_claw_hit(0)
			if _hits_landed == 1 and _phase_t >= 0.26:
				_claw_hit(1)
		Skill.Lunge:
			_ghost_cd -= delta
			if _ghost_cd <= 0.0:
				_ghost_cd = 0.05
				_drop_motion_ghost(0.42)
			if _hits_landed == 0 and _phase_t >= 0.08:
				_body_hit(124.0, 30.0, 1.2)
		Skill.Dash:
			_ghost_cd -= delta
			if _ghost_cd <= 0.0:
				_ghost_cd = 0.06
				_drop_motion_ghost(0.35)
		Skill.Slam:
			if _hits_landed == 0 and _phase_t >= 0.08:
				_body_hit(150.0, 30.0, 1.25)
		Skill.Volley:
			_tick_volley()
		Skill.Nova:
			if _hits_landed == 0 and _phase_t >= 0.12:
				_body_hit(96.0, 24.0, 1.1)
		_:
			pass


func _enter_recover() -> void:
	_phase = Phase.Recover
	_phase_t = 0.0
	_lunge_vel = Vector2.ZERO
	telegraph_resolved.emit(false)


func _claw_hit(index: int) -> void:
	_hits_landed = index + 1
	_spawn_slash_vfx(index == 1)
	if index == 0:
		_body_hit(132.0, 24.0, 0.9)
	else:
		_body_hit(148.0, 30.0, 1.2)
	_strike_flourish()
	Audio.play_sfx(Audio.Sfx.THUD)


func _tick_volley() -> void:
	var stamps := [0.06, 0.24, 0.42]
	while _volleys_shot < stamps.size() and _phase_t >= float(stamps[_volleys_shot]):
		_spawn_bolt(_volleys_shot)
		_volleys_shot += 1


func _body_hit(reach: float, damage: float, knock: float) -> void:
	_hits_landed = maxi(_hits_landed, 1)
	var player := _player()
	if player == null:
		return
	var dist := Iso.iso_distance(global_position, player.global_position)
	if dist > reach:
		return
	var to_player := (player.global_position - global_position)
	if to_player.length() > 4.0 and _aim.dot(to_player.normalized()) < -0.42 and _skill == Skill.Claw:
		return
	player.take_damage(damage, self)
	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position, 260.0 * knock)
	Fx.hit_flash(player, Color(0.62, 0.22, 0.78))


func _begin_dash() -> void:
	var player := _player()
	var origin := global_position
	var dest := global_position + _aim * 160.0
	if player != null:
		var side := Vector2(-_aim.y, _aim.x)
		if randf() < 0.5:
			side = -side
		dest = player.global_position + side.normalized() * 78.0 + _aim * -36.0
	dest = _slide_limit(origin, _clamp_point(dest))
	_dash_dest = dest
	var travel := dest - origin
	_lunge_vel = travel.normalized() * 860.0 if travel.length() > 8.0 else Vector2.ZERO
	_lay_dash_ghosts(origin, dest)
	Audio.play_sfx(Audio.Sfx.HIT)


func _player() -> Slang:
	var node := get_tree().get_first_node_in_group("player")
	return node as Slang if node is Slang else null


func _chase_player(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	_face_player()
	var to_player := player.global_position - global_position
	var dist := Iso.iso_distance(global_position, player.global_position)
	var speed := chase_speed
	if health_ratio() <= 0.35:
		speed *= 1.28
	elif health_ratio() <= 0.65:
		speed *= 1.12
	if dist > keep_range + 16.0:
		velocity = to_player.normalized() * speed
		_play_visual("walk")
	elif dist < keep_range * 0.45:
		velocity = -to_player.normalized() * speed * 0.55
		_play_visual("walk")
	else:
		_play_visual("idle")


func _face_player() -> void:
	var player := _player()
	if player == null:
		return
	_aim = player.global_position - global_position
	if _aim.length() < 2.0:
		_aim = Vector2(0, 1)
	else:
		_aim = _aim.normalized()
	if _sprite != null:
		_sprite.flip_h = player.global_position.x < global_position.x


func _slide_limit(from: Vector2, to: Vector2) -> Vector2:
	var world := get_world_2d()
	if world == null:
		return to
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.LAYER_WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var dir := to - from
	if dir.length() < 1.0:
		return from
	return (hit.position as Vector2) - dir.normalized() * 22.0


func _clamp_point(point: Vector2) -> Vector2:
	var offset := point - _home
	if offset.length() <= _arena_radius:
		return point
	return _home + offset.normalized() * _arena_radius


func _clamp_arena() -> void:
	var clamped := _clamp_point(global_position)
	if clamped.distance_squared_to(global_position) > 1.0:
		global_position = clamped


func _spawn_adds() -> void:
	_prune_adds()
	var needed := 2 - _adds.size()
	if needed <= 0:
		return
	var host := get_parent()
	if host == null:
		host = self
	var offsets := [Vector2(-78.0, 30.0), Vector2(78.0, 30.0)]
	for i in range(needed):
		var minion := ShadowMinion.new()
		minion.max_health = 34.0
		minion.touch_damage = 11.0
		minion.speed = 124.0
		minion.combat_style = "dasher" if i == 0 else "chaser"
		minion.spawn_delay = 0.18
		minion.set_meta("boss_add", true)
		host.add_child(minion)
		minion.global_position = global_position + offsets[i]
		minion.scale = Vector2(1.12, 1.12)
		minion.z_index = 6
		_adds.append(minion)
	Audio.play_sfx(Audio.Sfx.THUD)
	Fx.punch(self, 0.12)


func _prune_adds() -> void:
	var kept: Array[Node] = []
	for node in _adds:
		if node != null and is_instance_valid(node) and node.is_inside_tree():
			if node is ShadowMinion and (node as ShadowMinion).health <= 0.0:
				continue
			kept.append(node)
	_adds = kept


func _clear_adds() -> void:
	for node in _adds:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_adds.clear()


func _spawn_slash_vfx(flip: bool) -> void:
	var frames: SpriteFrames = _vfx_frames.get("slash", null)
	if frames == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.centered = true
	fx.position = _aim * 54.0 + Vector2(0.0, -48.0)
	fx.rotation = _aim.angle()
	fx.flip_v = flip
	fx.scale = Vector2(1.45, 1.35)
	fx.z_index = 12
	add_child(fx)
	fx.play("play")
	fx.animation_finished.connect(fx.queue_free)


func _spawn_bolt(index: int) -> void:
	var player := _player()
	if player == null:
		return
	var host := get_parent()
	if host == null:
		host = self
	var bolt := _SkillBolt.new()
	bolt.target = player
	bolt.source = self
	bolt.damage = 16.0
	bolt.frames = _vfx_frames.get("bolt", null)
	var spread := (float(index) - 1.0) * 0.22
	bolt.direction = _aim.rotated(spread)
	host.add_child(bolt)
	bolt.global_position = global_position + Vector2(0.0, -70.0) + _aim * 28.0
	Audio.play_sfx(Audio.Sfx.HIT)


func _spawn_slam_ring() -> void:
	_spawn_ring(_vfx_frames.get("slam", null), 16.0, 240.0, 320.0, 34.0, 26.0, 1.35)


func _spawn_nova_ring() -> void:
	_spawn_ring(_vfx_frames.get("nova", null), 22.0, 210.0, 390.0, 32.0, 28.0, 1.55)
	Audio.play_sfx(Audio.Sfx.FAIL)
	Fx.punch(self, 0.2)


func _spawn_ring(frames: SpriteFrames, start_r: float, grow: float, max_r: float, band: float, damage: float, life: float) -> void:
	var host := get_parent()
	if host == null:
		host = self
	var ring := _ExpandingRing.new()
	ring.frames = frames
	ring.radius = start_r
	ring.grow = grow
	ring.max_r = max_r
	ring.band = band
	ring.damage = damage
	ring.life = life
	ring.source = self
	host.add_child(ring)
	ring.global_position = global_position


func _show_tell() -> void:
	if _tell == null:
		return
	_tell.visible = true
	_tell.scale = Vector2.ONE
	var pts := _danger_points()
	if _danger != null:
		_danger.polygon = pts
		_danger.color = Color(0.92, 0.14, 0.16, 0.34)
	var rim := _tell.get_node_or_null("Rim") as Line2D
	if rim != null:
		rim.points = pts


func _hide_tell() -> void:
	if _tell != null:
		_tell.visible = false


func _danger_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	match _skill:
		Skill.Nova:
			for i in range(24):
				var a := TAU * float(i) / 24.0
				pts.append(Vector2(cos(a) * 190.0, sin(a) * 104.0))
		Skill.Slam:
			for i in range(20):
				var a := TAU * float(i) / 20.0
				pts.append(Vector2(cos(a) * 132.0, sin(a) * 72.0))
		Skill.Summon:
			for i in range(16):
				var a := TAU * float(i) / 16.0
				pts.append(Vector2(cos(a) * 74.0, sin(a) * 38.0 + 16.0))
		Skill.Blind:
			for i in range(24):
				var a := TAU * float(i) / 24.0
				pts.append(Vector2(cos(a) * 176.0, sin(a) * 96.0))
		Skill.Volley:
			pts.append(-_aim * 10.0)
			pts.append(_aim.rotated(-0.55) * 210.0)
			pts.append(_aim.rotated(0.55) * 210.0)
		Skill.Lunge, Skill.Dash:
			pts.append(-_aim * 8.0 + _aim.rotated(-0.28) * 36.0)
			pts.append(_aim * 168.0)
			pts.append(-_aim * 8.0 + _aim.rotated(0.28) * 36.0)
		_:
			pts.append(-_aim * 8.0)
			pts.append(_aim.rotated(-0.72) * 118.0)
			pts.append(_aim.rotated(0.72) * 118.0)
	return pts


func _update_tell(progress: float) -> void:
	if _tell == null:
		return
	var pulse := 0.92 + progress * 0.2
	_tell.scale = Vector2(pulse, pulse)
	if _danger != null:
		_danger.color = Color(0.94, 0.10, 0.12, 0.26 + progress * 0.34)
	var rim := _tell.get_node_or_null("Rim") as Line2D
	if rim != null:
		var hot := Color(1.0, 0.22 + progress * 0.2, 0.16, 1.0).lerp(_skill_color(), 0.42)
		rim.default_color = Color(hot.r, hot.g, hot.b, 0.78 + progress * 0.22)
		rim.width = 3.0 + progress * 3.4


func _flash(tint: Color) -> void:
	if _art == null and _sprite == null:
		return
	if _art != null:
		_art.set_tint(tint)
	if _sprite != null:
		_sprite.modulate = tint
	_flash_left = 0.12
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_art):
			_art.set_tint(Color.WHITE)
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
	)


func _play_visual(anim: StringName, force := false) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if not force and _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)


func _on_visual_finished() -> void:
	if _sprite == null or _dead:
		return
	var anim := _sprite.animation
	if _sprite.sprite_frames.get_animation_loop(anim):
		return
	# Hold the last pose through the hit and the punish window.
	if _phase == Phase.Recover or _phase == Phase.Windup or _phase == Phase.Active or _phase == Phase.Dead:
		_sprite.pause()
		return
	_sprite.play(&"idle")


func _arm_skill_anim(anim: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.animation = anim
	_sprite.pause()
	_sprite.frame = 0
	_sprite.scale = SPRITE_SCALE


func _drive_skill_pose() -> void:
	if _sprite == null or _skill == Skill.None:
		return
	if not _sprite.sprite_frames.has_animation(_sprite.animation):
		return
	var count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if count < 2:
		return
	var cut := mini(STRIKE_SPLIT, count - 1)
	var frame := 0
	match _phase:
		Phase.Windup:
			var t := clampf(_phase_t / maxf(_windup, 0.05), 0.0, 0.999)
			frame = int(t * float(cut))
		Phase.Active:
			var t := clampf(_phase_t / maxf(_active_len, 0.05), 0.0, 0.999)
			frame = cut + int(t * float(count - cut))
		Phase.Recover:
			frame = count - 1
		_:
			return
	if _sprite.is_playing():
		_sprite.pause()
	_sprite.frame = clampi(frame, 0, count - 1)
	_paint_skill_glow()


func _paint_skill_glow() -> void:
	if _sprite == null or _flash_left > 0.0:
		return
	var ink := _skill_color()
	match _phase:
		Phase.Windup:
			var t := clampf(_phase_t / maxf(_windup, 0.05), 0.0, 1.0)
			var pulse := 0.65 + 0.35 * sin(_phase_t * 16.0)
			_sprite.modulate = Color.WHITE.lerp(ink, (0.12 + t * 0.5) * pulse)
		Phase.Active:
			var t := clampf(_phase_t / maxf(_active_len, 0.05), 0.0, 1.0)
			_sprite.modulate = Color.WHITE.lerp(ink, (1.0 - t) * 0.28)
		_:
			_sprite.modulate = Color.WHITE


func _skill_color() -> Color:
	match _skill:
		Skill.Lunge:
			return Color(0.92, 0.28, 0.62)
		Skill.Slam:
			return Color(0.78, 0.18, 1.0)
		Skill.Volley:
			return Color(0.72, 0.38, 1.0)
		Skill.Dash:
			return Color(0.58, 0.28, 0.98)
		Skill.Nova:
			return Color(1.0, 0.72, 0.38)
		Skill.Summon:
			return Color(0.48, 0.14, 0.78)
		Skill.Blind:
			return Color(0.86, 0.9, 1.0)
		_:
			return Color(0.74, 0.22, 0.98)


func _strike_flourish() -> void:
	if _sprite != null:
		if _pose_tween != null:
			_pose_tween.kill()
		_sprite.scale = Vector2(SPRITE_SCALE.x * 1.14, SPRITE_SCALE.y * 0.84)
		_pose_tween = create_tween()
		_pose_tween.tween_property(_sprite, "scale", SPRITE_SCALE, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.light_burst(self, _skill_color())
	Fx.fiber_burst(self, _skill_color())


func _drop_motion_ghost(alpha: float) -> void:
	var host := get_parent()
	if host == null or _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.frame < 0 or _sprite.frame >= _sprite.sprite_frames.get_frame_count(_sprite.animation):
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	ghost.centered = true
	ghost.scale = _sprite.scale
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(_skill_color().lerp(Color.WHITE, 0.25), alpha)
	ghost.z_index = z_index - 1
	host.add_child(ghost)
	ghost.global_position = _sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


func _lay_dash_ghosts(from: Vector2, to: Vector2) -> void:
	var host := get_parent()
	if host == null or _sprite == null or _sprite.sprite_frames == null:
		return
	var count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, mini(5, count - 1))
	var foot := _sprite.global_position - global_position
	for i in range(5):
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.centered = true
		ghost.scale = _sprite.scale * (1.0 - float(i) * 0.05)
		ghost.flip_h = from.x > to.x
		ghost.modulate = Color(_skill_color().lerp(Color.WHITE, 0.3), 0.7 - float(i) * 0.1)
		ghost.z_index = z_index - 1
		host.add_child(ghost)
		ghost.global_position = from.lerp(to, float(i) / 4.0) + foot
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.16 + float(i) * 0.05)
		tween.tween_callback(ghost.queue_free)


func _ensure_feet() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	shape_node.shape = PhysicsLayers.feet_circle(16.0)
	shape_node.position = Vector2(0.0, -2.0)
	shape_node.disabled = false
	collision_layer = PhysicsLayers.LAYER_ENEMIES
	collision_mask = PhysicsLayers.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08
	slide_on_ceiling = true
	floor_stop_on_slope = false


func _sync_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	var show := _active and not _dead and health > 0.0
	_hp_bar.visible = show
	if _hp_label != null:
		_hp_label.visible = show
		_hp_label.text = "SHADOW WEAVER  %d" % roundi(health)


func _cast_blind() -> void:
	_body_hit(172.0, 18.0, 1.3)
	Fx.light_burst(self, Color(0.94, 0.96, 1.0))
	Fx.ring_pulse(self, Color(0.8, 0.86, 1.0), 180.0)
	Audio.play_sfx(Audio.Sfx.CHIME)
	_clear_blind()
	var veil := BlindVeil.new()
	veil.name = "BossBlindVeil"
	veil.setup(3.15)
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(veil)
	_veil = veil


func _clear_blind() -> void:
	if _veil != null and is_instance_valid(_veil):
		_veil.queue_free()
	_veil = null


func _build_visuals() -> void:
	var boss_frames := _build_sprite_frames()
	if boss_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "ShadowWeaverArt"
		_sprite.sprite_frames = boss_frames
		_sprite.centered = true
		_sprite.position = Vector2(0.0, -(float(BODY_SIZE.y) * 0.5 - 8.0))
		_sprite.scale = SPRITE_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_sprite.animation_finished.connect(_on_visual_finished)
		add_child(_sprite)
		_sprite.play("idle")
	else:
		_art = PlaceholderProp.new()
		_art.name = "Art"
		_art.prop_label = "SHADOW WEAVER BOSS"
		_art.prop_size = Vector2(156.0, 236.0)
		_art.body_color = Color(0.12, 0.11, 0.15)
		_art.accent_color = Color(0.42, 0.3, 0.42)
		_art.float_amplitude = 6.0
		_art.float_speed = 1.1
		_art.blocks_movement = false
		add_child(_art)

	_vfx_frames["slash"] = _strip_frames(VFX_SLASH, 14.0, false)
	_vfx_frames["slam"] = _strip_frames(VFX_SLAM, 10.0, false)
	_vfx_frames["bolt"] = _strip_frames(VFX_BOLT, 12.0, true)
	_vfx_frames["nova"] = _strip_frames(VFX_NOVA, 9.0, false)

	_smoke = GPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 28
	_smoke.lifetime = 1.6
	_smoke.preprocess = 0.4
	_smoke.emitting = false
	_smoke.position = Vector2(0.0, -70.0)
	_smoke.z_index = -1
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_mat.emission_sphere_radius = 22.0
	smoke_mat.direction = Vector3(0.0, -1.0, 0.0)
	smoke_mat.spread = 80.0
	smoke_mat.initial_velocity_min = 8.0
	smoke_mat.initial_velocity_max = 28.0
	smoke_mat.gravity = Vector3(0.0, -12.0, 0.0)
	smoke_mat.scale_min = 0.5
	smoke_mat.scale_max = 1.4
	smoke_mat.color = Color(0.12, 0.1, 0.14, 0.55)
	_smoke.process_material = smoke_mat
	add_child(_smoke)

	var contact := Polygon2D.new()
	contact.name = "ContactShadow"
	var shadow_pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		shadow_pts.append(Vector2(cos(a) * 52.0, sin(a) * 16.0))
	contact.polygon = shadow_pts
	contact.color = Color(0.02, 0.01, 0.03, 0.42)
	contact.position = Vector2(0.0, 8.0)
	contact.z_index = -3
	add_child(contact)
	move_child(contact, 0)

	_select_ring = Polygon2D.new()
	_select_ring.polygon = Iso.diamond(Vector2(0.0, 10.0), 2.6)
	_select_ring.color = Palette.alpha(Palette.GOLD_SUN, 0.5)
	_select_ring.z_index = -2
	_select_ring.visible = false
	add_child(_select_ring)
	move_child(_select_ring, 0)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "BossHp"
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(168.0, 12.0)
	_hp_bar.size = Vector2(168.0, 12.0)
	_hp_bar.position = Vector2(-84.0, -368.0)
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.visible = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.z_index = 40
	_hp_bar.add_theme_stylebox_override("background", UiStyle.bar_track(6))
	_hp_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Color(0.62, 0.16, 0.72), 6))
	add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.name = "BossHpLabel"
	_hp_label.text = "SHADOW WEAVER"
	_hp_label.position = Vector2(-84.0, -390.0)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.z_index = 40
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.96))
	_hp_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	_hp_label.add_theme_constant_override("outline_size", 4)
	add_child(_hp_label)
	_hp_label.visible = false

	_tell = Node2D.new()
	_tell.name = "Telegraph"
	_tell.visible = false
	_tell.z_index = -1
	add_child(_tell)
	_danger = Polygon2D.new()
	_danger.name = "Danger"
	_danger.color = Color(0.92, 0.16, 0.18, 0.38)
	_tell.add_child(_danger)
	var rim := Line2D.new()
	rim.name = "Rim"
	rim.width = 4.0
	rim.default_color = Color(1.0, 0.28, 0.22, 0.95)
	rim.closed = true
	rim.antialiased = true
	_tell.add_child(rim)


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var specs: Array = [
		[&"idle", SHEET_IDLE, 5.5, true],
		[&"walk", SHEET_WALK, 8.0, true],
		[&"claw", SHEET_CLAW, 10.0, false],
		[&"lunge", SHEET_LUNGE, 12.0, false],
		[&"slam", SHEET_SLAM, 9.0, false],
		[&"cast", SHEET_CAST, 8.0, false],
		[&"dash", SHEET_DASH, 14.0, false],
		[&"nova", SHEET_NOVA, 8.0, false],
		[&"summon", SHEET_SUMMON, 8.0, false],
		[&"stagger", SHEET_STAGGER, 7.0, true],
		[&"death", SHEET_DEATH, 6.0, false],
		[&"blind", SHEET_BLIND, 9.0, false],
	]
	for spec in specs:
		_add_sheet_anim(frames, spec[0], spec[1], float(spec[2]), bool(spec[3]))
	if not frames.has_animation(&"dash") and frames.has_animation(&"lunge"):
		_add_sheet_anim(frames, &"dash", SHEET_LUNGE, 14.0, false)
	if not frames.has_animation(&"blind") and frames.has_animation(&"nova"):
		_add_sheet_anim(frames, &"blind", SHEET_NOVA, 9.0, false)
	if frames.has_animation(&"idle") and frames.has_animation(&"claw") and frames.has_animation(&"slam"):
		return frames
	push_warning("ShadowWeaverBoss: skill sheets missing, using combined sheet")
	return _frames_from_original_sheet()


func _frames_from_original_sheet() -> SpriteFrames:
	var image := _load_image(ORIGINAL_SHEET)
	if image == null:
		return null
	_key_black_plate(image)
	var cols := SHEET_COLS
	var rows := SHEET_ROWS
	var cell_w := int(image.get_width() / cols)
	var cell_h := int(image.get_height() / rows)
	if cell_w < 8 or cell_h < 8:
		return null
	var textures: Array[Texture2D] = []
	for i in range(cols * rows):
		var cell := image.get_region(Rect2i(
			(i % cols) * cell_w,
			int(i / cols) * cell_h,
			cell_w,
			cell_h
		))
		textures.append(_fit_body_frame(cell))
	if textures.size() < 12:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_visual_anim(frames, &"idle", [textures[0], textures[1], textures[11], textures[1]], 3.8, true)
	_add_visual_anim(frames, &"walk", [textures[2], textures[1], textures[2], textures[0]], 6.5, true)
	_add_visual_anim(frames, &"claw", [textures[3], textures[4], textures[4]], 11.0, false)
	_add_visual_anim(frames, &"lunge", [textures[2], textures[4], textures[4]], 12.0, false)
	_add_visual_anim(frames, &"slam", [textures[7], textures[8], textures[8]], 9.0, false)
	_add_visual_anim(frames, &"cast", [textures[5], textures[5]], 8.0, false)
	_add_visual_anim(frames, &"summon", [textures[6], textures[6]], 8.0, false)
	_add_visual_anim(frames, &"nova", [textures[7], textures[8], textures[8]], 8.0, false)
	_add_visual_anim(frames, &"stagger", [textures[9]], 1.0, true)
	_add_visual_anim(frames, &"death", [textures[9], textures[10]], 5.0, false)
	return frames


func _key_black_plate(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var pending: Array[Vector2i] = []
	for x in range(w):
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, h - 1))
	for y in range(h):
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(w - 1, y))
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= w or point.y >= h:
			continue
		var index: int = point.y * w + point.x
		if seen[index] == 1:
			continue
		seen[index] = 1
		var color := image.get_pixelv(point)
		if not _is_black_plate(color):
			continue
		image.set_pixelv(point, Color.TRANSPARENT)
		pending.append(point + Vector2i.RIGHT)
		pending.append(point + Vector2i.LEFT)
		pending.append(point + Vector2i.DOWN)
		pending.append(point + Vector2i.UP)


func _is_black_plate(color: Color) -> bool:
	if color.a < 0.08:
		return true
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var chroma := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
	return luma < 0.09 and chroma < 0.07


func _add_sheet_anim(frames: SpriteFrames, anim: StringName, path: String, fps: float, loop: bool) -> bool:
	var textures := _slice_strip(path, true)
	if textures.is_empty():
		return false
	_add_visual_anim(frames, anim, textures, fps, loop)
	return true


func _strip_frames(path: String, fps: float, loop: bool) -> SpriteFrames:
	var textures := _slice_strip(path, false)
	if textures.is_empty():
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_visual_anim(frames, &"play", textures, fps, loop)
	return frames


func _add_visual_anim(frames: SpriteFrames, anim: StringName, textures: Array, fps: float, loop: bool) -> void:
	if frames.has_animation(anim):
		frames.remove_animation(anim)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for texture in textures:
		frames.add_frame(anim, texture as Texture2D)


func _first_tex(frames: SpriteFrames, anim: StringName) -> Texture2D:
	if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
		return frames.get_frame_texture(anim, 0)
	return null


func _slice_strip(path: String, fit_body: bool) -> Array[Texture2D]:
	var image := _load_image(path)
	if image == null:
		return []
	_key_plate(image)
	var cells := _cut_cells(image, FRAME_GUTTER if fit_body else 0)
	if not fit_body:
		return _pack_vfx_frames(cells)
	return _pack_body_frames(cells)


func _cut_cells(image: Image, gutter: int) -> Array[Image]:
	var fw := maxi(1, int(image.get_width() / float(STRIP_FRAMES)))
	var fh := image.get_height()
	var cell_w := fw + gutter * 2
	var cells: Array[Image] = []
	for i in range(STRIP_FRAMES):
		var cell := Image.create(cell_w, fh, false, Image.FORMAT_RGBA8)
		cell.fill(Color.TRANSPARENT)
		var src_x := i * fw - gutter
		var copy_x := maxi(0, src_x)
		var dest_x := copy_x - src_x
		var copy_w := mini(image.get_width(), src_x + cell_w) - copy_x
		if copy_w > 0:
			cell.blit_rect(image, Rect2i(copy_x, 0, copy_w, fh), Vector2i(dest_x, 0))
		cells.append(cell)
	return cells


func _pack_body_frames(cells: Array[Image]) -> Array[Texture2D]:
	var rects: Array[Rect2i] = []
	var heights: Array[int] = []
	var max_w := 1
	var tallest := 1
	for cell in cells:
		var used := cell.get_used_rect()
		rects.append(used)
		tallest = maxi(tallest, used.size.y)
		if used.size.x > 8 and used.size.y > 8:
			heights.append(used.size.y)
			max_w = maxi(max_w, used.size.x)
	var median := 1
	if not heights.is_empty():
		heights.sort()
		median = heights[heights.size() / 2]
	# Same on-screen body height for every move. Extra canvas is headroom for bursts.
	var scale_factor := float(BODY_DRAW_H) / float(maxi(median, 1))
	scale_factor = minf(scale_factor, float(BODY_SIZE.x - 24) / float(maxi(max_w, 1)))
	if float(tallest) * scale_factor > float(BODY_SIZE.y - 16):
		scale_factor = float(BODY_SIZE.y - 16) / float(tallest)
	var textures: Array[Texture2D] = []
	for i in range(cells.size()):
		textures.append(_blit_scaled_cell(cells[i], rects[i], scale_factor))
	return textures


func _pack_vfx_frames(cells: Array[Image]) -> Array[Texture2D]:
	var rects: Array[Rect2i] = []
	var side := 32
	for cell in cells:
		var used := cell.get_used_rect()
		rects.append(used)
		if used.size.x > 2 and used.size.y > 2:
			side = maxi(side, maxi(used.size.x, used.size.y))
	side = mini(side + 8, 280)
	var textures: Array[Texture2D] = []
	for i in range(cells.size()):
		var canvas := Image.create(side, side, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var used: Rect2i = rects[i]
		if used.size.x > 0 and used.size.y > 0:
			var crop := cells[i].get_region(used)
			var origin := Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2)
			canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), origin)
		textures.append(ImageTexture.create_from_image(canvas))
	return textures


func _blit_scaled_cell(cell: Image, used: Rect2i, scale_factor: float) -> Texture2D:
	var canvas := Image.create(BODY_SIZE.x, BODY_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	if used.size.x < 1 or used.size.y < 1:
		return ImageTexture.create_from_image(canvas)
	var scaled := cell.duplicate()
	var tw := maxi(1, int(round(float(cell.get_width()) * scale_factor)))
	var th := maxi(1, int(round(float(cell.get_height()) * scale_factor)))
	scaled.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var foot := int(round(float(used.position.y + used.size.y) * scale_factor))
	var cell_cx := int(round(float(cell.get_width()) * 0.5 * scale_factor))
	var origin := Vector2i(int(BODY_SIZE.x / 2.0) - cell_cx, BODY_SIZE.y - 8 - foot)
	var src_rect := Rect2i(Vector2i.ZERO, scaled.get_size())
	if origin.x < 0:
		src_rect.position.x = -origin.x
		src_rect.size.x += origin.x
		origin.x = 0
	if origin.y < 0:
		src_rect.position.y = -origin.y
		src_rect.size.y += origin.y
		origin.y = 0
	if origin.x + src_rect.size.x > BODY_SIZE.x:
		src_rect.size.x = BODY_SIZE.x - origin.x
	if origin.y + src_rect.size.y > BODY_SIZE.y:
		src_rect.size.y = BODY_SIZE.y - origin.y
	if src_rect.size.x > 0 and src_rect.size.y > 0:
		canvas.blit_rect(scaled, src_rect, origin)
	return ImageTexture.create_from_image(canvas)


func _load_image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			var tex := (loaded as Texture2D).get_image()
			if tex != null:
				if tex.get_format() != Image.FORMAT_RGBA8:
					tex.convert(Image.FORMAT_RGBA8)
				return tex
	var image := Image.new()
	var disk := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if FileAccess.file_exists(disk) and image.load(disk) == OK:
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		return image
	return null


func _key_plate(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	# Sheets are stored with the plate already removed. Skip the pixel walk then.
	if image.get_pixel(0, 0).a < 0.08 and image.get_pixel(w - 1, h - 1).a < 0.08:
		return
	for y in range(h):
		for x in range(w):
			if _is_plate(image.get_pixel(x, y)):
				image.set_pixel(x, y, Color.TRANSPARENT)


func _is_plate(color: Color) -> bool:
	if color.a < 0.08:
		return true
	# Green screen on the slash strip.
	if color.g > 0.72 and color.r < 0.35 and color.b < 0.35:
		return true
	# Magenta plate on the skill strips. The violet glow keeps some green, so it stays.
	if color.g < 0.10 and color.r > 0.38 and color.b > 0.22 and color.r > color.g * 4.0:
		return true
	return false


func _fit_body_frame(source: Image) -> Texture2D:
	var used := source.get_used_rect()
	var canvas := Image.create(BODY_SIZE.x, BODY_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	if used.size.x < 1 or used.size.y < 1:
		return ImageTexture.create_from_image(canvas)
	var crop := source.get_region(used)
	var available := BODY_SIZE - Vector2i(20, 18)
	var scale_factor := minf(
		float(available.x) / float(crop.get_width()),
		float(available.y) / float(crop.get_height())
	)
	var target := Vector2i(
		maxi(1, int(round(crop.get_width() * scale_factor))),
		maxi(1, int(round(crop.get_height() * scale_factor)))
	)
	crop.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var origin := Vector2i((BODY_SIZE.x - target.x) / 2, BODY_SIZE.y - 10 - target.y)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, target), origin)
	return ImageTexture.create_from_image(canvas)


func _fit_vfx_frame(source: Image) -> Texture2D:
	var used := source.get_used_rect()
	if used.size.x < 1 or used.size.y < 1:
		return ImageTexture.create_from_image(source)
	var crop := source.get_region(used)
	var side := maxi(crop.get_width(), crop.get_height())
	var canvas := Image.create(side, side, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var origin := Vector2i((side - crop.get_width()) / 2, (side - crop.get_height()) / 2)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), origin)
	return ImageTexture.create_from_image(canvas)


class _SkillBolt extends Node2D:
	var source: Node2D
	var target: Node2D
	var damage := 16.0
	var speed := 360.0
	var direction := Vector2.RIGHT
	var frames: SpriteFrames
	var _spent := false
	var _travel := 0.0

	func _ready() -> void:
		z_index = 20
		if frames != null:
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = frames
			spr.centered = true
			spr.scale = Vector2(0.72, 0.72)
			add_child(spr)
			spr.play("play")
		else:
			var orb := Polygon2D.new()
			orb.polygon = PackedVector2Array([
				Vector2(0.0, -9.0), Vector2(8.0, 0.0), Vector2(0.0, 9.0), Vector2(-8.0, 0.0)
			])
			orb.color = Color(0.7, 0.25, 0.9, 0.95)
			add_child(orb)

	func _process(delta: float) -> void:
		if _spent:
			return
		if target != null and is_instance_valid(target) and target.is_inside_tree():
			var aim := target.global_position + Vector2(0.0, -28.0) - global_position
			if aim.length() > 4.0:
				direction = direction.lerp(aim.normalized(), minf(1.0, delta * 3.8)).normalized()
			if aim.length() <= 26.0:
				_impact()
				return
		global_position += direction * speed * delta
		rotation = direction.angle()
		_travel += speed * delta
		if _travel >= 980.0:
			queue_free()

	func _impact() -> void:
		_spent = true
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage, source)
			Fx.hit_flash(target as Node2D, Color(0.6, 0.22, 0.8))
			if target.has_method("apply_knockback"):
				target.apply_knockback(global_position, 180.0)
		queue_free()


class _ExpandingRing extends Node2D:
	var source: Node2D
	var frames: SpriteFrames
	var radius := 20.0
	var grow := 240.0
	var max_r := 320.0
	var band := 30.0
	var damage := 24.0
	var life := 1.2
	var _age := 0.0
	var _hit := false
	var _spr: AnimatedSprite2D

	func _ready() -> void:
		z_index = 9
		if frames != null:
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = frames
			_spr.centered = true
			_spr.position = Vector2(0.0, -8.0)
			add_child(_spr)
			_spr.play("play")
		set_process(true)

	func _process(delta: float) -> void:
		_age += delta
		radius += grow * delta
		if _spr != null:
			var s := clampf(radius / 130.0, 0.75, 2.6)
			_spr.scale = Vector2(s, s * 0.62)
			_spr.modulate.a = clampf(1.0 - _age / life, 0.0, 1.0)
		if not _hit:
			_try_hit()
		if radius >= max_r or _age >= life:
			queue_free()

	func _try_hit() -> void:
		var tree := get_tree()
		if tree == null:
			return
		for node in tree.get_nodes_in_group("player"):
			var victim := node as Node2D
			if victim == null:
				continue
			var dist := Iso.iso_distance(global_position, victim.global_position)
			if absf(dist - radius) > band:
				continue
			_hit = true
			if victim.has_method("take_damage"):
				victim.take_damage(damage, source)
			if victim.has_method("apply_knockback"):
				victim.apply_knockback(global_position, 300.0)
			Fx.hit_flash(victim, Color(0.55, 0.16, 0.7))
			return


class BlindVeil extends CanvasLayer:
	var _left := 0.0
	var _duration := 3.15
	var _rect: ColorRect
	var _mat: ShaderMaterial

	func setup(duration: float) -> void:
		_duration = duration
		_left = duration

	func _ready() -> void:
		layer = 40
		_rect = ColorRect.new()
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.color = Color.WHITE
		_mat = ShaderMaterial.new()
		var shader := load("res://shaders/boss_blind.gdshader") as Shader
		_mat.shader = shader
		_rect.material = _mat
		add_child(_rect)
		_place_hole()

	func _process(delta: float) -> void:
		_left -= delta
		var fade := 1.0
		var age := _duration - _left
		if age < 0.14:
			fade = age / 0.14
		elif _left < 0.45:
			fade = clampf(_left / 0.45, 0.0, 1.0)
		_place_hole()
		if _mat != null:
			_mat.set_shader_parameter("veil_alpha", 0.98 * fade)
		if _left <= 0.0:
			queue_free()

	func _place_hole() -> void:
		if _mat == null:
			return
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		var vp := get_viewport()
		var focus := player.global_position + Vector2(0.0, -46.0)
		var screen := vp.get_canvas_transform() * focus
		var size := vp.get_visible_rect().size
		if size.x < 2.0 or size.y < 2.0:
			return
		_mat.set_shader_parameter("hole_uv", Vector2(screen.x / size.x, screen.y / size.y))
		var zoom := maxf(0.2, vp.get_canvas_transform().get_scale().y)
		_mat.set_shader_parameter("radius_px", 78.0 * zoom)
		_mat.set_shader_parameter("soft_px", 16.0 * zoom)
