class_name ShadowWeaverBoss
extends Node2D
## Final boss: claw melee, hall-blind, two shadow adds, and a shadow-burst
## ultimate. Floor tells, dodgeable strikes, punish windows after heavies.

signal health_changed(current: float, maximum: float)
signal telegraph_started(window: float)
signal telegraph_resolved(parried: bool)
signal staggered(duration: float)
signal recovered
signal defeated

const PARRY_GRACE := 0.08
const SHEET_PATH := "res://assets/images/enemies/shadow_weaver_boss_sheet.png"
const FRAME_SIZE := Vector2i(320, 320)
const SHEET_COLS := 4
const SHEET_ROWS := 3

enum Move { Melee, Blind, Summon, Burst }

@export var max_health := 560.0
@export var chase_speed := 148.0
@export var keep_range := 64.0
@export var bleach_damage := 20.0
@export var stagger_duration := 1.35
@export var poise_to_stagger := 140.0
@export var blind_duration := 4.4
@export var burst_orbs := 10

var health := 100.0

var _active := false
var _telegraphing := false
var _resolved := false
var _timer := 0.8
var _window_left := 0.0
var _current_window := 1.0
var _staggered := false
var _stagger_left := 0.0
var _dead := false
var _heavy := false
var _move := Move.Melee
var _poise := 0.0
var _recover_left := 0.0
var _home := Vector2.ZERO
var _arena_radius := 280.0
var _aim := Vector2(0, 1)
var _strike_center := Vector2.ZERO
var _lunge_vel := Vector2.ZERO
var _cd_blind := 5.5
var _cd_summon := 3.5
var _cd_burst := 9.0
var _blind_left := 0.0
var _adds: Array[Node] = []
var _veil: CanvasLayer

var _art: PlaceholderProp
var _sprite: AnimatedSprite2D
var _tell: Node2D
var _danger: Polygon2D
var _smoke: GPUParticles2D


func _ready() -> void:
	add_to_group("boss")
	add_to_group("hittable")
	health = max_health
	_home = global_position
	_build_visuals()
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	_cd_blind = maxf(0.0, _cd_blind - delta)
	_cd_summon = maxf(0.0, _cd_summon - delta)
	_cd_burst = maxf(0.0, _cd_burst - delta)
	if _blind_left > 0.0:
		_blind_left = maxf(0.0, _blind_left - delta)
		if _blind_left <= 0.0:
			_clear_blind()
	if not _active or _dead:
		return
	if _staggered:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			_end_stagger()
		return
	if _recover_left > 0.0:
		_recover_left -= delta
		_face_player()
		return
	if _telegraphing:
		_window_left -= delta
		_update_tell(1.0 - clampf(_window_left / maxf(0.001, _current_window), 0.0, 1.0))
		if _lunge_vel != Vector2.ZERO and _window_left < _current_window * 0.25:
			global_position += _lunge_vel * delta
			_clamp_arena()
		if _window_left <= -PARRY_GRACE and not _resolved:
			_resolve_telegraph(false)
		return
	_timer -= delta
	_chase_player(delta)
	if _timer <= 0.0:
		_begin_telegraph()


func begin_duel() -> void:
	_active = true
	_dead = false
	_staggered = false
	_timer = 0.4
	_home = global_position
	_cd_blind = 5.5
	_cd_summon = 3.2
	_cd_burst = 8.5
	_play_visual("idle")
	if _smoke != null:
		_smoke.emitting = true


func end_duel() -> void:
	_active = false
	_telegraphing = false
	_lunge_vel = Vector2.ZERO
	_hide_tell()
	_clear_blind()
	_clear_adds()
	if _smoke != null:
		_smoke.emitting = false


func set_arena(home: Vector2, radius: float) -> void:
	_home = home
	_arena_radius = radius


func is_staggered() -> bool:
	return _staggered


func is_telegraphing() -> bool:
	return _telegraphing and not _resolved


func current_move() -> String:
	match _move:
		Move.Blind:
			return "blind"
		Move.Summon:
			return "summon"
		Move.Burst:
			return "burst"
		_:
			return "melee"


func hit_radius() -> float:
	return 56.0


