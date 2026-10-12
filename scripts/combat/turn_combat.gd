extends CanvasLayer
## Pokémon-style turn battles.
##
## When S'lang meets a shadow on the ridge, the chapter freezes, a separate
## battle screen flashes in, and turns play out there. Win or lose, the ridge
## returns — defeated shadows are gone from the overworld.

signal battle_finished(won: bool)

const LAYER := 120
const PLAYER_STRIKE := 32.0
const PLAYER_CHIME := 20.0
const SLANG_TEX := "res://assets/images/characters/slang.png"
const SHADOW_TEX := "res://assets/images/enemies/shadow_minion.png"

var _busy := false
var _player: Slang
var _world_foes: Array[ShadowMinion] = []
var _foes: Array[Dictionary] = []
var _focus := 0
var _chime_ready := true
var _pending_action := ""
var _host_scene: Node
var _host_mode := Node.PROCESS_MODE_INHERIT

var _root: Control
var _flash: ColorRect
var _enemy_stage: Control
var _player_stage: Control
var _player_sprite: TextureRect
var _player_hp: ProgressBar
var _player_hp_label: Label
var _msg: Label
var _prompt: Label
var _cmd_row: HBoxContainer
var _strike_btn: Button
var _chime_btn: Button


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_screen()


func is_busy() -> bool:
	return _busy


## Retired overlay. Fights now happen on the ridge. Kept so old callers cannot freeze the game.
func run(_player: Slang, _foes: Array) -> bool:
	return true


func _freeze_chapter(frozen: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if frozen:
		_host_scene = scene
		_host_mode = scene.process_mode
		scene.process_mode = Node.PROCESS_MODE_DISABLED
	elif _host_scene != null and is_instance_valid(_host_scene):
		_host_scene.process_mode = _host_mode
		_host_scene = null


func _battle_loop() -> bool:
	while _busy and _player_alive():
		_prune_foes()
		if _foes.is_empty():
			_refresh_all("The shadows unravel into loose thread.")
			_set_prompt("")
			_cmd_row.visible = false
			await _wait(1.0)
			return true

		_focus = clampi(_focus, 0, _foes.size() - 1)
		_refresh_all("Your turn.")
		_set_prompt("Choose a move.")
		_cmd_row.visible = true
		_chime_btn.disabled = not _chime_ready
		_chime_btn.text = "CHIME  [Q]" if _chime_ready else "CHIME (recharging)"

		var action := await _await_command()
		_cmd_row.visible = false
		if not _busy:
			return false

		match action:
			"strike":
				await _do_strike()
			"chime":
				await _do_chime()

		_prune_foes()
		if _foes.is_empty():
			_refresh_all("The shadows unravel into loose thread.")
			await _wait(0.9)
			return true
		if not _player_alive():
			return false

		for i in range(_foes.size()):
			await _enemy_turn(i)
			if not _player_alive():
				return false

	return false


func _await_command() -> String:
	_pending_action = ""
	while _busy:
		await get_tree().process_frame
		if not _player_alive():
			return ""
		if not _pending_action.is_empty():
			var pick := _pending_action
			_pending_action = ""
			return pick
		if Input.is_action_just_pressed("attack"):
			return "strike"
		if Input.is_action_just_pressed("ability") and _chime_ready:
			return "chime"
	return ""


func _do_strike() -> void:
	_prune_foes()
	if _foes.is_empty():
		return
	_focus = clampi(_focus, 0, _foes.size() - 1)
	var foe: Dictionary = _foes[_focus]
	Audio.play_sfx(Audio.Sfx.HIT)
	if _enemy_stage.get_child_count() > _focus:
		var slot := _enemy_stage.get_child(_focus) as Control
		if slot != null:
			slot.modulate = Color(1.6, 1.3, 0.85)
			var flash := create_tween()
			flash.tween_property(slot, "modulate", Color.WHITE, 0.18)
		await _bump(_enemy_stage.get_child(_focus) as Control, Vector2(-18, 0))
	foe["hp"] = maxf(0.0, float(foe["hp"]) - PLAYER_STRIKE)
	_foes[_focus] = foe
	_refresh_all("S'lang strikes with the Lewet Staff!")
	await _wait(0.55)
	if float(foe["hp"]) <= 0.0:
		_refresh_all("%s faded." % str(foe["name"]))
		await _fade_enemy_out(_focus)
		await _wait(0.35)


func _do_chime() -> void:
	if not _chime_ready:
		_refresh_all("The chime is still gathering.")
		await _wait(0.35)
		return
	_chime_ready = false
	Audio.play_sfx(Audio.Sfx.CHIME)
	await _bump(_player_stage, Vector2(14, -6))
	for i in range(_foes.size()):
		var foe: Dictionary = _foes[i]
		foe["hp"] = maxf(0.0, float(foe["hp"]) - PLAYER_CHIME)
		_foes[i] = foe
	_refresh_all("The Lewet Staff sings. Every shadow reels!")
	await _wait(0.7)
	for i in range(_foes.size() - 1, -1, -1):
		if float(_foes[i]["hp"]) <= 0.0:
			_refresh_all("%s faded." % str(_foes[i]["name"]))
			await _fade_enemy_out(i)
	await _wait(0.25)


func _enemy_turn(index: int) -> void:
	if index < 0 or index >= _foes.size():
		return
	var foe: Dictionary = _foes[index]
	_refresh_all("%s lunges!" % str(foe["name"]))
	_set_prompt("")
	await _wait(0.35)
	if not _player_alive():
		return
	Audio.play_sfx(Audio.Sfx.THUD)
	if _player_stage != null:
		_player_stage.modulate = Color(1.5, 0.7, 0.65)
		var hurt := create_tween()
		hurt.tween_property(_player_stage, "modulate", Color.WHITE, 0.22)
	if _enemy_stage.get_child_count() > index:
		await _bump(_enemy_stage.get_child(index) as Control, Vector2(22, 8))
	_player.take_damage(float(foe["damage"]), null)
	_refresh_hp()
	_refresh_all("S'lang takes the hit!")
	await _wait(0.55)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _transition_in() -> void:
	visible = true
	_root.modulate.a = 1.0
	_flash.modulate.a = 1.0
	_flash.visible = true
	for _i in range(3):
		_flash.color = Color(0.02, 0.02, 0.03, 1)
		await _wait(0.06)
		_flash.color = Color(0.75, 0.12, 0.1, 1)
		await _wait(0.06)
	_flash.color = Color(0.04, 0.03, 0.05, 1)
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35)
	await tween.finished
	_flash.visible = false


