extends CanvasLayer
## Shared Settings / Options overlay for Login, Register, and the Gateway.
##
## Tabs cover Audio, Account, and Display. Host screens instance this once and
## call `open()`. Account tools only appear when a session is active.

signal closed

enum Tab { AUDIO, ACCOUNT, DISPLAY }

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _tab_audio: Button
var _tab_account: Button
var _tab_display: Button
var _body: VBoxContainer
var _status: Label
var _close_button: Button
var _account_enabled := true

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _mute_check: CheckButton

var _username_label: Label
var _current_password: LineEdit
var _new_password: LineEdit
var _confirm_password: LineEdit
var _delete_password: LineEdit

var _fullscreen_check: CheckButton
var _vsync_check: CheckButton

var _audio_block: VBoxContainer
var _account_block: VBoxContainer
var _display_block: VBoxContainer


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open(account_enabled: bool = true, start_tab: Tab = Tab.AUDIO) -> void:
	_account_enabled = account_enabled
	_tab_account.disabled = not account_enabled
	_pull_settings()
	var tab := start_tab
	if not account_enabled and tab == Tab.ACCOUNT:
		tab = Tab.AUDIO
	_show_tab(tab)
	_status.text = ""
	visible = true
	_dim.color.a = 0.0
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "color:a", 0.72, 0.18)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "color:a", 0.0, 0.14)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.14)
	await tween.finished
	visible = false
	closed.emit()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(Palette.DREAM_ABYSS, 0.0)
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 470)
	_panel.add_theme_stylebox_override("panel", UiStyle.glass_lit(Palette.DREAM_INDIGO, 0.95, 8))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.text = "SETTINGS"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	header.add_child(_title)
	_close_button = Button.new()
	_close_button.text = "CLOSE"
	_close_button.custom_minimum_size = Vector2(108, 34)
	_close_button.theme_type_variation = &"GhostButton"
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_tab_audio = _tab_button("AUDIO", Tab.AUDIO)
	_tab_account = _tab_button("ACCOUNT", Tab.ACCOUNT)
	_tab_display = _tab_button("DISPLAY", Tab.DISPLAY)
	tabs.add_child(_tab_audio)
	tabs.add_child(_tab_account)
	tabs.add_child(_tab_display)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(Palette.GOLD_BRASS, 0.3)
	root.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Palette.DREAM_MIST)
	root.add_child(_status)

	_audio_block = _build_audio_block()
	_account_block = _build_account_block()
	_display_block = _build_display_block()


func _tab_button(text: String, tab: Tab) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(118, 34)
	button.pressed.connect(func() -> void: _show_tab(tab))
	return button


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _show_tab(tab: Tab) -> void:
	_tab_audio.set_pressed_no_signal(tab == Tab.AUDIO)
	_tab_account.set_pressed_no_signal(tab == Tab.ACCOUNT)
	_tab_display.set_pressed_no_signal(tab == Tab.DISPLAY)
	for child in _body.get_children():
		_body.remove_child(child)
	match tab:
		Tab.AUDIO:
			_title.text = "SETTINGS  ·  AUDIO"
			_body.add_child(_audio_block)
		Tab.ACCOUNT:
			_title.text = "SETTINGS  ·  ACCOUNT"
			_refresh_account_block()
			_body.add_child(_account_block)
		Tab.DISPLAY:
			_title.text = "SETTINGS  ·  DISPLAY"
			_body.add_child(_display_block)


func _pull_settings() -> void:
	_master_slider.set_value_no_signal(Settings.master_volume * 100.0)
	_music_slider.set_value_no_signal(Settings.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(Settings.sfx_volume * 100.0)
	_mute_check.set_pressed_no_signal(Settings.muted)
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_vsync_check.set_pressed_no_signal(Settings.vsync)


func _build_audio_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("VOLUME"))
	_master_slider = _slider()
	_music_slider = _slider()
	_sfx_slider = _slider()
	_master_slider.value_changed.connect(func(v: float) -> void:
		Settings.set_master_volume(v / 100.0)
		_ok("Master volume updated.")
	)
	_music_slider.value_changed.connect(func(v: float) -> void:
		Settings.set_music_volume(v / 100.0)
		_ok("Music volume updated.")
	)
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		Settings.set_sfx_volume(v / 100.0)
		_ok("Effects volume updated.")
		Audio.play_sfx(Audio.Sfx.CHIME)
	)
	box.add_child(_row("Master", _master_slider))
	box.add_child(_row("Music", _music_slider))
	box.add_child(_row("Effects", _sfx_slider))
	_mute_check = CheckButton.new()
	_mute_check.text = "Mute all audio"
	_mute_check.toggled.connect(func(on: bool) -> void:
		Settings.set_muted(on)
		_ok("Audio muted." if on else "Audio unmuted.")
	)
	box.add_child(_mute_check)
	return box


