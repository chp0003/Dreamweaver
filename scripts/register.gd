extends Control
## Create-account screen — matches the cinematic login language.

@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var confirm_field: LineEdit = %ConfirmField
@onready var error_label: Label = %ErrorLabel
@onready var register_button: Button = %RegisterButton
@onready var login_button: Button = %LoginButton
@onready var background: TextureRect = %Background
@onready var brand: Control = %Brand
@onready var form_host: Control = %FormHost
@onready var embers: GPUParticles2D = %Embers


func _ready() -> void:
	error_label.text = ""
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)
	username_field.text_submitted.connect(func(_t: String) -> void: password_field.grab_focus())
	password_field.text_submitted.connect(func(_t: String) -> void: confirm_field.grab_focus())
	confirm_field.text_submitted.connect(func(_t: String) -> void: _on_register_pressed())
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


func _on_register_pressed() -> void:
	if SceneFader.is_busy():
		return
	var message := AccountManager.try_register(
		username_field.text,
		password_field.text,
		confirm_field.text
	)
	error_label.text = message
	if not message.is_empty():
		UiMotion.refuse(form_host)
		return
	SceneFader.fade_to_scene(AccountManager.scene_after_login())


func _on_login_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.LOGIN_SCENE)