func try_parry() -> bool:
	if not is_telegraphing():
		return false
	if _window_left > _current_window * 0.42:
		return false
	var player := _player()
	if player == null or Iso.iso_distance(global_position, player.global_position) > 130.0:
		return false
	_resolve_telegraph(true)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	if _staggered:
		amount *= 1.35
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_flash(Color(1.8, 1.5, 1.5))
	_poise += amount
	if not _staggered and _poise >= poise_to_stagger:
		stagger()
	if health <= 0.0:
		_dead = true
		_active = false
		_hide_tell()
		_clear_blind()
		_clear_adds()
		defeated.emit()


func stagger(duration: float = -1.0) -> void:
	if _dead or _staggered:
		return
	_staggered = true
	_telegraphing = false
	_lunge_vel = Vector2.ZERO
	_hide_tell()
	_stagger_left = stagger_duration if duration < 0.0 else duration
	_poise = 0.0
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_flash(Color(1.4, 1.3, 0.9))
	_play_visual("stagger")
	staggered.emit(_stagger_left)


func end_stagger_early() -> void:
	if _staggered:
		_end_stagger()


func health_ratio() -> float:
	return health / max_health


func is_heavy_attack() -> bool:
	return _heavy


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
	if dist > keep_range + 18.0:
		var step := to_player.normalized() * chase_speed * delta
		global_position += step
		_clamp_arena()
		_play_visual("walk")
	elif dist < keep_range * 0.5:
		global_position -= to_player.normalized() * chase_speed * 0.5 * delta
		_clamp_arena()
		_play_visual("walk")
	else:
		_play_visual("idle")


func _face_player() -> void:
	var player := _player()
	if player == null:
		return
	_aim = (player.global_position - global_position)
	if _aim.length() < 2.0:
		_aim = Vector2(0, 1)
	else:
		_aim = _aim.normalized()
	if _sprite != null:
		_sprite.flip_h = player.global_position.x < global_position.x


func _clamp_arena() -> void:
	var offset := global_position - _home
	if offset.length() <= _arena_radius:
		return
	global_position = _home + offset.normalized() * _arena_radius


func _begin_telegraph() -> void:
	var player := _player()
	_telegraphing = true
	_resolved = false
	_lunge_vel = Vector2.ZERO
	_face_player()
	var dist := 180.0
	if player != null:
		dist = Iso.iso_distance(global_position, player.global_position)
	_move = _pick_move(dist)
	if _move == Move.Melee and dist > keep_range + 42.0:
		_telegraphing = false
		_timer = 0.12
		return
	_heavy = _move == Move.Burst or _move == Move.Blind
	match _move:
		Move.Melee:
			_current_window = 0.42
			_lunge_vel = _aim * 210.0
		Move.Blind:
			_current_window = 0.85
			_cd_blind = 16.5
		Move.Summon:
			_current_window = 0.78
			_cd_summon = 13.0
		Move.Burst:
			_current_window = 1.15
			_cd_burst = 18.0
	_window_left = _current_window
	if player != null:
		_strike_center = player.global_position
	else:
		_strike_center = global_position + _aim * 90.0
	_show_tell()
	if _move == Move.Burst:
		_seed_burst_tells()
	match _move:
		Move.Blind:
			_play_visual("blind")
		Move.Summon:
			_play_visual("summon")
		Move.Burst:
			_play_visual("burst_windup")
		_:
			_play_visual("windup")
	Audio.play_wind_whistle()
	telegraph_started.emit(_window_left)


func _pick_move(dist: float) -> Move:
	_prune_adds()
	var can_burst := _cd_burst <= 0.0 and _blind_left <= 0.0 \
		and (health_ratio() <= 0.78 or _cd_summon < 8.0)
	var can_summon := _cd_summon <= 0.0 and _adds.size() < 2
	var can_blind := _cd_blind <= 0.0 and _blind_left <= 0.0
	if can_burst and (dist < 210.0 or health_ratio() <= 0.55):
		return Move.Burst
	if can_summon and randf() < (0.7 if dist > 90.0 else 0.4):
		return Move.Summon
	if can_blind and dist < 230.0:
		return Move.Blind
	if dist > keep_range + 42.0:
		if can_summon:
			return Move.Summon
		if can_burst:
			return Move.Burst
	return Move.Melee