func _transition_out(won: bool) -> void:
	_cmd_row.visible = false
	_flash.visible = true
	_flash.modulate.a = 0.0
	_flash.color = Color(0.04, 0.03, 0.05, 1) if won else Color(0.15, 0.02, 0.02, 1)
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 1.0, 0.4)
	await tween.finished


func _finish(won: bool) -> void:
	visible = false
	_flash.visible = false
	_clear_enemy_stage()
	_freeze_chapter(false)

	if won:
		for foe in _world_foes:
			if foe != null and is_instance_valid(foe):
				foe.defeat_from_battle()
	else:
		for foe in _world_foes:
			if foe != null and is_instance_valid(foe):
				foe.exit_battle_stance()

	if _player != null and is_instance_valid(_player) and not _player.is_dead():
		_player.set_input_enabled(true)

	_player = null
	_world_foes.clear()
	_foes.clear()
	_busy = false


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and not _player.is_dead()


func _prune_foes() -> void:
	var kept: Array[Dictionary] = []
	for foe in _foes:
		if float(foe.get("hp", 0.0)) > 0.0:
			kept.append(foe)
	_foes = kept
	if _focus >= _foes.size():
		_focus = maxi(0, _foes.size() - 1)
	_layout_fighters()
	_refresh_hp()


func _refresh_all(message: String) -> void:
	_msg.text = message
	_refresh_hp()


func _refresh_hp() -> void:
	if _player != null and is_instance_valid(_player):
		_player_hp.max_value = _player.max_health
		_player_hp.value = _player.health
		_player_hp_label.text = "S'lang   %d / %d" % [int(ceil(_player.health)), int(ceil(_player.max_health))]
	for i in range(_enemy_stage.get_child_count()):
		var slot := _enemy_stage.get_child(i) as Control
		if slot == null or i >= _foes.size():
			continue
		var bar := slot.get_node_or_null("Hp") as ProgressBar
		var label := slot.get_node_or_null("Name") as Label
		var foe: Dictionary = _foes[i]
		if bar != null:
			bar.max_value = float(foe["max_hp"])
			bar.value = float(foe["hp"])
		if label != null:
			var mark := "▸ " if i == _focus else ""
			label.text = "%s%s  %d/%d" % [
				mark, str(foe["name"]),
				int(ceil(float(foe["hp"]))), int(ceil(float(foe["max_hp"])))
			]


func _set_prompt(text: String) -> void:
	_prompt.text = text


func _layout_fighters() -> void:
	_clear_enemy_stage()
	for i in range(_foes.size()):
		_enemy_stage.add_child(_make_enemy_slot())
	_player_sprite.texture = _load_tex(SLANG_TEX)
	_refresh_hp()


func _clear_enemy_stage() -> void:
	for child in _enemy_stage.get_children():
		child.queue_free()


