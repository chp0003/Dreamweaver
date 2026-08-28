extends "res://scripts/chapters/house_quest.gd"
## Chapter 5 - The Final Stand at the Sacred Loom.
##
## Three phases, no puzzle screens:
##
##   Phase 1  The Breach          clear every Shadow Minion that rises out of
##                                the floor before the Loom can be reached.
##   Phase 2  The Duel of Rhythms Defend Mode parries the boss's Bleach Attacks
##                                (swing the staff as the ring tightens); a run
##                                of clean parries staggers it into Weave Mode,
##                                where the loom opens a rhythm track and every
##                                struck note damages the Shadow Weaver.
##   Phase 3  The Finishing Stitch a W/A/S/D quick-time event, then the Color
##                                Burst that restores the whole world.

const RHYTHM_TRACK := "res://scenes/minigames/RhythmTrack.tscn"
const QTE_SEQUENCE := "res://scenes/minigames/QteSequence.tscn"

const WAVES: Array[int] = [1, 2, 2]
const SPAWN_CELLS: Array[Vector2] = [
	Vector2(-6.0, -2.0),
	Vector2(6.0, -2.0),
	Vector2(-5.0, 4.0),
	Vector2(5.0, 4.0),
	Vector2(0.0, 6.0),
	Vector2(-3.0, 0.0),
]

const RHYTHM_DAMAGE := 9.0
const LOOM_BLEACH_DAMAGE := 0.18

var _loom: PlaceholderProp
var _loom_trigger: Interactable
var _boss: ShadowWeaverBoss
var _shadows_alive := 0
var _loom_integrity := 1.0
var _weave_mode := false
var _in_weave_game := false
var _duel_over := false
var _gray_people: Array[PlaceholderProp] = []


func _build_world() -> void:
	add_room_bounds(Vector2i(-8, -8), 17, 17)

	_loom = spawn_prop("THE SACRED LOOM", Vector2(0.0, -6.0), {
		"texture_path": "res://assets/images/props/sacred_loom.png",
		"prop_size": Vector2(230.0, 160.0),
		"body_color": Color(0.32, 0.28, 0.22),
		"accent_color": Color(0.82, 0.7, 0.4),
	})
	_loom_trigger = add_interactable("Weave", Vector2(0.0, -4.8),
		{"enabled": false, "radius": 108.0})
	_loom_trigger.interacted.connect(_on_loom_used)
	var loom_light := PointLight2D.new()
	loom_light.name = "LoomLight"
	loom_light.color = Color(1.0, 0.86, 0.52)
	loom_light.energy = 1.15
	loom_light.texture_scale = 3.4
	loom_light.position = Vector2(0.0, -70.0)
	var loom_tex := GradientTexture2D.new()
	var loom_grad := Gradient.new()
	loom_grad.set_color(0, Color(1, 1, 1, 1))
	loom_grad.set_color(1, Color(1, 1, 1, 0))
	loom_tex.gradient = loom_grad
	loom_tex.width = 256
	loom_tex.height = 256
	loom_tex.fill = GradientTexture2D.FILL_RADIAL
	loom_tex.fill_from = Vector2(0.5, 0.5)
	loom_tex.fill_to = Vector2(1.0, 0.5)
	loom_light.texture = loom_tex
	_loom.add_child(loom_light)

	# Gray figures wait in the hall. The Color Burst returns them to life.
	for i in range(5):
		var figure := spawn_prop("GRAY FIGURE", Vector2(-6.0 + float(i) * 3.0, -1.0), {
			"texture_path": "res://assets/images/characters/villager_%d.png" % (i + 1),
			"prop_size": Vector2(30.0, 56.0),
			"body_color": Color(0.42, 0.41, 0.4),
			"accent_color": Color(0.55, 0.54, 0.52),
			"show_label": false,
		})
		figure.set_tint(Color(0.72, 0.72, 0.74))
		_gray_people.append(figure)

	# Darkness pools: the minion spawn points, visible from the start.
	for i in range(SPAWN_CELLS.size()):
		spawn_prop("DARKNESS POOL", SPAWN_CELLS[i], {
			"prop_size": Vector2(72.0, 10.0),
			"body_color": Color(0.06, 0.05, 0.07),
			"accent_color": Color(0.2, 0.16, 0.22),
			"show_label": i == 0,
			"cast_shadow": true,
		})

	for i in range(5):
		spawn_prop("ANCESTOR BANNER", Vector2(-7.0 + float(i) * 3.5, -7.5), {
			"texture_path": "res://assets/images/environments/highland/ancestor_banner_3d.png",
			"prop_size": Vector2(48.0, 132.0),
			"body_color": Color(0.22, 0.2, 0.19),
			"accent_color": Color(0.5, 0.4, 0.3),
			"show_label": false,
			"nearest_filter": true,
			"cast_shadow": false,
		})

	_boss = ShadowWeaverBoss.new()
	_boss.position = Iso.cell_to_world(map_cell(Vector2(0.0, -3.6)))
	_boss.max_health = 100.0
	world.add_child(_boss)
	_boss.modulate = Color(1, 1, 1, 0)
	_boss.visible = false