func _resolve_telegraph(parried: bool) -> void:
	_resolved = true
	_telegraphing = false
	_lunge_vel = Vector2.ZERO

	if parried:
		_hide_tell()
		_timer = 0.55
		Audio.play_sfx(Audio.Sfx.PARRY)
		take_damage(22.0 if _heavy else 14.0)
		GameState.add_score(50 if _heavy else 30)
		_poise += 40.0
		if _poise >= poise_to_stagger or _heavy:
			telegraph_resolved.emit(true)
			stagger()
			return
		_recover_left = 0.35
	else:
		match _move:
			Move.Blind:
				_play_visual("blind")
			Move.Summon:
				_play_visual("summon")
			Move.Burst:
				_play_visual("burst")
			_:
				_play_visual("attack")
		_land_attack()
		_hide_tell()
		_timer = 1.05 if _move == Move.Burst else (0.7 if _move != Move.Melee else 0.38)
		_recover_left = 0.85 if _move == Move.Burst else (0.42 if _heavy else 0.22)
	telegraph_resolved.emit(parried)


func _land_attack() -> void:
	match _move:
		Move.Blind:
			_cast_blind()
			Audio.play_sfx(Audio.Sfx.FAIL)
			Fx.punch(self, 0.14)
			return
		Move.Summon:
			_spawn_adds()
			Audio.play_sfx(Audio.Sfx.THUD)
			Fx.punch(self, 0.12)
			return
		Move.Burst:
			_fire_burst()
			Audio.play_sfx(Audio.Sfx.FAIL)
			Fx.punch(self, 0.22)
			return
		_:
			pass
	var player := _player()
	Audio.play_sfx(Audio.Sfx.THUD)
	Fx.punch(self, 0.12)
	if player == null:
		return
	if _player_in_strike(player):
		player.take_damage(bleach_damage, self)
		if player.has_method("apply_knockback"):
			player.apply_knockback(global_position, 280.0)


func _player_in_strike(player: Node2D) -> bool:
	var dist := Iso.iso_distance(global_position, player.global_position)
	if dist > 96.0:
		return false
	var to_player := (player.global_position - global_position).normalized()
	return _aim.dot(to_player) > 0.12


func _cast_blind() -> void:
	_blind_left = blind_duration
	if _veil != null and is_instance_valid(_veil):
		_veil.queue_free()
	_veil = BlindVeil.new()
	_veil.hold_time = blind_duration
	var tree := get_tree()
	if tree != null:
		tree.root.add_child(_veil)


func _clear_blind() -> void:
	_blind_left = 0.0
	if _veil != null and is_instance_valid(_veil):
		_veil.fade_out()
	_veil = null


func _spawn_adds() -> void:
	_prune_adds()
	var needed := 2 - _adds.size()
	if needed <= 0:
		return
	var host := get_parent()
	if host == null:
		host = self
	var offsets := [Vector2(-70.0, 28.0), Vector2(70.0, 28.0)]
	for i in range(needed):
		var minion := ShadowMinion.new()
		minion.max_health = 52.0
		minion.touch_damage = 12.0
		minion.speed = 132.0
		minion.combat_style = "dasher" if i == 0 else "chaser"
		minion.spawn_delay = 0.2
		minion.set_meta("boss_add", true)
		host.add_child(minion)
		minion.global_position = global_position + offsets[i]
		minion.scale = Vector2(1.45, 1.45)
		minion.z_index = 6
		_adds.append(minion)


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


func _seed_burst_tells() -> void:
	# Orbs spawn on resolve; the floor tell is the large ring around the Weaver.
	pass


func _fire_burst() -> void:
	var host := get_parent()
	if host == null:
		host = self
	var player := _player()
	var count := burst_orbs
	if health_ratio() <= 0.4:
		count += 4
	for i in range(count):
		var orb := ShadowOrb.new()
		var angle := TAU * float(i) / float(count)
		var radius := 78.0 + float(i % 3) * 36.0
		orb.damage = bleach_damage * 0.85
		orb.global_position = global_position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.55)
		host.add_child(orb)
	if player != null:
		for j in range(3):
			var extra := ShadowOrb.new()
			extra.damage = bleach_damage * 0.9
			var jitter := Vector2(randf_range(-70.0, 70.0), randf_range(-48.0, 48.0))
			extra.global_position = player.global_position + jitter
			host.add_child(extra)


