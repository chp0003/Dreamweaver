class_name LoreReveal
extends Control
## Illustrated lore discovery overlay. Used when a statue, scroll, or the
## Master Pattern returns a piece of remembered knowledge.

signal closed

var _title: Label
var _body: Label
var _art: TextureRect
var _continue: Button
var _frame: WovenFrame


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_res := load("res://assets/themes/dreamweaver.tres") as Theme
	if theme_res != null:
		theme = theme_res
	_build()


func present(entry_id: String) -> void:
	var entry := CultureData.lore_entry(entry_id)
	if entry.is_empty():
		closed.emit()
		queue_free()
		return
	_title.text = str(entry.get("title", "Remembered"))
	_body.text = str(entry.get("text", ""))
	var art_path := str(entry.get("illustration", entry.get("portrait", "")))
	var tex := PlaceholderProp.load_cutout_texture(art_path)
	_art.texture = tex
	_art.visible = tex != null
	await _fade_in(0.45)


func present_custom(title: String, body: String, texture: Texture2D) -> void:
	_title.text = title
	_body.text = body
	_art.texture = texture
	_art.visible = texture != null
	await _fade_in(0.55)


func _fade_in(duration: float) -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _continue != null:
		_continue.grab_focus()
	await closed


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Palette.alpha(Palette.DREAM_ABYSS, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = WovenFrame.new()
	_frame.pad = 26
	_frame.fill = Palette.alpha(Palette.DREAM_NIGHT, 0.92)
	_frame.lit = true
	_frame.draw_kleng = true
	_frame.header_band = true
	center.add_child(_frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(720.0, 0.0)
	_frame.add_child(column)

	var kicker := Label.new()
	kicker.text = "A memory returns"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.theme_type_variation = &"FieldLabel"
	column.add_child(kicker)

	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override("font_size", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.custom_minimum_size = Vector2(640.0, 280.0)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_art)

	_body = Label.new()
	_body.custom_minimum_size = Vector2(640.0, 0.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.theme_type_variation = &"TaglineLabel"
	_body.add_theme_font_size_override("font_size", 17)
	column.add_child(_body)

	_continue = Button.new()
	_continue.text = "Hold this knowledge"
	_continue.custom_minimum_size = Vector2(280.0, 44.0)
	_continue.pressed.connect(_on_continue)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_continue)
	column.add_child(row)


func _on_continue() -> void:
	_continue.disabled = true
	Audio.play_sfx(Audio.Sfx.PICKUP)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.28)
	await tween.finished
	closed.emit()
	queue_free()
