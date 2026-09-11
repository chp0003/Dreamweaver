extends MiniGameBase
## Chapter 2 - "Pigment Mashing".
##
## A pestle marker sweeps back and forth across the mortar. A target band sits
## somewhere along the sweep with a direction glyph on it. Press that direction
## (W/A/S/D) while the marker is inside the band to land a strike. Land enough
## strikes before the timer or the miss budget runs out and the hulo root gives
## up its red.

const REQUIRED_HITS := 10
const ALLOWED_MISSES := 4
const TRACK_HEIGHT := 66.0

const DIRECTIONS := [
	{"action": "move_forward", "glyph": "W"},
	{"action": "move_left", "glyph": "A"},
	{"action": "move_back", "glyph": "S"},
	{"action": "move_right", "glyph": "D"},
]

var _track: Control
var _band: ColorRect
var _marker: ColorRect
var _glyph: Label
var _mash_label: Label

var _marker_pos := 0.0
var _direction := 1.0
var _speed := 0.62
var _band_center := 0.5
var _band_half := 0.1
var _required_index := 0

var _hits := 0
var _misses := 0


func _configure() -> void:
	mini_game_title = "Pigment Mashing"
	mini_game_subtitle = "House of Red Courage"
	instructions = "The pestle swings across the mortar. Press the shown direction key while the pestle is inside the lit band. %d clean strikes crush the root; %d misses spoil it." % [
		REQUIRED_HITS, ALLOWED_MISSES + 1]
	time_limit = 45.0


func _build_content(parent: Control) -> void:
	_mash_label = Label.new()
	_mash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mash_label.add_theme_font_size_override("font_size", 20)
	_mash_label.add_theme_color_override("font_color", Palette.RED_EMBER)
	parent.add_child(_mash_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 18.0)
	parent.add_child(spacer)

	_glyph = Label.new()
	_glyph.text = "W"
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.theme_type_variation = &"HeaderLabel"
	_glyph.add_theme_font_size_override("font_size", 56)
	parent.add_child(_glyph)

	_track = Control.new()
	_track.custom_minimum_size = Vector2(0.0, TRACK_HEIGHT)
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_track)

	var trough := ColorRect.new()
	trough.color = Palette.alpha(Palette.BLACK_SOOT, 0.95)
	trough.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(trough)

	_band = ColorRect.new()
	_band.color = Palette.alpha(Palette.RED_SACRED, 0.55)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_band)

	_marker = ColorRect.new()
	_marker.color = Palette.GOLD_SACRED
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_marker)

	var mortar := Label.new()
	mortar.text = "Crush the hulo root. The pestle is the gold bar; the pigment lives in the red band."
	mortar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mortar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mortar.theme_type_variation = &"FieldLabel"
	parent.add_child(mortar)


func _reset_round() -> void:
	_hits = 0
	_misses = 0
	_marker_pos = 0.0
	_direction = 1.0
	_speed = 0.62
	_next_target()
	_refresh_labels()


func _process(delta: float) -> void:
	super._process(delta)
	if not running or _track == null:
		return

	_marker_pos += _direction * _speed * delta
	if _marker_pos >= 1.0:
		_marker_pos = 1.0
		_direction = -1.0
	elif _marker_pos <= 0.0:
		_marker_pos = 0.0
		_direction = 1.0

	_layout_track()


func _unhandled_input(event: InputEvent) -> void:
	if not running or event.is_echo():
		return
	for i in range(DIRECTIONS.size()):
		var action := str(DIRECTIONS[i]["action"])
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_attempt_strike(i)
			return


func _attempt_strike(direction_index: int) -> void:
	var inside := absf(_marker_pos - _band_center) <= _band_half
	if inside and direction_index == _required_index:
		_hits += 1
		GameState.add_score(20)
		Audio.play_sfx(Audio.Sfx.HIT)
		_flash_band(Palette.alpha(Palette.RED_EMBER, 0.88))
		_pulse_glyph(true)
		# Each strike drives the pestle a little faster.
		_speed = minf(1.5, _speed + 0.07)
		_next_target()
	else:
		_misses += 1
		Audio.play_sfx(Audio.Sfx.THUD)
		_flash_band(Color(0.35, 0.32, 0.3, 0.6))
		_pulse_glyph(false)

	_refresh_labels()

	if _hits >= REQUIRED_HITS:
		GameState.unlock_lore("sacred_colors")
		succeed("The root gives way. Deep red bleeds into the mortar - %d clean strikes." % _hits)
	elif _misses > ALLOWED_MISSES:
		fail("The pestle kept striking dry stone. The root is bruised, not crushed.")


## Places a new band and picks a new direction, avoiding a band right under the
## pestle so the player always gets a moment to read it.
func _next_target() -> void:
	_band_half = lerpf(0.11, 0.06, float(_hits) / float(REQUIRED_HITS))
	for _try in range(8):
		var candidate := randf_range(_band_half + 0.05, 1.0 - _band_half - 0.05)
		if absf(candidate - _marker_pos) > _band_half + 0.12:
			_band_center = candidate
			break
		_band_center = candidate
	_required_index = randi() % DIRECTIONS.size()
	if _glyph != null:
		_glyph.text = str(DIRECTIONS[_required_index]["glyph"])
	_layout_track()


func _layout_track() -> void:
	if _track == null or _band == null or _marker == null:
		return
	var width := _track.size.x
	if width <= 0.0:
		return
	_band.position = Vector2((_band_center - _band_half) * width, 0.0)
	_band.size = Vector2(_band_half * 2.0 * width, TRACK_HEIGHT)
	_marker.size = Vector2(14.0, TRACK_HEIGHT - 8.0)
	_marker.position = Vector2(_marker_pos * width - 7.0, 4.0)


func _pulse_glyph(hit: bool) -> void:
	if _glyph == null:
		return
	_glyph.modulate = Color(1.25, 0.55, 0.38) if hit else Color(0.7, 0.65, 0.6)
	var tween := create_tween()
	tween.tween_property(_glyph, "modulate", Color.WHITE, 0.22)


func _flash_band(color: Color) -> void:
	if _band == null:
		return
	_band.color = color
	var tween := create_tween()
	tween.tween_property(_band, "color", Palette.alpha(Palette.RED_SACRED, 0.55), 0.24)


func _refresh_labels() -> void:
	if _mash_label != null:
		_mash_label.text = "Strikes  %d / %d      Spoiled  %d / %d" % [
			_hits, REQUIRED_HITS, _misses, ALLOWED_MISSES + 1]
	set_status("Press the glyph shown while the pestle is in the red band.")