func _end_stagger() -> void:
	_staggered = false
	_stagger_left = 0.0
	_timer = 0.7
	_play_visual("recover")
	recovered.emit()


func _build_visuals() -> void:
	var boss_frames := _build_sprite_frames()
	if boss_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "ShadowWeaverArt"
		_sprite.sprite_frames = boss_frames
		_sprite.centered = true
		_sprite.position = Vector2(0.0, -FRAME_SIZE.y * 0.5)
		# Chapter 5 applies a 1.25 world scale. This keeps the boss roughly
		# twice S'lang's height while its lowered arena anchor prevents clipping.
		_sprite.scale = Vector2(0.8, 0.8)
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


func _show_tell() -> void:
	if _tell == null:
		return
	_tell.visible = true
	_tell.scale = Vector2.ONE
	_tell.rotation = 0.0
	if _move == Move.Burst:
		_tell.position = Vector2.ZERO
	elif _move == Move.Summon:
		_tell.position = Vector2.ZERO
	else:
		_tell.position = Vector2.ZERO
	var pts := _danger_points()
	if _danger != null:
		_danger.polygon = pts
		_danger.color = Color(0.92, 0.16, 0.18, 0.32)
	var rim := _tell.get_node_or_null("Rim") as Line2D
	if rim != null:
		rim.points = pts


func _hide_tell() -> void:
	if _tell != null:
		_tell.visible = false


func _danger_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	match _move:
		Move.Burst:
			for i in range(24):
				var a := TAU * float(i) / 24.0
				pts.append(Vector2(cos(a) * 168.0, sin(a) * 92.0))
		Move.Summon:
			for i in range(16):
				var a := TAU * float(i) / 16.0
				pts.append(Vector2(cos(a) * 70.0, sin(a) * 36.0 + 18.0))
		Move.Blind:
			for i in range(18):
				var a := TAU * float(i) / 18.0
				pts.append(Vector2(cos(a) * 48.0, sin(a) * 26.0) + Vector2(0, -52))
		_:
			var left := _aim.rotated(-0.7) * 108.0
			var right := _aim.rotated(0.7) * 108.0
			pts.append(-_aim * 8.0)
			pts.append(left)
			pts.append(right)
	return pts


func _update_tell(progress: float) -> void:
	if _tell == null:
		return
	var pulse := 0.92 + progress * 0.18
	_tell.scale = Vector2(pulse, pulse)
	if _danger != null:
		_danger.color = Color(0.92, 0.12, 0.14, 0.28 + progress * 0.28)
	var rim := _tell.get_node_or_null("Rim") as Line2D
	if rim != null:
		rim.default_color = Color(1.0, 0.22 + progress * 0.2, 0.18, 0.8 + progress * 0.2)
		rim.width = 3.0 + progress * 3.0


## Phase 3: the Weaver drops to its knees, waiting for the last stitch.
func kneel() -> void:
	_active = false
	_telegraphing = false
	_staggered = false
	_hide_tell()
	_clear_blind()
	_clear_adds()
	if _smoke != null:
		_smoke.emitting = false
	_play_visual("stagger")
	var home := scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees", 16.0, 0.55)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(home.x * 1.05, home.y * 0.82), 0.55)


## Color Burst: the sprite unravels into light.
func dissolve_into_light() -> void:
	_active = false
	_dead = true
	_hide_tell()
	_clear_blind()
	_clear_adds()
	if _smoke != null:
		_smoke.emitting = false
	Fx.fiber_burst(self, Palette.GOLD_SUN)
	var home := scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.6, 1.5, 1.1, 0.0), 1.25)
	tween.tween_property(self, "scale", Vector2(home.x * 1.8, home.y * 0.12), 1.25)


func _flash(tint: Color) -> void:
	if _art == null and _sprite == null:
		return
	if _art != null:
		_art.set_tint(tint)
	if _sprite != null:
		_sprite.modulate = tint
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_art):
			_art.set_tint(Color.WHITE)
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
	)


func _play_visual(anim: StringName) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)


func _on_visual_finished() -> void:
	if _sprite == null or _dead or _staggered or not _active:
		return
	if _sprite.animation == &"idle" or _sprite.animation == &"walk":
		return
	_sprite.play("idle")


