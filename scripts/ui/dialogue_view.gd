class_name DialogueView
extends CanvasLayer
## Reusable dialogue box for NPCs, the Narrator, and branching choices.
##
## Chapters await it directly:
##     await dialogue.play([
##         {"speaker": "Spirit of the Fiber", "text": "I have forgotten..."},
##         "A line with no speaker is narration.",
##         {"speaker": "The Shadow Weaver", "text": "...", "voice": "weaver_intro_1"},
##     ])
## A "voice" names a clip in assets/audio/voice/ that plays with the line.
##     var pick := await dialogue.ask("Which thread?", ["Black", "Red"])
##
## Lines type on with visible_characters (not visible_ratio) so autowrap never
## clips mid-word into "Five hous".

signal finished
signal choice_made(index: int)

const CHARS_PER_SECOND := 48.0

@onready var panel: Control = %Panel
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var continue_hint: Label = %ContinueHint
@onready var choice_box: VBoxContainer = %ChoiceBox
@onready var portrait: TextureRect = %Portrait
@onready var dock: Control = $Root/Dock

var _typing: Tween
var _awaiting_advance := false
var _advance_requested := false
var _choosing := false
var _line_length := 0
var _presented := false
var _hint_tween: Tween
static var _bust_cache: Dictionary = {}


