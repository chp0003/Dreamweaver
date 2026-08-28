extends ChapterBase
## Tutorial - "S'lang's Awakening".
##
## Step-gated: walk until it reads as understood, pick up the Lewet Staff,
## then land one hit on a Shadow Creep. Colour stays on — this room is not
## a bleached House.

var _staff: PlaceholderProp
var _staff_trigger: Interactable
var _goddess: PlaceholderProp
var _tutorial: TutorialManager


func _build_world() -> void:
	add_room_bounds(Vector2i(-6, -6), 13, 13)
	ColorRestoration.clear_zones()
	ColorRestoration.set_global_gray(0.0)
	Audio.set_ambience(0.45, 0.0)

	_staff = spawn_prop("LEWET STAFF", Vector2(0.0, -4.0), {
		"texture_path": "res://assets/images/props/lewet_staff.png",
		"prop_size": Vector2(28.0, 100.0),
		"body_color": Color(0.68, 0.52, 0.24),
		"accent_color": Color(0.98, 0.86, 0.46),
		"float_amplitude": 4.0,
		"float_speed": 1.4,
		"show_label": false,
	})
	_staff_trigger = add_interactable("Take the Lewet Staff", Vector2(0.0, -3.3), {
		"one_shot": true,
		"radius": 70.0,
		"enabled": false,
	})

	_dress_room()
	_light_staff()

	if player != null:
		player.has_staff = false
		player.set_light_enabled(false)

	_tutorial = TutorialManager.new()
	_tutorial.name = "TutorialManager"
	add_child(_tutorial)
	_tutorial.setup(self, _staff, _staff_trigger)


func _dress_room() -> void:
	spawn_prop("SLEEPING MAT", Vector2(0.0, 3.0), {
		"texture_path": "res://assets/images/props/sleeping_mat.png",
		"prop_size": Vector2(90.0, 36.0),
		"body_color": Color(0.26, 0.24, 0.22),
		"accent_color": Color(0.4, 0.36, 0.3),
		"show_label": false,
	})
	spawn_prop("S'LANG'S BACKSTRAP LOOM", Vector2(-4.0, 0.0), {
		"texture_path": "res://assets/images/props/backstrap_loom.png",
		"prop_size": Vector2(96.0, 70.0),
		"body_color": Color(0.28, 0.25, 0.21),
		"accent_color": Color(0.46, 0.4, 0.3),
		"show_label": false,
	})
	spawn_prop("UNFINISHED T'NALAK", Vector2(4.0, 0.0), {
		"texture_path": "res://assets/images/props/unfinished_tnalak.png",
		"prop_size": Vector2(78.0, 58.0),
		"body_color": Color(0.31, 0.3, 0.28),
		"accent_color": Color(0.45, 0.43, 0.4),
		"show_label": false,
	})
	for x in range(-5, 6, 2):
		spawn_prop("WALL", Vector2(float(x), -6.0), {
			"texture_path": "res://assets/images/props/wall_panel.png",
			"prop_size": Vector2(72.0, 110.0),
			"body_color": Color(0.19, 0.18, 0.17),
			"accent_color": Color(0.3, 0.28, 0.26),
			"show_label": false,
			"cast_shadow": false,
		})


func _light_staff() -> void:
	if _staff == null:
		return
	var lamp := PointLight2D.new()
	lamp.name = "StaffGlow"
	lamp.color = Color(1.0, 0.86, 0.48)
	lamp.energy = 0.85
	lamp.texture_scale = 1.6
	lamp.position = Vector2(0.0, -48.0)
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	lamp.texture = tex
	_staff.add_child(lamp)


func _run_chapter() -> void:
	set_player_input(false)
	objective("Listen.")

	await say([
		"S'lang wakes on the mat where she fell asleep, in a room she has known her whole life.",
		{"speaker": "S'lang", "text": "The loom. The mat. Still here. And there — by the wall — the beater is waiting."},
	])

	_tutorial.begin()
	await _tutorial.finished

	set_player_input(false)
	GameState.unlock_lore("fun_kdungon")
	await _reveal_fun_kdungon()
	await say([
		{"speaker": "Fun Kdungon", "text": "A weaver's beater. Brass on one end, and my hand on the other. Where you carry it, colour follows — a little of it, for now."},
		{"speaker": "Fun Kdungon", "text": "Five houses stand on one highland. Four hold a thing that was lost. The fifth holds what took it."},
		{"speaker": "S'lang", "text": "Then I start at the first."},
	])

	objective("Walk the boardwalk and enter the House of the Black Foundation.")
	SceneFader.fade_to_scene(AccountManager.HUB_SCENE)


func _reveal_fun_kdungon() -> void:
	_goddess = spawn_prop("FUN KDUNGON", Vector2(-2.4, -3.2), {
		"texture_path": "res://assets/images/characters/fun_kdungon.png",
		"prop_size": Vector2(78.0, 130.0),
		"body_color": Palette.BLACK_CHARCOAL,
		"accent_color": Palette.GOLD_SACRED,
		"float_amplitude": 2.2,
		"float_speed": 0.7,
		"show_label": false,
		"blocks_movement": false,
		"cast_shadow": true,
	})
	_goddess.modulate.a = 0.0
	ColorRestoration.add_zone("fun_kdungon", _goddess, 210.0, 1.0)
	var lamp := PointLight2D.new()
	lamp.name = "GoddessLight"
	lamp.color = Color(1.0, 0.86, 0.48)
	lamp.energy = 1.1
	lamp.texture_scale = 2.4
	lamp.position = Vector2(0.0, -96.0)
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	lamp.texture = tex
	_goddess.add_child(lamp)
	var arrive := create_tween()
	arrive.tween_property(_goddess, "modulate:a", 1.0, 0.9)\
		.set_ease(Tween.EASE_OUT)
	await arrive.finished
