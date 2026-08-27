extends Control
## First screen — cinematic entrance into Dreamweaver.

const SETTINGS_SCENE := "res://scenes/ui/SettingsOverlay.tscn"

@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var error_label: Label = %ErrorLabel
@onready var login_button: Button = %LoginButton
@onready var register_button: Button = %RegisterButton
@onready var settings_button: Button = %SettingsButton
@onready var background: TextureRect = %Background
@onready var brand: Control = %Brand
@onready var form_host: Control = %FormHost
@onready var embers: GPUParticles2D = %Embers

var _settings: CanvasLayer


func _ready() -> void:
	Audio.play_menu_music()
	Audio.set_ambience(0.18, 0.0)
	error_label.text = ""
	_settings = load(SETTINGS_SCENE).instantiate()
	add_child(_settings)
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	username_field.text_submitted.connect(func(_t: String) -> void: password_field.grab_focus())
	password_field.text_submitted.connect(func(_t: String) -> void: _on_login_pressed())
	get_viewport().size_changed.connect(_fit_embers)
	_fit_embers()
	var motes := LightMotes.new()
	motes.mote_count = 32
	add_child(motes)
	await get_tree().process_frame
	_play_entrance()
	username_field.grab_focus()
	if brand != null:
		var title := brand.get_node_or_null("Title") as Label
		if title != null:
			UiStyle.glow_label(title, Palette.DREAM_LANTERN, 18)
		UiMotion.breathe(brand, 5.0, 4.2)


func _fit_embers() -> void:
	var size := get_viewport_rect().size
	embers.position = Vector2(size.x * 0.5, size.y + 20.0)
	var mat := embers.process_material as ParticleProcessMaterial
	if mat != null:
		mat.emission_box_extents = Vector3(size.x * 0.55, 10.0, 1.0)


func _play_entrance() -> void:
	background.pivot_offset = background.size * 0.5
	background.scale = Vector2(1.06, 1.06)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(background, "scale", Vector2.ONE, 8.0)


func _on_login_pressed() -> void:
	if SceneFader.is_busy():
		return
	login_button.disabled = true
	var message := await AccountManager.try_login(username_field.text, password_field.text)
	login_button.disabled = false
	error_label.text = message
	if not message.is_empty():
		UiMotion.refuse(form_host)
		return
	SceneFader.fade_to_scene(AccountManager.scene_after_login())


func _on_register_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.REGISTER_SCENE)


func _on_settings_pressed() -> void:
	if _settings != null and _settings.has_method("open"):
		_settings.open(false)