# --------------------------------------------------------------------------
# Chapter flow
# --------------------------------------------------------------------------

func _run_chapter() -> void:
	banner("The Final Stand\nat the Sacred Loom", 2.8)
	objective("Reach the Sacred Loom at the far end of the hall.")
	await wait(1.4)

	await say([
		"The great Guno Bong is one long hall, and at the end of it the Sacred Loom is still strung - half a cloth on it, the pattern stopping mid-figure like a sentence cut off.",
		{"speaker": "S'lang", "text": "The floor is wrong. Those are not shadows. Shadows do not have a surface."},
	])

	if not await _phase_one_breach():
		return
	if not await _phase_two_duel():
		return
	await _phase_three_finish()


## PHASE 1 - clear every shadow before the Loom can be approached.
func _phase_one_breach() -> bool:
	banner("Phase I  -  The Breach", 2.2)
	objective("Clear Shadow Minions (dark figures with purple eyes). Left-click to lock on.")
	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", true)

	for wave_index in range(WAVES.size()):
		if is_finished():
			return false
		_spawn_wave(WAVES[wave_index])
		await until(func() -> bool: return _shadows_alive <= 0 or is_finished())
		if is_finished():
			return false
		if wave_index < WAVES.size() - 1:
			banner("Another wave rises", 1.4)
			await wait(1.4)

	counter("")
	Audio.play_sfx(Audio.Sfx.CHIME)
	await say([
		"The last of them comes apart, and for a moment the hall is only a hall.",
		"Then the half-woven cloth on the Sacred Loom begins to unravel by itself.",
	])
	return true


## PHASE 2 - the hybrid boss fight.
func _phase_two_duel() -> bool:
	_boss.visible = true
	var appear := create_tween()
	appear.tween_property(_boss, "modulate:a", 1.0, 1.4)
	await wait(1.5)

	await say([
		{"speaker": "The Shadow Weaver", "text": "I am not your enemy, weaver. I am only what is left when nobody remembers. You will be me. Everyone is, eventually."},
		{"speaker": "S'lang", "text": "Not while I can still name the colours."},
	])
	GameState.unlock_lore("shadow_weaver")

	banner("Phase II  -  The Duel of Rhythms", 2.4)
	if hud != null:
		if hud.has_method("show_loom_integrity"):
			hud.call("show_loom_integrity", true)
		if hud.has_method("set_loom_integrity"):
			hud.call("set_loom_integrity", _loom_integrity)

	_boss.telegraph_started.connect(_on_telegraph_started)
	_boss.telegraph_resolved.connect(_on_telegraph_resolved)
	_boss.staggered.connect(_on_boss_staggered)
	_boss.recovered.connect(_on_boss_recovered)
	_boss.health_changed.connect(_on_boss_health_changed)
	_boss.defeated.connect(_on_boss_defeated)

	_enter_defend_mode()
	_boss.begin_duel()

	await until(func() -> bool: return _duel_over or is_finished())
	return not is_finished()