func _build_account_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_username_label = Label.new()
	_username_label.add_theme_font_size_override("font_size", 18)
	_username_label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	box.add_child(_username_label)

	box.add_child(_heading("CHANGE PASSWORD"))
	_current_password = _secret("Current password")
	_new_password = _secret("New password")
	_confirm_password = _secret("Confirm new password")
	box.add_child(_current_password)
	box.add_child(_new_password)
	box.add_child(_confirm_password)
	var change_btn := _action("UPDATE PASSWORD", true)
	change_btn.pressed.connect(_on_change_password)
	box.add_child(change_btn)

	box.add_child(_heading("SAVE DATA"))
	var clear_btn := _action("CLEAR SAVE DATA", false)
	clear_btn.pressed.connect(_on_clear_save)
	box.add_child(clear_btn)

	box.add_child(_heading("SESSION"))
	var logout_btn := _action("LOG OUT", false)
	logout_btn.pressed.connect(_on_logout)
	box.add_child(logout_btn)

	box.add_child(_heading("DANGER ZONE"))
	_delete_password = _secret("Password to confirm deletion")
	box.add_child(_delete_password)
	var delete_btn := _action("DELETE ACCOUNT", false)
	delete_btn.pressed.connect(_on_delete_account)
	box.add_child(delete_btn)
	return box


func _refresh_account_block() -> void:
	if AccountManager.has_session():
		_username_label.text = "Signed in as  %s" % AccountManager.current_username()
	else:
		_username_label.text = "Not signed in."


func _build_display_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("WINDOW"))
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		_ok("Fullscreen enabled." if on else "Windowed mode.")
	)
	_vsync_check = CheckButton.new()
	_vsync_check.text = "V-Sync"
	_vsync_check.toggled.connect(func(on: bool) -> void:
		Settings.set_vsync(on)
		_ok("V-Sync enabled." if on else "V-Sync disabled.")
	)
	box.add_child(_fullscreen_check)
	box.add_child(_vsync_check)
	var tip := Label.new()
	tip.text = "Display changes apply immediately and stay saved on this device."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Palette.DREAM_MIST)
	box.add_child(tip)
	return box


func _on_change_password() -> void:
	var message := await AccountManager.change_password(
		_current_password.text, _new_password.text, _confirm_password.text)
	if message.is_empty():
		_current_password.text = ""
		_new_password.text = ""
		_confirm_password.text = ""
		_ok("Password updated.")
		Audio.play_sfx(Audio.Sfx.SUCCESS)
	else:
		_err(message)


func _on_clear_save() -> void:
	if not AccountManager.has_session():
		_err("Sign in to manage save data.")
		return
	AccountManager.clear_progress()
	GameState.load_from_account()
	_ok("Save data cleared.")
	Audio.play_sfx(Audio.Sfx.THUD)


func _on_logout() -> void:
	await AccountManager.logout()
	close()
	if not SceneFader.is_busy():
		SceneFader.fade_to_scene(AccountManager.LOGIN_SCENE)


func _on_delete_account() -> void:
	var message := await AccountManager.delete_account(_delete_password.text)
	if message.is_empty():
		_delete_password.text = ""
		close()
		if not SceneFader.is_busy():
			SceneFader.fade_to_scene(AccountManager.LOGIN_SCENE)
	else:
		_err(message)


func _ok(text: String) -> void:
	_status.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	_status.text = text


func _err(text: String) -> void:
	_status.add_theme_color_override("font_color", Palette.RED_EMBER)
	_status.text = text
	Audio.play_sfx(Audio.Sfx.FAIL)


func _slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260, 22)
	return slider


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(84, 0)
	label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	row.add_child(label)
	row.add_child(control)
	return row


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	return label


func _secret(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.secret = true
	field.secret_character = "•"
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 40)
	return field


func _action(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	if not primary:
		button.theme_type_variation = &"GhostButton"
	return button