func _ready() -> void:
	layer = 115
	visible = false
	choice_box.visible = false
	add_to_group("dialogue_view")
	if panel is WovenFrame:
		(panel as WovenFrame).set_quiet(true)
	if portrait != null:
		var well := portrait.get_parent() as PanelContainer
		if well != null:
			well.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			well.clip_contents = true
			well.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_advance or event.is_echo():
		return
	var advance := event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("interact") \
		or event.is_action_pressed("attack")
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		advance = advance or (mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if advance:
		get_viewport().set_input_as_handled()
		_advance_requested = true


func play(lines: Array) -> void:
	visible = true
	choice_box.visible = false
	_present()
	for line in lines:
		var speaker := ""
		var body := ""
		var voice := ""
		if typeof(line) == TYPE_DICTIONARY:
			speaker = str((line as Dictionary).get("speaker", ""))
			body = str((line as Dictionary).get("text", ""))
			voice = str((line as Dictionary).get("voice", ""))
		else:
			body = str(line)
		if not voice.is_empty():
			Audio.play_voice(voice)
		await _show_line(speaker, body)
		if not voice.is_empty():
			Audio.stop_voice()
	visible = false
	_presented = false
	finished.emit()


func ask(prompt: String, options: Array, speaker := "") -> int:
	visible = true
	_present()
	await _show_line(speaker, prompt, false)

	_build_choices(options)
	_choosing = true
	var pick: int = await choice_made
	choice_box.visible = false
	visible = false
	_presented = false
	return pick


func say_line(speaker: String, body: String) -> void:
	visible = true
	choice_box.visible = false
	_present()
	await _show_line(speaker, body)
	visible = false
	_presented = false


func is_busy() -> bool:
	return visible


func _show_line(speaker: String, body: String, wait_for_input := true) -> void:
	speaker_label.text = speaker.to_upper() if not speaker.is_empty() else "NARRATOR"
	speaker_label.visible = true
	_style_speaker(speaker)
	_set_portrait(speaker)
	text_label.text = body
	_line_length = body.length()
	text_label.visible_characters = 0
	continue_hint.text = "E  ·  continue"
	continue_hint.visible = wait_for_input
	_pulse_hint(false)

	_start_typing()
	if not wait_for_input:
		await _wait_for_typing()
		return

	_awaiting_advance = true
	_advance_requested = false

	while true:
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
		if _advance_requested:
			_advance_requested = false
			if text_label.visible_characters >= 0 and text_label.visible_characters < _line_length:
				_kill_typing()
				text_label.visible_characters = -1
			else:
				break
		elif _typing == null and (text_label.visible_characters < 0 \
				or text_label.visible_characters >= _line_length):
			continue_hint.text = "E  ·  continue  ▸"
			_pulse_hint(true)

	_awaiting_advance = false


func _wait_for_typing() -> void:
	while _typing != null:
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame


func _start_typing() -> void:
	_kill_typing()
	text_label.visible_characters = 0
	if _line_length <= 0:
		text_label.visible_characters = -1
		return
	var duration := clampf(float(_line_length) / CHARS_PER_SECOND, 0.2, 5.5)
	_typing = create_tween()
	_typing.tween_method(_set_visible_chars, 0, _line_length, duration)
	_typing.tween_callback(func() -> void:
		text_label.visible_characters = -1
		_typing = null
	)


func _set_visible_chars(count: int) -> void:
	text_label.visible_characters = count


func _kill_typing() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null


func _build_choices(options: Array) -> void:
	for child in choice_box.get_children():
		child.queue_free()

	for i in range(options.size()):
		var button := Button.new()
		button.text = "✦   %s" % str(options[i])
		button.theme_type_variation = &"GhostButton"
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		choice_box.add_child(button)
	choice_box.visible = true
	UiMotion.cascade(choice_box, 0.0, UiMotion.FAST, 8.0, 0.04)


func _present() -> void:
	if _presented or dock == null:
		return
	_presented = true
	var home := dock.position
	dock.position = home + Vector2(0.0, 28.0)
	dock.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(dock, "modulate:a", 1.0, UiMotion.BASE)
	tween.tween_property(dock, "position", home, UiMotion.SLOW)


func _pulse_hint(on: bool) -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	if not on or continue_hint == null:
		if continue_hint != null:
			continue_hint.modulate.a = 0.75
		return
	_hint_tween = UiMotion.shimmer(continue_hint, 0.4, 1.0, 1.4)


func _style_speaker(speaker: String) -> void:
	var key := speaker.to_lower()
	var color := Palette.GOLD_SACRED
	if speaker.is_empty():
		color = Palette.CREAM_STONE
	elif "fun kdungon" in key:
		color = Palette.GOLD_SUN
	elif "spirit" in key:
		color = Palette.DREAM_AURORA
	elif "harvest" in key:
		color = Color(0.78, 0.32, 0.18)
	elif "chief" in key:
		color = Palette.GOLD_BRASS
	elif "master" in key or "ancestor" in key:
		color = Palette.GOLD_SUN
	elif "shadow" in key:
		color = Palette.DREAM_MIST
	elif "s'lang" in key or "slang" in key:
		color = Palette.GOLD_BRASS
	speaker_label.add_theme_color_override("font_color", Palette.alpha(color, 0.95))


func _set_portrait(speaker: String) -> void:
	if portrait == null:
		return
	var path := _portrait_path(speaker)
	var tex := _bust_texture(path, speaker)
	portrait.texture = tex
	portrait.visible = tex != null
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var well := portrait.get_parent() as CanvasItem
	if well != null and well != panel:
		well.visible = tex != null
	if tex != null:
		var key := speaker.to_lower()
		portrait.custom_minimum_size = Vector2(108, 148)
		if "spirit" in key:
			portrait.modulate = Color(0.92, 0.95, 1.05, 0.92)
		elif "shadow" in key:
			portrait.modulate = Color(0.96, 0.9, 1.0)
		else:
			portrait.modulate = Color.WHITE


func _portrait_path(speaker: String) -> String:
	var key := speaker.to_lower()
	if key.is_empty():
		return ""
	if "s'lang" in key or key == "slang":
		return "res://assets/images/characters/slang.png"
	if "fun kdungon" in key:
		return "res://assets/images/characters/fun_kdungon.png"
	if "chief" in key:
		return "res://assets/images/characters/the_chief.png"
	if "harvest" in key:
		return "res://assets/images/characters/harvest_queen.png"
	if "spirit" in key:
		return "res://assets/images/characters/spirit_of_the_fiber.png"
	if "master" in key:
		return "res://assets/images/characters/master_weaver_ghost_portrait.png"
	if "shadow" in key or "weaver" in key:
		return "res://assets/images/enemies/shadow_weaver_idle.png"
	return "res://assets/images/characters/slang.png"


const _WELL_ASPECT := 108.0 / 148.0
const _BUST_FRACTION := 0.5


func _bust_texture(path: String, speaker: String) -> Texture2D:
	if path.is_empty():
		return null
	if _bust_cache.has(path):
		return _bust_cache[path] as Texture2D
	var image := Palette.read_image(path)
	if image == null:
		return null
	# The portrait well is tiny. Keying a full 864×1152 plate on the speak
	# frame freezes the game, so shrink before any per-pixel pass.
	const MAX_H := 220
	if image.get_height() > MAX_H:
		var scale := float(MAX_H) / float(image.get_height())
		var next_w := maxi(8, int(round(float(image.get_width()) * scale)))
		image.resize(next_w, MAX_H, Image.INTERPOLATE_BILINEAR)
	if _uses_studio_plate(path, speaker):
		PlaceholderProp.key_backdrop(image)
	if "shadow_weaver" in path:
		image = _first_strip_frame(image, 8)
		_key_edge_plate(image)
	var bust := _crop_id_bust(image)
	var tex := ImageTexture.create_from_image(bust)
	_bust_cache[path] = tex
	return tex


func _uses_studio_plate(path: String, speaker: String) -> bool:
	var key := (path + " " + speaker).to_lower()
	return "characters/" in key or "kdungon" in key or "chief" in key \
		or "harvest" in key or "queen" in key


func _first_strip_frame(image: Image, frames: int) -> Image:
	if frames < 2:
		return image
	var cell_w := maxi(1, int(image.get_width() / float(frames)))
	if cell_w >= image.get_width():
		return image
	return image.get_region(Rect2i(0, 0, cell_w, image.get_height()))


func _key_edge_plate(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	if w < 2 or h < 2:
		return
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
		var index := point.y * w + point.x
		if seen[index] == 1:
			continue
		seen[index] = 1
		if not _is_edge_plate(image.get_pixelv(point)):
			continue
		image.set_pixelv(point, Color.TRANSPARENT)
		pending.append(point + Vector2i.RIGHT)
		pending.append(point + Vector2i.LEFT)
		pending.append(point + Vector2i.DOWN)
		pending.append(point + Vector2i.UP)


func _is_edge_plate(color: Color) -> bool:
	if color.a < 0.08:
		return true
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var chroma := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
	return luma < 0.07 and chroma < 0.06


func _crop_id_bust(image: Image) -> Image:
	var bounds := image.get_used_rect()
	if bounds.size.x < 8 or bounds.size.y < 8:
		return image
	var bust_h := maxi(8, int(round(float(bounds.size.y) * _BUST_FRACTION)))
	var bust_w := maxi(8, int(round(float(bust_h) * _WELL_ASPECT)))
	bust_w = mini(bust_w, image.get_width())
	bust_h = mini(bust_h, image.get_height())
	var head_h := maxi(4, int(round(float(bounds.size.y) * 0.34)))
	var head := Rect2i(bounds.position.x, bounds.position.y, bounds.size.x, mini(head_h, bounds.size.y))
	var face_x := _head_center_x(image, head, float(bounds.position.x) + float(bounds.size.x) * 0.5)
	var x := clampi(int(round(face_x - float(bust_w) * 0.5)), 0, image.get_width() - bust_w)
	var y := clampi(bounds.position.y, 0, image.get_height() - bust_h)
	return image.get_region(Rect2i(x, y, bust_w, bust_h))


## Longest solid run in the head band. A staff is a thin column and loses.
func _head_center_x(image: Image, head: Rect2i, fallback: float) -> float:
	var data := image.get_data()
	var stride := image.get_width()
	var best_start := -1
	var best_len := 0
	var run_start := -1
	var y_step := 2 if head.size.y > 80 else 1
	for x in range(head.position.x, head.position.x + head.size.x):
		var hit := false
		var y := head.position.y
		var y_end := head.position.y + head.size.y
		while y < y_end:
			var index := (y * stride + x) * 4 + 3
			if index < data.size() and data[index] > 51:
				hit = true
				break
			y += y_step
		if hit:
			if run_start < 0:
				run_start = x
		elif run_start >= 0:
			var length := x - run_start
			if length > best_len:
				best_len = length
				best_start = run_start
			run_start = -1
	if run_start >= 0:
		var tail := head.position.x + head.size.x - run_start
		if tail > best_len:
			best_len = tail
			best_start = run_start
	if best_start < 0 or best_len < 4:
		return fallback
	return float(best_start) + float(best_len) * 0.5


func _on_choice_pressed(index: int) -> void:
	if not _choosing:
		return
	_choosing = false
	Audio.play_sfx(Audio.Sfx.PICKUP)
	choice_made.emit(index)