## PHASE 3 - the quick-time finale and the Color Burst.
func _phase_three_finish() -> void:
	_boss.end_duel()
	counter("")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "")

	banner("Phase III  -  The Finishing Stitch", 2.2)
	objective("Finish the pattern. Match every prompt.")
	await say([
		"The Shadow Weaver comes apart into loose thread and hangs there, still turning, waiting for someone to either tie it off or let it go.",
		{"speaker": "S'lang", "text": "One stitch. Do not rush it."},
	])

	# If the finale is fluffed entirely, the Shadow Weaver reforms rather than
	# dead-ending the run: the player goes back to Phase 2 with a weakened boss.
	while true:
		var stitched: bool = await run_mini_game(QTE_SEQUENCE)
		if stitched:
			break
		await say([
			{"speaker": "The Shadow Weaver", "text": "You hesitated. I only need you to hesitate."},
		])
		if not await _reform_boss():
			return

	await _color_burst()
	await _closing_cutscene()


# --------------------------------------------------------------------------
# Phase 1 helpers
# --------------------------------------------------------------------------

func _spawn_wave(count: int) -> void:
	for i in range(count):
		var cell: Vector2 = SPAWN_CELLS[i % SPAWN_CELLS.size()]
		var jitter := Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
		var minion := spawn_minion(cell + jitter, {
			"max_health": 55.0,
			"speed": 88.0,
			"touch_damage": 11.0,
			"spawn_delay": 0.45 + float(i) * 0.12,
		})
		if minion == null:
			continue
		minion.died.connect(_on_minion_died)
		_shadows_alive += 1
	_refresh_shadow_counter()


func _on_minion_died(_minion: ShadowMinion) -> void:
	_shadows_alive = maxi(0, _shadows_alive - 1)
	_refresh_shadow_counter()


func _refresh_shadow_counter() -> void:
	counter("Shadows Remaining: %d" % _shadows_alive)


# --------------------------------------------------------------------------
# Phase 2 helpers
# --------------------------------------------------------------------------

func _enter_defend_mode() -> void:
	_weave_mode = false
	_loom_trigger.set_enabled(false)
	objective("DEFEND: cast [Space] as the ring tightens to parry the Bleach Attack.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "DEFEND MODE", Color(0.9, 0.55, 0.42))


func _enter_weave_mode() -> void:
	_weave_mode = true
	_loom_trigger.set_enabled(true)
	objective("WEAVE: reach the Sacred Loom and press [E] while the Shadow Weaver reels.")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "WEAVE MODE", Color(0.9, 0.82, 0.5))


## Every staff swing during a wind-up is a parry attempt.
func _on_player_attacked(_swing_position: Vector2, _facing: Vector2) -> void:
	shake_camera(4.5)
	if _boss != null and is_instance_valid(_boss) and _boss.is_telegraphing():
		_boss.try_parry()


func _on_telegraph_started(_window: float) -> void:
	if not _weave_mode:
		counter("Bleach Attack incoming - parry!")


func _on_telegraph_resolved(parried: bool) -> void:
	if parried:
		counter("Parried.")
		return

	counter("Bleached!")
	if player != null and is_instance_valid(player):
		player.take_damage(_boss.bleach_damage, _boss)
	_damage_loom(LOOM_BLEACH_DAMAGE)


func _on_boss_staggered(_duration: float) -> void:
	banner("The Shadow Weaver reels", 1.4)
	_enter_weave_mode()


func _on_boss_recovered() -> void:
	if _duel_over or _in_weave_game:
		return
	banner("It gathers itself", 1.2)
	_enter_defend_mode()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if _weave_mode or _duel_over:
		return
	counter("Shadow Weaver  %d%%" % roundi(current / maximum * 100.0))


func _on_boss_defeated() -> void:
	_duel_over = true


