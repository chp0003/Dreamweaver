extends Control
## Cinematic prologue. Returning weavers skip this via AccountManager.

const CHARS_PER_SECOND := 52.0
const SLIDE_FADE := 0.45

const SLIDES: Array[Dictionary] = [
	{
		"chapter": "PROLOGUE  ·  I",
		"title": "The Cloth of the World",
		"texture": "res://assets/images/story/intro_01_sacred_world.png",
		"text": "In the time before forgetting, the world was a cloth.\n\nBlack was the foundation. Red was courage. Gold was the sun-thread. From these sacred colors the ancestors wove balance itself — and they called this work Dreamweaving.",
		"pan": Vector2(1.04, 1.04),
	},
	{
		"chapter": "PROLOGUE  ·  II",
		"title": "The Forgetting",
		"texture": "res://assets/images/story/intro_02_darkness.png",
		"text": "Then a grayness came that did not belong to night.\n\nIt crept between the threads. Patterns sung for generations began to loosen — not torn in anger, but forgotten. The Houses of Weaving grew dim. The world began to fray.",
		"pan": Vector2(1.06, 1.03),
	},
	{
		"chapter": "PROLOGUE  ·  III",
		"title": "Fun Kdungon",
		"texture": "res://assets/images/story/intro_03_fun_kdungon.png",
		"text": "In a dream thick as abaca, she came.\n\nFun Kdungon — Goddess of Weaving, keeper of the sacred cloth. She looked upon the loosening world, and upon a sleeping village, and she chose not a warrior — but a weaver. Young. Ordinary. Listening.",
		"pan": Vector2(1.05, 1.05),
	},
	{
		"chapter": "PROLOGUE  ·  IV",
		"title": "The Dreamweaver",
		"texture": "res://assets/images/story/intro_04_slang_chosen.png",
		"text": "S'lang, daughter of the loom — I name you Dreamweaver.\n\nTake up the threads I place in your hands. Walk the Houses of Black Foundation, Red Courage, Golden Sun, and the Dream Ancestors. Restore what the forgetting has unmade.",
		"pan": Vector2(1.03, 1.06),
	},
	{
		"chapter": "PROLOGUE  ·  V",
		"title": "The Road Beyond",
		"texture": "res://assets/images/story/intro_05_journey.png",
		"text": "S'lang woke with gold still burning behind her eyes, and a road she had never walked waiting beyond the door.\n\nThe houses waited. The colors waited. And the cloth of the world, though thinning, had not yet torn.",
		"pan": Vector2(1.05, 1.04),
	},
]

@onready var art_host: Control = %ArtHost
@onready var art: TextureRect = %Art
@onready var chapter_label: Label = %ChapterLabel
@onready var title_label: Label = %TitleLabel
@onready var narration_label: Label = %NarrationLabel
@onready var continue_hint: Label = %ContinueHint
@onready var progress_dots: StoryProgress = %ProgressDots
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
	progress_dots.set_progress(0, SLIDES.size())
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
	progress_dots.set_progress(_index, SLIDES.size())
	continue_hint.text = "Continue  →" if _index < SLIDES.size() - 1 else "Begin the journey  →"

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
