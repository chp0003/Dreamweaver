extends Control
## Cinematic prologue. Returning weavers skip this via AccountManager.

const CHARS_PER_SECOND := 52.0
const SLIDE_FADE := 0.45

const SLIDES: Array[Dictionary] = [
	{
		"chapter": "PROLOGUE  ·  I",
		"title": "The Golden Era",
		"texture": "res://assets/images/story/intro_01_golden_era.png",
		"text": "Long ago, our world was a living tapestry. Every thread held a story, and every vibrant color—the deep blacks, the bright reds, the shining golds—was a sign of life and heritage.",
		"pan": Vector2(1.04, 1.04),
	},
	{
		"chapter": "PROLOGUE  ·  II",
		"title": "The Covenant of the Loom",
		"texture": "res://assets/images/story/intro_02_covenant_loom.png",
		"text": "The spirits blessed our weavers with sacred dreams (damgo), guiding our hands to create the T’nalak cloth. We were the guardians of these colors, keeping our culture alive through every stitch.",
		"pan": Vector2(1.05, 1.03),
	},
	{
		"chapter": "PROLOGUE  ·  III",
		"title": "The Great Bleaching",
		"texture": "res://assets/images/story/intro_03_great_bleaching.png",
		"text": "But as time passed, a shadow crept in—the Shadow of Forgetfulness. We began to neglect our traditions and forgot the old ways. When we stopped caring for our heritage, the spirits grew silent. The colors fled. Our world unraveled into gray.",
		"pan": Vector2(1.06, 1.04),
	},
	{
		"chapter": "PROLOGUE  ·  IV",
		"title": "The Last Spark",
		"texture": "res://assets/images/story/intro_04_last_spark.png",
		"text": "The colors... they're gone. The loom is silent. How can I weave a dream when the world itself has unraveled?\n\nThe bleaching has taken everyone, S'lang. But the rhythm still beats in you. Enter the ancestral houses, gather the lost essences, and weave the colors back to life.",
		"pan": Vector2(1.03, 1.05),
	},
]

@onready var art_host: Control = %ArtHost
@onready var art: TextureRect = %Art
@onready var chapter_label: Label = %ChapterLabel
@onready var title_label: Label = %TitleLabel
@onready var narration_label: Label = %NarrationLabel
@onready var continue_hint: Label = %ContinueHint
@onready var progress_dots: Control = %ProgressDots
@onready var skip_button: Button = %SkipButton
@onready var caption: Control = %Caption

var _index: int = 0
var _typing: Tween
var _slide_busy: bool = false
var _hint_tween: Tween
var _ken_burns: Tween
var _line_length: int = 0


func _ready() -> void:
	skip_button.pressed.connect(_finish_intro)
	_set_progress(0)
	_pulse_hint()
	_show_slide(0, false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _can_advance(event):
		accept_event()
		_on_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _can_advance(event):
		get_viewport().set_input_as_handled()
		_on_advance()
	elif event.is_action_pressed("interact") and _can_advance(event):
		get_viewport().set_input_as_handled()
		_on_advance()


func _can_advance(event: InputEvent) -> bool:
	if SceneFader.is_busy() or _slide_busy or event.is_echo():
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	return false


func _on_advance() -> void:
	if _is_typing():
		_complete_text()
		return
	if _index >= SLIDES.size() - 1:
		_finish_intro()
		return
	_show_slide(_index + 1, true)


func _show_slide(index: int, animate: bool) -> void:
	_index = index
	_set_progress(_index)
	continue_hint.text = "Continue  →" if _index < SLIDES.size() - 1 else "Take up the Lewet Staff  →"

	if animate:
		_slide_busy = true
		var fade_out := create_tween()
		fade_out.set_parallel(true)
		fade_out.tween_property(art, "modulate:a", 0.0, SLIDE_FADE)
		fade_out.tween_property(caption, "modulate:a", 0.0, SLIDE_FADE * 0.85)
		await fade_out.finished
		if not is_inside_tree():
			return

	_apply_slide(SLIDES[_index])
	_start_ken_burns(SLIDES[_index].get("pan", Vector2(1.04, 1.04)))

	if animate:
		art.modulate.a = 0.0
		caption.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.set_parallel(true)
		fade_in.tween_property(art, "modulate:a", 1.0, SLIDE_FADE)
		fade_in.tween_property(caption, "modulate:a", 1.0, SLIDE_FADE + 0.1)\
			.set_ease(Tween.EASE_OUT)
		await fade_in.finished
		if not is_inside_tree():
			return
		_slide_busy = false

	_start_typewriter()


func _apply_slide(slide: Dictionary) -> void:
	var path := str(slide["texture"])
	var loaded := load(path)
	if loaded is Texture2D:
		art.texture = loaded
	chapter_label.text = str(slide.get("chapter", ""))
	title_label.text = str(slide.get("title", ""))
	narration_label.text = str(slide["text"])
	_line_length = narration_label.text.length()
	narration_label.visible_characters = 0


func _start_ken_burns(target_scale: Vector2) -> void:
	if _ken_burns != null and _ken_burns.is_valid():
		_ken_burns.kill()
	await get_tree().process_frame
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2(1.02, 1.02)
	_ken_burns = create_tween()
	_ken_burns.tween_property(art, "scale", target_scale, 14.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _start_typewriter() -> void:
	_kill_typing()
	narration_label.visible_characters = 0
	if _line_length <= 0:
		narration_label.visible_characters = -1
		return
	var duration := clampf(float(_line_length) / CHARS_PER_SECOND, 0.8, 8.0)
	_typing = create_tween()
	_typing.tween_method(_set_visible_chars, 0, _line_length, duration)
	_typing.tween_callback(func() -> void:
		narration_label.visible_characters = -1
		_typing = null
	)


func _set_visible_chars(count: int) -> void:
	narration_label.visible_characters = count


func _complete_text() -> void:
	_kill_typing()
	narration_label.visible_characters = -1


func _is_typing() -> bool:
	return narration_label.visible_characters >= 0 \
		and narration_label.visible_characters < _line_length


func _kill_typing() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null


func _set_progress(slide_index: int) -> void:
	if progress_dots != null and progress_dots.has_method("set_progress"):
		progress_dots.call("set_progress", slide_index, SLIDES.size())


func _pulse_hint() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	continue_hint.modulate.a = 0.55
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(continue_hint, "modulate:a", 1.0, 1.1)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(continue_hint, "modulate:a", 0.45, 1.1)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _finish_intro() -> void:
	if SceneFader.is_busy():
		return
	AccountManager.mark_intro_seen()
	SceneFader.fade_to_scene(AccountManager.MAIN_GAME_SCENE)