## Player reached the loom during Weave Mode: open the rhythm track.
func _on_loom_used() -> void:
	if not _weave_mode or _in_weave_game or _duel_over or is_finished():
		return
	_in_weave_game = true
	_loom_trigger.set_enabled(false)

	await run_mini_game(RHYTHM_TRACK, {
		"note_count": 12,
		"note_speed": 300.0,
	}, func(game: Node) -> void:
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

	banner("The loom nearly tore - a life spent holding it", 2.0)
	_loom_integrity = 0.5
	if hud != null and hud.has_method("set_loom_integrity"):
		hud.call("set_loom_integrity", _loom_integrity)


## After a failed finale the boss stands back up at a fraction of its strength.
func _reform_boss() -> bool:
	if _boss == null or not is_instance_valid(_boss):
		return false
	_duel_over = false
	_boss.health = _boss.max_health * 0.25
	_boss.health_changed.emit(_boss.health, _boss.max_health)
	_boss.begin_duel()
	_enter_defend_mode()
	banner("The Shadow Weaver re-gathers", 2.0)

	await until(func() -> bool: return _duel_over or is_finished())
	if is_finished():
		return false

	_boss.end_duel()
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
	banner("The Sacred Loom remembers", 2.2)
	Audio.play_sfx(Audio.Sfx.CHIME)
	shake_camera(10.0)

	if is_instance_valid(_boss):
		Fx.fiber_burst(_boss, Palette.GOLD_SUN)
		var dissolve := create_tween()
		dissolve.set_parallel(true)
		dissolve.tween_property(_boss, "modulate:a", 0.0, 1.15)
		dissolve.tween_property(_boss, "scale", Vector2(1.7, 0.12), 1.15)
	await wait(0.85)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 280.0, 1.0, 1.1)
		banner("Sacred patterns wake", 1.8)
	await wait(1.0)

	if _loom != null:
		ColorRestoration.bloom_zone("color_burst", _loom, 720.0, 1.0, 1.4)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	banner("COLOUR", 2.6)

	var burst := _make_burst()
	burst.position = _loom.position if is_instance_valid(_loom) else Vector2.ZERO
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
	GameState.complete_game()
	_awaken_people()

	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 1.8)
	await fade.finished
	flash.queue_free()
	await wait(1.0)


func _awaken_people() -> void:
	for i in range(_gray_people.size()):
		var person := _gray_people[i]
		if person == null or not is_instance_valid(person):
			continue
		person.set_tint(Color.WHITE)
		person.body_color = Color(0.66, 0.5, 0.36)
		person.accent_color = Color(0.8, 0.24, 0.2)
		person.queue_redraw()
		var wake := create_tween()
		wake.tween_property(person, "modulate", Color(1.15, 1.08, 0.95), 0.7)\
			.set_delay(float(i) * 0.16)
		wake.tween_property(person, "modulate", Color.WHITE, 0.4)


func _make_burst() -> GPUParticles2D:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 24.0
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 220.0
	material.initial_velocity_max = 620.0
	material.gravity = Vector3(0.0, 120.0, 0.0)
	material.scale_min = 2.0
	material.scale_max = 6.0
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
	particles.lifetime = 2.6
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.emitting = false
	particles.z_index = 60
	return particles


## Gray statues become living NPCs, the land turns green, then the credits.
func _closing_cutscene() -> void:
	await say([
		"The colour does not stop at the walls of the House. It runs out along the mountain paths, into the terraces, up the hills, into cloth that has been folded away in the dark for a generation.",
		"The gray figures in the hall draw breath. Faces return. Hands remember work.",
	])

	await wait(1.4)

	await say([
		{"speaker": "Master Weaver", "text": "..."},
		"The Master Weaver's ghost is standing at the back of the hall, in colour now, and solid enough to be somebody's grandmother. She looks at the loom. She looks at S'lang. She inclines her head, once.",
		{"speaker": "S'lang", "text": "I will teach it. All of it. To anyone who will sit still and learn."},
	])

	objective("")
	SceneFader.fade_to_scene(AccountManager.ENDING_SCENE)
