extends CanvasLayer
## Gameplay HUD: objective, lives, health, essences, weaving progress, score.
##
## Sits above the grayscale veil (layer 110 vs 100) so the interface never
## desaturates. Reads GameState signals directly, so chapters only need to call
## `set_chapter()`, `flash_banner()` and the optional combat widgets.

@onready var chapter_label: Label = %ChapterLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var hearts: HudHearts = %Hearts
@onready var health_bar: ProgressBar = %HealthBar
@onready var chime_bar: ProgressBar = %ChimeBar
@onready var beam_bar: ProgressBar = %BeamBar
@onready var essence_row: HBoxContainer = %EssenceRow
@onready var items_label: Label = %ItemsLabel
@onready var weave_bar: ProgressBar = %WeaveBar
@onready var weave_label: Label = %WeaveLabel
@onready var score_label: Label = %ScoreLabel
@onready var banner_label: Label = %BannerLabel
@onready var banner_plate: Control = %BannerPlate
@onready var counter_label: Label = %CounterLabel
@onready var mode_label: Label = %ModeLabel
@onready var integrity_box: VBoxContainer = %IntegrityBox
@onready var integrity_bar: ProgressBar = %IntegrityBar
@onready var boss_plate: VBoxContainer = %BossPlate
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_name: Label = %BossName
@onready var bottom_dock: Control = %BottomDock
@onready var health_value: Label = %HealthValue
@onready var quest_plate: Control = %QuestPlate
@onready var vital_plate: Control = %VitalPlate
@onready var essence_plate: Control = %EssencePlate
@onready var weave_plate: Control = %WeavePlate
@onready var center_top: Control = $Root/CenterTop

var _player: Slang
var _banner_tween: Tween
var _beam_pulse: Tween
var _story_focus := false
var _dialogue_busy := false


func _ready() -> void:
	layer = 110

	GameState.lives_changed.connect(_on_lives_changed)
	GameState.objective_changed.connect(set_objective)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.score_changed.connect(_on_score_changed)
	GameState.progress_changed.connect(_refresh_weaving)

	banner_plate.modulate.a = 0.0
	banner_plate.visible = false
	counter_label.visible = false
	mode_label.visible = false
	integrity_box.visible = false
	chime_bar.visible = false
	if beam_bar != null:
		beam_bar.visible = false
	if boss_bar != null:
		boss_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Color(0.55, 0.12, 0.62), 8))
	if boss_plate != null:
		boss_plate.visible = false

	_on_lives_changed(GameState.lives)
	_on_score_changed(GameState.score)
	_refresh_inventory()
	_refresh_weaving()
	set_objective(GameState.objective)
	set_process(true)
	_dress_plates()
	for plate in [quest_plate, vital_plate, essence_plate, weave_plate]:
		if plate != null:
			plate.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_property(plate, "modulate:a", 1.0, UiMotion.SLOW)\
				.set_ease(Tween.EASE_OUT)


func _dress_plates() -> void:
	if quest_plate is PanelContainer:
		(quest_plate as PanelContainer).add_theme_stylebox_override("panel", UiStyle.veil(0.46, 8))
		quest_plate.clip_contents = false
	if vital_plate is PanelContainer:
		(vital_plate as PanelContainer).add_theme_stylebox_override("panel", UiStyle.veil(0.46, 12))
	if essence_plate is PanelContainer:
		(essence_plate as PanelContainer).add_theme_stylebox_override("panel", UiStyle.veil(0.42, 12))
	if weave_plate is PanelContainer:
		(weave_plate as PanelContainer).add_theme_stylebox_override("panel", UiStyle.veil(0.42, 12))
	if banner_plate is PanelContainer:
		(banner_plate as PanelContainer).add_theme_stylebox_override("panel", UiStyle.glass_lit())
	UiStyle.glow_label(chapter_label, Palette.GOLD_BRASS, 6)
	UiStyle.glow_label(banner_label, Palette.DREAM_LANTERN, 14)


func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player) and chime_bar.visible:
		chime_bar.value = _player.chime_cooldown_ratio() * 100.0
	if _player != null and is_instance_valid(_player) and beam_bar != null:
		beam_bar.visible = _player.has_light_beam
		if beam_bar.visible:
			beam_bar.value = _player.beam_cooldown_ratio() * 100.0
	_sync_dialogue_chrome()


