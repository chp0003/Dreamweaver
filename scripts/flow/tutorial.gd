extends ChapterBase
## Tutorial - "S'lang's Awakening".
##
## The cutscene letterbox lifts, the camera hands control over, and the only
## object in a fully bleached room that still has colour is the Lewet Staff.
## Taking it teaches WASD and [E], equips the weapon, and opens the Hub.

var _staff: PlaceholderProp
var _staff_trigger: Interactable
var _goddess: PlaceholderProp
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _move_hint: Label
var _has_moved := false


func _build_world() -> void:
	add_room_bounds(Vector2i(-6, -6), 13, 13)

	_staff = spawn_prop("LEWET STAFF", Vector2(0.0, -4.0), {
		"texture_path": "res://assets/images/props/lewet_staff.png",
		"prop_size": Vector2(28.0, 100.0),
		"body_color": Color(0.68, 0.52, 0.24),
		"accent_color": Color(0.98, 0.86, 0.46),
		"float_amplitude": 4.0,
		"float_speed": 1.4,
		"show_label": false,
	})
	_staff_trigger = add_interactable("Take the Lewet Staff", Vector2(0.0, -3.3),
		{"one_shot": true, "radius": 70.0})

	# The staff is the one thing in the room the forgetting did not reach.
	ColorRestoration.add_zone("lewet_staff", _staff, 120.0, 1.0)

	_dress_room()
	_build_letterbox()
	_build_move_hint()


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


## Cinematic bars left over from the prologue, retracted on the first beat.
## Own canvas layer under the HUD so objective / vitality stay readable.
func _build_letterbox() -> void:
	var box_layer := CanvasLayer.new()
	box_layer.layer = 108
	box_layer.name = "LetterboxLayer"
	add_child(box_layer)

	_letterbox_top = ColorRect.new()
	_letterbox_top.color = Color(0.02, 0.015, 0.02)
	_letterbox_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_bottom = 72.0
	_letterbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_layer.add_child(_letterbox_top)

	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.color = Color(0.02, 0.015, 0.02)
	_letterbox_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = -72.0
	_letterbox_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_layer.add_child(_letterbox_bottom)


func _build_move_hint() -> void:
	_move_hint = Label.new()
	_move_hint.text = "W  A  S  D    move toward the glowing staff"
	_move_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_move_hint.offset_left = -380.0
	_move_hint.offset_right = 380.0
	_move_hint.offset_top = -120.0
	_move_hint.offset_bottom = -72.0
	_move_hint.add_theme_font_size_override("font_size", 18)
	_move_hint.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78, 0.95))
	_move_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.02, 0.9))
	_move_hint.add_theme_constant_override("outline_size", 8)
	_move_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_hint.modulate.a = 0.0
	ui_layer.add_child(_move_hint)


func _process(delta: float) -> void:
	super._process(delta)
	if _has_moved or player == null or not is_instance_valid(player):
		return
	if player.velocity.length() > 20.0:
		_has_moved = true
		_fade_hint_out()


# --------------------------------------------------------------------------

func _run_chapter() -> void:
	set_player_input(false)
	Audio.set_ambience(0.45, 0.0)
	objective("Wake in the bleached room.")

	await say([
		"S'lang wakes on the mat where she fell asleep, in a room she has known her whole life, and cannot find a single colour in it.",
		{"speaker": "S'lang", "text": "The cloth on the loom. The mat. My own hands. All of it gray."},
		{"speaker": "S'lang", "text": "Except - there. By the wall. Something is still gold."},
	])

	# Letterbox retracts and the camera becomes the player's.
	var open := create_tween()
	open.set_parallel(true)
	open.tween_property(_letterbox_top, "offset_bottom", 0.0, 0.9)
	open.tween_property(_letterbox_bottom, "offset_top", 0.0, 0.9)
	await open.finished

	set_player_input(true)
	objective("Move to the glowing Lewet Staff.")

	var hint_in := create_tween()
	hint_in.tween_property(_move_hint, "modulate:a", 1.0, 0.5)

	await until(func() -> bool: return _staff_trigger.is_player_inside())
	_fade_hint_out()
	_show_hint("[E]  take the Lewet Staff")
	objective("Take the Lewet Staff. [E]")

	await _staff_trigger.interacted
	_fade_hint_out()

	set_player_input(false)
	if player != null:
		player.equip_staff()
	Audio.play_sfx(Audio.Sfx.CHIME)
	banner("The Lewet Staff", 2.0)

	# The staff's colour now travels with S'lang instead of sitting on the floor.
	ColorRestoration.remove_zone("lewet_staff")
	ColorRestoration.add_zone("staff_carried", player, 150.0, 1.0)
	_staff.queue_free()

	GameState.unlock_lore("lewet_staff")
	GameState.unlock_lore("fun_kdungon")
	GameState.add_score(200)
	GameState.unlock_house(1)

	await _reveal_fun_kdungon()
	await say([
		{"speaker": "Fun Kdungon", "text": "A weaver's beater. Brass on one end, and my hand on the other. Where you carry it, colour follows - a little of it, for now."},
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


func _show_hint(text: String) -> void:
	_move_hint.text = text
	var tween := create_tween()
	tween.tween_property(_move_hint, "modulate:a", 1.0, 0.35)


func _fade_hint_out() -> void:
	var tween := create_tween()
	tween.tween_property(_move_hint, "modulate:a", 0.0, 0.4)
