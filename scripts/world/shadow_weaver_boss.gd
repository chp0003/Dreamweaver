class_name ShadowWeaverBoss
extends Node2D
## The Shadow Weaver: smoke and unravelled thread, final opponent of Chapter 5.
##
## The boss runs a simple loop of telegraphed "Bleach Attacks". Chapter 5 turns
## that loop into the Duel of Rhythms:
##
##   Defend Mode - `telegraph_started` opens a parry window. The chapter calls
##                 `try_parry()` when the player presses the attack key. A hit
##                 parry chips the boss; a miss damages S'lang and the loom.
##   Weave Mode  - after `heavy_windup` parries the boss overextends and calls
##                 `stagger()`, emitting `staggered`. While staggered the loom
##                 can be used, and each rhythm note feeds `take_damage()`.

signal health_changed(current: float, maximum: float)
signal telegraph_started(window: float)
signal telegraph_resolved(parried: bool)
signal staggered(duration: float)
signal recovered
signal defeated

const PARRY_GRACE := 0.12
const SHEET_PATH := "res://assets/images/enemies/shadow_weaver_boss_sheet.png"
const FRAME_SIZE := Vector2i(320, 320)

@export var max_health := 100.0
## Seconds of telegraph before a Bleach Attack lands. Shrinks as the boss weakens.
@export var telegraph_window := 1.05
@export var attack_interval := 1.5
@export var bleach_damage := 16.0
## Parries needed before the boss overextends into a stagger.
@export var parries_to_stagger := 3
@export var stagger_duration := 7.0
## Every Nth Bleach Attack is a heavy overextend that always opens Weave Mode
## when parried, matching the "heavy attack then stun" beat.
@export var heavy_every := 4

var health := 100.0

var _active := false
var _telegraphing := false
var _resolved := false
var _timer := 0.0
var _window_left := 0.0
var _parry_streak := 0
var _staggered := false
var _stagger_left := 0.0
var _dead := false
var _attack_index := 0
var _heavy := false
var _current_window := 1.05

var _art: PlaceholderProp
var _sprite: AnimatedSprite2D
var _tell: Node2D
var _smoke: GPUParticles2D


func _ready() -> void:
	# Deliberately not in the "hittable" group: the Shadow Weaver cannot be
	# mashed down with melee. It only takes damage from clean parries and from
	# struck notes on the loom, which is what makes the duel a duel.
	add_to_group("boss")
	health = max_health
	_build_visuals()
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	if not _active or _dead:
		return

	if _staggered:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			_end_stagger()
		return

	if _telegraphing:
		_window_left -= delta
		_update_tell(1.0 - clampf(_window_left / maxf(0.001, _current_window), 0.0, 1.0))
		if _window_left <= -PARRY_GRACE and not _resolved:
			_resolve_telegraph(false)
		return

	_timer -= delta
	if _timer <= 0.0:
		_begin_telegraph()


# --------------------------------------------------------------------------
# Fight control
# --------------------------------------------------------------------------

func begin_duel() -> void:
	_active = true
	_dead = false
	_staggered = false
	_timer = attack_interval
	_play_visual("idle")
	if _smoke != null:
		_smoke.emitting = true


func end_duel() -> void:
	_active = false
	_telegraphing = false
	_hide_tell()
	if _smoke != null:
		_smoke.emitting = false


func is_staggered() -> bool:
	return _staggered


func is_telegraphing() -> bool:
	return _telegraphing and not _resolved


## Called when the player presses the attack key. Returns true on a clean parry.
func try_parry() -> bool:
	if not is_telegraphing():
		return false
	# The window is generous right at the end of the wind-up.
	if _window_left > _current_window * 0.55:
		return false
	_resolve_telegraph(true)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_flash(Color(1.8, 1.5, 1.5))

	# The Shadow Weaver frays faster as it loses hold of the pattern.
	var ratio := health / max_health
	telegraph_window = lerpf(0.68, 1.05, ratio)
	attack_interval = lerpf(1.05, 1.5, ratio)

	if health <= 0.0:
		_dead = true
		_active = false
		_hide_tell()
		defeated.emit()


## Forces the boss into its vulnerable Weave Mode window.
func stagger(duration: float = -1.0) -> void:
	if _dead or _staggered:
		return
	_staggered = true
	_telegraphing = false
	_hide_tell()
	_stagger_left = stagger_duration if duration < 0.0 else duration
	_parry_streak = 0
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_flash(Color(1.4, 1.3, 0.9))
	_play_visual("stagger")
	staggered.emit(_stagger_left)