## Dialogue owns the bottom of the screen. Hide inventory + world nameplates so
## walking into a line of dialogue never stacks two UIs on top of each other.
func _sync_dialogue_chrome() -> void:
	var busy := false
	for node in get_tree().get_nodes_in_group("dialogue_view"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			busy = true
			break
	if busy == _dialogue_busy:
		return
	_dialogue_busy = busy

	bottom_dock.visible = not busy and not _story_focus
	if _story_focus:
		# Story focus already hid essence/weave; keep them hidden during dialogue too.
		if essence_plate != null:
			essence_plate.visible = false
		if weave_plate != null:
			weave_plate.visible = false
	elif not busy:
		if essence_plate != null:
			essence_plate.visible = true
		if weave_plate != null:
			weave_plate.visible = true

	# Never leave a half-faded title card over the room while someone is talking.
	if busy:
		_kill_banner()

	for node in get_tree().get_nodes_in_group("world_chrome"):
		if node is CanvasItem:
			(node as CanvasItem).visible = not busy
	for node in get_tree().get_nodes_in_group("tutorial_hint"):
		if node is CanvasItem:
			(node as CanvasItem).visible = not busy
	if quest_plate != null:
		quest_plate.visible = not busy


# --------------------------------------------------------------------------
# Chapter-facing API
# --------------------------------------------------------------------------

func bind_player(player: Slang) -> void:
	_player = player
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)
	chime_bar.visible = player.has_staff
	if beam_bar != null:
		beam_bar.visible = player.has_light_beam


func set_chapter(title: String) -> void:
	chapter_label.text = title.to_upper()


func show_quest_plate(visible_now: bool) -> void:
	if quest_plate != null:
		quest_plate.visible = visible_now


func set_story_focus(enabled: bool) -> void:
	_story_focus = enabled
	if essence_plate != null:
		essence_plate.visible = not enabled
	if weave_plate != null:
		weave_plate.visible = not enabled
	bottom_dock.visible = not enabled
	if chapter_label != null and enabled:
		chapter_label.add_theme_font_size_override("font_size", 12)
	if objective_label != null and enabled:
		objective_label.add_theme_font_size_override("font_size", 28)


func set_chapter_focus(enabled: bool) -> void:
	_story_focus = false
	if essence_plate != null:
		essence_plate.visible = true
	if weave_plate != null:
		weave_plate.visible = true
		weave_plate.modulate = Color(1, 1, 1, 0.9) if enabled else Color.WHITE
	bottom_dock.visible = true
	if objective_label != null and enabled:
		objective_label.add_theme_font_size_override("font_size", 28)


func set_quest_steps(steps: Array, current: int) -> void:
	var box := get_node_or_null("%QuestSteps") as VBoxContainer
	if box == null:
		return
	for child in box.get_children():
		child.free()
	if steps.is_empty():
		box.visible = false
		if objective_label != null:
			objective_label.add_theme_font_size_override("font_size", 28)
		_fit_quest_plate()
		return
	box.visible = true
	if objective_label != null:
		objective_label.add_theme_font_size_override("font_size", 28)
	for i in range(steps.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(3, 18)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == current:
			pip.color = Palette.GOLD_SACRED
		elif i < current:
			pip.color = Palette.alpha(Palette.GOLD_BRASS, 0.55)
		else:
			pip.color = Palette.alpha(Palette.DREAM_MIST, 0.22)
		row.add_child(pip)

		var num := Label.new()
		num.text = "%d" % (i + 1)
		num.custom_minimum_size = Vector2(18, 0)
		num.add_theme_font_size_override("font_size", 20)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := Palette.GOLD_SUN if i == current \
			else (Palette.CREAM_STONE if i < current else Palette.alpha(Palette.DREAM_MIST, 0.58))
		num.add_theme_color_override("font_color", color)
		num.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.85))
		num.add_theme_constant_override("outline_size", 4)
		row.add_child(num)

		var body := Label.new()
		body.text = str(steps[i])
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_font_size_override("font_size", 22 if i == current else 20)
		body.add_theme_color_override("font_color", color)
		body.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.85))
		body.add_theme_constant_override("outline_size", 4)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(body)
		box.add_child(row)
	_fit_quest_plate()


func set_objective(text: String) -> void:
	objective_label.text = text if not text.is_empty() else "Walk the ridge."
	_fit_quest_plate()


## The plate used to be a fixed height sized for three lines. Later lessons
## (strand, roll, ward, and the longer house lists) drew past the bottom and vanished.
func _fit_quest_plate() -> void:
	if quest_plate == null or objective_label == null:
		return
	var width := 440.0
	var font := objective_label.get_theme_font("font")
	var font_size := objective_label.get_theme_font_size("font_size")
	var objective_h := 28.0
	if font != null and not objective_label.text.is_empty():
		objective_h = font.get_multiline_string_size(
			objective_label.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size
		).y
	objective_h = maxf(objective_h, 28.0)
	var rows := 0
	var box := get_node_or_null("%QuestSteps") as VBoxContainer
	if box != null and box.visible:
		rows = box.get_child_count()
	var height := 56.0 + objective_h + float(rows) * 32.0
	quest_plate.offset_bottom = quest_plate.offset_top + height