func _build_sprite_frames() -> SpriteFrames:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SHEET_PATH)) != OK:
		push_warning("ShadowWeaverBoss: missing %s" % SHEET_PATH)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var aspect := float(image.get_width()) / maxf(1.0, float(image.get_height()))
	var cols := SHEET_COLS
	var rows := SHEET_ROWS if aspect < 1.7 else 2
	var cell_w := int(image.get_width() / cols)
	var cell_h := int(image.get_height() / rows)
	if cell_w < 8 or cell_h < 8:
		return null
	var count := cols * rows
	var textures: Array[Texture2D] = []
	for i in range(count):
		var cell := image.get_region(Rect2i(
			(i % cols) * cell_w,
			int(i / cols) * cell_h,
			cell_w,
			cell_h
		))
		_key_boss_plate(cell)
		textures.append(_fit_boss_frame(cell))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if textures.size() >= 12:
		_add_visual_anim(frames, &"idle", [textures[0], textures[1], textures[11], textures[1]], 3.6, true)
		_add_visual_anim(frames, &"walk", [textures[2], textures[1], textures[2], textures[0]], 6.0, true)
		_add_visual_anim(frames, &"windup", [textures[3]], 1.0, false)
		_add_visual_anim(frames, &"attack", [textures[4]], 1.0, false)
		_add_visual_anim(frames, &"blind", [textures[5]], 1.0, false)
		_add_visual_anim(frames, &"summon", [textures[6]], 1.0, false)
		_add_visual_anim(frames, &"burst_windup", [textures[7]], 1.0, false)
		_add_visual_anim(frames, &"burst", [textures[8]], 1.0, false)
		_add_visual_anim(frames, &"stagger", [textures[9]], 1.0, false)
		_add_visual_anim(frames, &"recover", [textures[10], textures[0]], 5.0, false)
		_add_visual_anim(frames, &"cast", [textures[5]], 1.0, false)
	else:
		_add_visual_anim(frames, &"idle", [textures[0], textures[1], textures[2], textures[1]], 3.5, true)
		_add_visual_anim(frames, &"walk", [textures[0], textures[2]], 5.0, true)
		_add_visual_anim(frames, &"windup", [textures[3]], 1.0, false)
		_add_visual_anim(frames, &"attack", [textures[mini(4, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"cast", [textures[mini(5, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"blind", [textures[mini(5, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"summon", [textures[mini(5, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"burst_windup", [textures[3]], 1.0, false)
		_add_visual_anim(frames, &"burst", [textures[mini(4, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"stagger", [textures[mini(6, textures.size() - 1)]], 1.0, false)
		_add_visual_anim(frames, &"recover", [textures[mini(7, textures.size() - 1)], textures[0]], 5.0, false)
	return frames


func _add_visual_anim(
		frames: SpriteFrames,
		anim: StringName,
		textures: Array,
		fps: float,
		loop: bool
) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for texture in textures:
		frames.add_frame(anim, texture as Texture2D)


func _key_boss_plate(image: Image) -> void:
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
		var color: Color = image.get_pixelv(point)
		if not _is_boss_plate(color):
			continue
		image.set_pixelv(point, Color.TRANSPARENT)
		pending.append(point + Vector2i.RIGHT)
		pending.append(point + Vector2i.LEFT)
		pending.append(point + Vector2i.DOWN)
		pending.append(point + Vector2i.UP)


func _is_boss_plate(color: Color) -> bool:
	if color.a < 0.08:
		return true
	# Generated plate ranges from hot magenta to violet. Flooding only from the
	# cell edge preserves the enclosed violet eye/core and rim lighting.
	return color.r > 0.32 and color.b > 0.38 and color.g < 0.28 \
		and (color.r + color.b) > color.g * 3.2


func _fit_boss_frame(source: Image) -> Texture2D:
	var used := source.get_used_rect()
	var canvas := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	if used.size.x < 1 or used.size.y < 1:
		return ImageTexture.create_from_image(canvas)
	var crop := source.get_region(used)
	var available := FRAME_SIZE - Vector2i(24, 24)
	var scale_factor := minf(
		float(available.x) / float(crop.get_width()),
		float(available.y) / float(crop.get_height())
	)
	var target := Vector2i(
		maxi(1, int(round(crop.get_width() * scale_factor))),
		maxi(1, int(round(crop.get_height() * scale_factor)))
	)
	crop.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var origin := Vector2i(
		(FRAME_SIZE.x - target.x) / 2,
		FRAME_SIZE.y - 12 - target.y
	)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, target), origin)
	return ImageTexture.create_from_image(canvas)


class ShadowOrb extends Node2D:
	const ARM := 0.55
	const LIVE := 1.25
	const HIT_RADIUS := 40.0
	const EXPLODE_RADIUS := 52.0

	var damage := 16.0
	var _age := 0.0
	var _spent := false
	var _armed := false
	var _ball: Sprite2D
	var _tell: Polygon2D


	func _ready() -> void:
		z_index = 16
		_tell = Polygon2D.new()
		var ring := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			ring.append(Vector2(cos(a) * 38.0, sin(a) * 20.0))
		_tell.polygon = ring
		_tell.color = Color(0.78, 0.12, 0.22, 0.42)
		_tell.z_index = -1
		add_child(_tell)
		_ball = Sprite2D.new()
		_ball.texture = _dot()
		_ball.modulate = Color(0.28, 0.08, 0.38, 0.0)
		_ball.scale = Vector2(0.55, 0.55)
		_ball.position = Vector2(0.0, -18.0)
		add_child(_ball)
		set_process(true)


	func _process(delta: float) -> void:
		if _spent:
			return
		_age += delta
		var pulse := 0.9 + 0.12 * sin(_age * 14.0)
		if _tell != null:
			_tell.scale = Vector2(pulse, pulse)
			_tell.color.a = 0.28 + 0.22 * clampf(_age / ARM, 0.0, 1.0)
		if not _armed and _age >= ARM:
			_armed = true
			if _ball != null:
				_ball.modulate.a = 0.95
		if _armed and _ball != null:
			_ball.scale = Vector2(0.58, 0.58) * (1.0 + 0.08 * sin(_age * 10.0))
			_try_hit(HIT_RADIUS)
		if _age >= ARM + LIVE:
			_explode()


	func _try_hit(radius: float) -> void:
		var tree := get_tree()
		if tree == null:
			return
		for node in tree.get_nodes_in_group("player"):
			var victim := node as Node2D
			if victim == null or not victim.is_inside_tree():
				continue
			if Iso.iso_distance(global_position, victim.global_position) > radius:
				continue
			_impact(victim)
			return


	func _impact(victim: Node2D) -> void:
		_spent = true
		if victim.has_method("take_damage"):
			victim.take_damage(damage, self)
		if victim.has_method("apply_knockback"):
			victim.apply_knockback(global_position, 220.0)
		Fx.hit_flash(victim, Color(0.55, 0.18, 0.62))
		queue_free()


	func _explode() -> void:
		_try_hit(EXPLODE_RADIUS)
		if _spent:
			return
		_spent = true
		Fx.fiber_burst(self, Color(0.42, 0.16, 0.5))
		queue_free()


	func _dot() -> Texture2D:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		var centre := Vector2(23.5, 23.5)
		for y in range(48):
			for x in range(48):
				var d := Vector2(x, y).distance_to(centre) / 24.0
				image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.7)))
		return ImageTexture.create_from_image(image)


class BlindVeil extends CanvasLayer:
	var hold_time := 4.4
	var _shade: ColorRect
	var _tag: Label
	var _fading := false


	func _ready() -> void:
		layer = 105
		name = "BlindVeil"
		_shade = ColorRect.new()
		_shade.color = Color(0.01, 0.0, 0.02, 0.0)
		_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
		_tag = Label.new()
		_tag.text = "BLINDED"
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_tag.offset_left = -140.0
		_tag.offset_right = 140.0
		_tag.offset_top = 88.0
		_tag.offset_bottom = 120.0
		_tag.add_theme_font_size_override("font_size", 22)
		_tag.add_theme_color_override("font_color", Color(0.72, 0.62, 0.82, 0.9))
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tag)
		var tween := create_tween()
		tween.tween_property(_shade, "color:a", 1.0, 0.28)
		tween.tween_interval(hold_time)
		tween.tween_callback(fade_out)


	func fade_out() -> void:
		if _fading:
			return
		_fading = true
		var tween := create_tween()
		if _shade != null:
			tween.tween_property(_shade, "color:a", 0.0, 0.45)
		if _tag != null:
			tween.parallel().tween_property(_tag, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