func end_stagger_early() -> void:
	if _staggered:
		_end_stagger()


func health_ratio() -> float:
	return health / max_health


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _begin_telegraph() -> void:
	_telegraphing = true
	_resolved = false
	_attack_index += 1
	_heavy = heavy_every > 0 and (_attack_index % heavy_every) == 0
	_window_left = telegraph_window * (1.35 if _heavy else 1.0)
	_current_window = _window_left
	_show_tell()
	_play_visual("cast" if _heavy else "windup")
	Audio.play_wind_whistle()
	telegraph_started.emit(_window_left)


func _resolve_telegraph(parried: bool) -> void:
	_resolved = true
	_telegraphing = false
	_hide_tell()
	_timer = attack_interval

	if parried:
		_parry_streak += 1
		Audio.play_sfx(Audio.Sfx.PARRY)
		take_damage(6.0 if _heavy else 4.0)
		GameState.add_score(40 if _heavy else 30)
		# A clean parry of a heavy overextend, or a run of light parries,
		# staggers the Weaver into Weave Mode.
		if _heavy or _parry_streak >= parries_to_stagger:
			telegraph_resolved.emit(true)
			stagger()
			return
	else:
		_parry_streak = 0
		Audio.play_sfx(Audio.Sfx.FAIL)
		_play_visual("attack")

	telegraph_resolved.emit(parried)


func _end_stagger() -> void:
	_staggered = false
	_stagger_left = 0.0
	_timer = attack_interval * 0.8
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
	_tell.z_index = 12
	add_child(_tell)

	var ring := Line2D.new()
	ring.name = "Ring"
	var points := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		points.append(Vector2(cos(a) * 78.0, sin(a) * 40.0))
	ring.points = points
	ring.width = 3.0
	ring.default_color = Color(0.95, 0.9, 0.75, 0.85)
	ring.antialiased = true
	_tell.add_child(ring)


func _show_tell() -> void:
	if _tell != null:
		_tell.visible = true
		_tell.scale = Vector2(1.6, 1.6)


func _hide_tell() -> void:
	if _tell != null:
		_tell.visible = false


## Wind-up ring shrinks toward the boss; parry when it is tight.
func _update_tell(progress: float) -> void:
	if _tell == null:
		return
	var s := lerpf(1.6, 0.85, clampf(progress, 0.0, 1.0))
	_tell.scale = Vector2(s, s)
	var ring := _tell.get_node_or_null("Ring") as Line2D
	if ring != null:
		var tell_color := Color(0.95, 0.88, 0.8).lerp(
			Color(1.0, 0.24, 0.22),
			progress
		)
		tell_color.a = 0.72 + progress * 0.28
		ring.default_color = tell_color
		ring.width = 3.0 + progress * 2.0


func is_heavy_attack() -> bool:
	return _heavy


## Phase 3: the Weaver drops to its knees, waiting for the last stitch.
func kneel() -> void:
	_active = false
	_telegraphing = false
	_staggered = false
	_hide_tell()
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
	if _sprite != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func _on_visual_finished() -> void:
	if _sprite == null or _dead or _staggered or not _active:
		return
	if _sprite.animation != &"idle":
		_sprite.play("idle")


func _build_sprite_frames() -> SpriteFrames:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SHEET_PATH)) != OK:
		push_warning("ShadowWeaverBoss: missing %s" % SHEET_PATH)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var cell_w := int(image.get_width() / 4)
	var cell_h := int(image.get_height() / 2)
	if cell_w < 8 or cell_h < 8:
		return null
	var textures: Array[Texture2D] = []
	for i in range(8):
		var cell := image.get_region(Rect2i(
			(i % 4) * cell_w,
			int(i / 4) * cell_h,
			cell_w,
			cell_h
		))
		_key_boss_plate(cell)
		textures.append(_fit_boss_frame(cell))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_visual_anim(frames, &"idle", [textures[0], textures[1], textures[2], textures[1]], 3.5, true)
	_add_visual_anim(frames, &"windup", [textures[3]], 1.0, false)
	_add_visual_anim(frames, &"attack", [textures[4]], 1.0, false)
	_add_visual_anim(frames, &"cast", [textures[5]], 1.0, false)
	_add_visual_anim(frames, &"stagger", [textures[6]], 1.0, false)
	_add_visual_anim(frames, &"recover", [textures[7], textures[0]], 5.0, false)
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