## Short centred toast. Skipped entirely while dialogue is open.
func flash_banner(text: String, hold := 1.6) -> void:
	if text.is_empty():
		return
	if _dialogue_busy:
		return
	# Don't repeat the objective/chapter title as a giant centre card.
	var compact := text.strip_edges().replace("\n", " ")
	if compact.to_upper() == chapter_label.text.to_upper():
		return
	if compact.to_upper() == objective_label.text.to_upper():
		return

	banner_label.text = compact
	banner_plate.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner_plate.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_plate, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner_plate, "modulate:a", 0.0, 0.45)
	_banner_tween.tween_callback(func() -> void:
		if banner_plate != null:
			banner_plate.visible = false
	)


func _kill_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
	if banner_plate != null:
		banner_plate.modulate.a = 0.0
		banner_plate.visible = false


func set_counter(text: String) -> void:
	counter_label.text = text
	counter_label.visible = not text.is_empty()


func set_mode(text: String, color := Palette.GOLD_SACRED) -> void:
	mode_label.text = text
	mode_label.add_theme_color_override("font_color", color)
	mode_label.visible = not text.is_empty()


## Flash the beam cooldown bar so a new unlock is obvious on the vitals plate.
func pulse_beam_unlock() -> void:
	if beam_bar == null:
		return
	beam_bar.visible = true
	beam_bar.value = 100.0
	if _beam_pulse != null and _beam_pulse.is_valid():
		_beam_pulse.kill()
	beam_bar.modulate = Color(1.55, 1.35, 0.55)
	beam_bar.scale = Vector2(1.0, 1.0)
	_beam_pulse = create_tween()
	_beam_pulse.set_loops(4)
	_beam_pulse.tween_property(beam_bar, "modulate", Color(1.9, 1.7, 0.7), 0.18)
	_beam_pulse.tween_property(beam_bar, "modulate", Color(1.15, 1.05, 0.55), 0.18)
	_beam_pulse.chain().tween_callback(func() -> void:
		if beam_bar != null:
			beam_bar.modulate = Color.WHITE)
	_refresh_inventory()
	if items_label != null:
		items_label.add_theme_color_override("font_color", Palette.GOLD_SUN)
		var glow := create_tween()
		glow.tween_interval(2.8)
		glow.tween_callback(func() -> void:
			if items_label != null:
				items_label.remove_theme_color_override("font_color"))


func show_loom_integrity(visible_now: bool) -> void:
	integrity_box.visible = visible_now
	_set_integrity_tag("LOOM HP")


func set_loom_integrity(ratio: float) -> void:
	UiMotion.slide_bar(integrity_bar, clampf(ratio, 0.0, 1.0) * 100.0)


func show_boss_health(visible_now: bool) -> void:
	if boss_plate != null:
		boss_plate.visible = visible_now
	if not visible_now and integrity_box != null:
		integrity_box.visible = false


func set_boss_health(current: float, maximum: float) -> void:
	if boss_bar == null:
		return
	var safe_max := maxf(1.0, maximum)
	boss_bar.max_value = safe_max
	UiMotion.slide_bar(boss_bar, clampf(current, 0.0, safe_max))
	if boss_name != null:
		boss_name.text = "SHADOW WEAVER   %d" % roundi(current)


func _set_integrity_tag(text: String) -> void:
	var tag := integrity_box.get_node_or_null("IntegrityTag") as Label
	if tag != null:
		tag.text = text


func show_chime_meter(visible_now: bool) -> void:
	chime_bar.visible = visible_now


# --------------------------------------------------------------------------
# GameState reactions
# --------------------------------------------------------------------------

func _on_lives_changed(lives: int) -> void:
	hearts.set_lives(lives)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	UiMotion.slide_bar(health_bar, current)
	health_value.text = "%d" % roundi(current)


func _on_score_changed(score: int) -> void:
	score_label.text = "%d" % score


func _refresh_weaving() -> void:
	var percent := GameState.weaving_percent()
	UiMotion.slide_bar(weave_bar, percent * 100.0, UiMotion.SLOW)
	weave_label.text = "%d%%" % roundi(percent * 100.0)


func _refresh_inventory() -> void:
	for child in essence_row.get_children():
		child.queue_free()

	for essence_id in ["black", "red", "gold"]:
		var chip := EssenceChip.new()
		essence_row.add_child(chip)
		chip.configure(str(essence_id), GameState.has_essence(str(essence_id)))

	if GameState.has_item("master_pattern"):
		var pattern := Label.new()
		pattern.text = "PATTERN"
		pattern.theme_type_variation = &"FieldLabel"
		pattern.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pattern.add_theme_color_override("font_color", Palette.GOLD_SUN)
		essence_row.add_child(pattern)

	var held: Array[String] = []
	for item_id in GameState.items:
		if str(item_id) == "master_pattern":
			continue
		held.append(Houses.item_name(str(item_id)))
	if held.is_empty():
		items_label.text = "I  ·  bag" if GameState.has_item("lewet_staff") or not GameState.journals.is_empty() else ""
	else:
		items_label.text = "I  ·  %s" % " · ".join(held)
	items_label.visible = not items_label.text.is_empty()