func _make_enemy_slot() -> Control:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(160.0, 180.0)
	slot.alignment = BoxContainer.ALIGNMENT_END
	slot.add_theme_constant_override("separation", 6)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Palette.CREAM_WARP)
	slot.add_child(name_l)

	var bar := ProgressBar.new()
	bar.name = "Hp"
	bar.custom_minimum_size = Vector2(140.0, 14.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiStyle.bar_track())
	bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.RED_SACRED))
	slot.add_child(bar)

	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(120.0, 140.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = _load_tex(SHADOW_TEX)
	art.modulate = Color(0.85, 0.8, 0.95)
	slot.add_child(art)
	return slot


func _fade_enemy_out(index: int) -> void:
	if index < 0 or index >= _enemy_stage.get_child_count():
		return
	var slot := _enemy_stage.get_child(index) as Control
	if slot == null:
		return
	var tween := create_tween()
	tween.tween_property(slot, "modulate:a", 0.0, 0.35)
	await tween.finished


func _bump(node: Control, offset: Vector2) -> void:
	if node == null:
		return
	var origin := node.position
	var tween := create_tween()
	tween.tween_property(node, "position", origin + offset, 0.08)
	tween.tween_property(node, "position", origin, 0.12)
	await tween.finished


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded
	return null


func _on_strike_pressed() -> void:
	_pending_action = "strike"


func _on_chime_pressed() -> void:
	if _chime_ready:
		_pending_action = "chime"


func _build_screen() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Palette.DREAM_NIGHT
	_root.add_child(backdrop)

	var motes := LightMotes.new()
	motes.mote_count = 20
	_root.add_child(motes)

	var ground := ColorRect.new()
	ground.color = Palette.DREAM_INDIGO
	ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -300.0
	_root.add_child(ground)

	var ground_rim := ColorRect.new()
	ground_rim.color = Palette.alpha(Palette.GOLD_BRASS, 0.35)
	ground_rim.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ground_rim.offset_top = -302.0
	ground_rim.offset_bottom = -300.0
	_root.add_child(ground_rim)

	_enemy_stage = HBoxContainer.new()
	_enemy_stage.alignment = BoxContainer.ALIGNMENT_END
	_enemy_stage.add_theme_constant_override("separation", 18)
	_enemy_stage.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_stage.offset_left = -520.0
	_enemy_stage.offset_top = 48.0
	_enemy_stage.offset_right = -40.0
	_enemy_stage.offset_bottom = 280.0
	_root.add_child(_enemy_stage)

	_player_stage = VBoxContainer.new()
	_player_stage.add_theme_constant_override("separation", 8)
	_player_stage.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_player_stage.offset_left = 48.0
	_player_stage.offset_top = -420.0
	_player_stage.offset_right = 260.0
	_player_stage.offset_bottom = -200.0
	_root.add_child(_player_stage)

	_player_hp_label = Label.new()
	_player_hp_label.add_theme_font_size_override("font_size", 15)
	_player_hp_label.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	_player_stage.add_child(_player_hp_label)

	_player_hp = ProgressBar.new()
	_player_hp.custom_minimum_size = Vector2(180.0, 16.0)
	_player_hp.show_percentage = false
	_player_hp.add_theme_stylebox_override("background", UiStyle.bar_track())
	_player_hp.add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.RED_SACRED))
	_player_stage.add_child(_player_hp)

	_player_sprite = TextureRect.new()
	_player_sprite.custom_minimum_size = Vector2(140.0, 180.0)
	_player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_stage.add_child(_player_sprite)

	var plate := WovenFrame.new()
	plate.pad = 18
	plate.lit = true
	plate.draw_kleng = true
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_left = 48.0
	plate.offset_right = -48.0
	plate.offset_top = -200.0
	plate.offset_bottom = -28.0
	_root.add_child(plate)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	plate.add_child(col)

	var title := Label.new()
	title.text = "SHADOW BATTLE"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	col.add_child(title)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(0.0, 48.0)
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.add_theme_color_override("font_color", Color(0.98, 0.95, 0.9))
	_msg.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.02, 0.92))
	_msg.add_theme_constant_override("outline_size", 8)
	col.add_child(_msg)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.84, 0.5, 0.95))
	_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.02, 0.85))
	_prompt.add_theme_constant_override("outline_size", 5)
	col.add_child(_prompt)

	_cmd_row = HBoxContainer.new()
	_cmd_row.add_theme_constant_override("separation", 20)
	_cmd_row.visible = false
	col.add_child(_cmd_row)

	_strike_btn = _make_cmd("STRIKE  ·  Space", _on_strike_pressed)
	_chime_btn = _make_cmd("CHIME  ·  Q", _on_chime_pressed)
	_cmd_row.add_child(_strike_btn)
	_cmd_row.add_child(_chime_btn)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Palette.DREAM_ABYSS
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	_root.add_child(_flash)


func _make_cmd(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.theme_type_variation = &"GhostButton"
	btn.custom_minimum_size = Vector2(160.0, 40.0)
	btn.pressed.connect(cb)
	return btn
