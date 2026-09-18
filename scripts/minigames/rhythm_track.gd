extends MiniGameBase
## Chapter 5, Weave Mode - "The Duel of Rhythms" rhythm track.
##
## Runs as a compact bar docked to the bottom of the screen so the boss fight
## stays visible behind it. Notes slide left along four lanes (W/A/S/D); press
## the lane's key as its note crosses the strike line. Each clean hit emits
## `note_resolved(true)`, which Chapter 5 turns into boss damage.

signal note_resolved(hit: bool)

const LANES := [
	{"action": "move_forward", "glyph": "W", "color": Color(0.9, 0.78, 0.36)},
	{"action": "move_left", "glyph": "A", "color": Color(0.78, 0.33, 0.27)},
	{"action": "move_back", "glyph": "S", "color": Color(0.62, 0.7, 0.5)},
	{"action": "move_right", "glyph": "D", "color": Color(0.72, 0.62, 0.82)},
]

const LANE_HEIGHT := 34.0
const STRIKE_X := 96.0
const HIT_TOLERANCE := 44.0

@export var note_count := 12
@export var note_speed := 300.0
@export var spawn_interval := 0.46875
## Fraction of notes that must land for the track to count as a success.
@export var required_ratio := 0.5

var _lane_area: Control
var _lane_rows: Array[Control] = []
var _notes: Array[Dictionary] = []
var _spawned := 0
var _resolved := 0
var _hits := 0
var _spawn_timer := 0.0
var _counter_label: Label


func _configure() -> void:
	compact = true
	mini_game_title = "Weave Mode"
	instructions = "Press W / A / S / D as each thread crosses the strike line."
	time_limit = 0.0
	max_attempts = 1
	reward_score = 0


func _build_content(parent: Control) -> void:
	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 16)
	_counter_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.62))
	parent.add_child(_counter_label)

	_lane_area = Control.new()
	_lane_area.custom_minimum_size = Vector2(0.0, LANE_HEIGHT * LANES.size() + 12.0)
	_lane_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lane_area.clip_contents = true
	parent.add_child(_lane_area)

	for i in range(LANES.size()):
		var row := Control.new()
		row.position = Vector2(0.0, i * LANE_HEIGHT)
		row.size = Vector2(0.0, LANE_HEIGHT - 4.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lane_area.add_child(row)
		_lane_rows.append(row)

		var bed := ColorRect.new()
		bed.color = Color(0.1, 0.09, 0.08, 0.8)
		bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bed)

		var strike := ColorRect.new()
		strike.color = Color(LANES[i]["color"], 0.55)
		strike.position = Vector2(STRIKE_X - 4.0, 0.0)
		strike.size = Vector2(8.0, LANE_HEIGHT - 4.0)
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(strike)

		var glyph := Label.new()
		glyph.text = str(LANES[i]["glyph"])
		glyph.position = Vector2(16.0, -4.0)
		glyph.add_theme_font_size_override("font_size", 20)
		glyph.add_theme_color_override("font_color", LANES[i]["color"])
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(glyph)


func _reset_round() -> void:
	for note in _notes:
		var rect := note["rect"] as ColorRect
		if is_instance_valid(rect):
			rect.queue_free()
	_notes.clear()
	_spawned = 0
	_resolved = 0
	_hits = 0
	_spawn_timer = 0.25
	_refresh_counter()


func _process(delta: float) -> void:
	super._process(delta)
	if not running or _lane_area == null:
		return

	# Lane rows follow the container width, which is only known after layout.
	for row in _lane_rows:
		row.size.x = _lane_area.size.x

	if _spawned < note_count:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_note()

	for i in range(_notes.size() - 1, -1, -1):
		var note: Dictionary = _notes[i]
		var rect := note["rect"] as ColorRect
		if not is_instance_valid(rect):
			_notes.remove_at(i)
			continue
		rect.position.x -= note_speed * delta
		if rect.position.x < STRIKE_X - HIT_TOLERANCE:
			_resolve(i, false)

	if _resolved >= note_count and _notes.is_empty():
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not running or event.is_echo():
		return
	for lane in range(LANES.size()):
		if event.is_action_pressed(str(LANES[lane]["action"])):
			get_viewport().set_input_as_handled()
			_strike(lane)
			return


func _spawn_note() -> void:
	var lane := randi() % LANES.size()
	var rect := ColorRect.new()
	rect.color = LANES[lane]["color"]
	rect.size = Vector2(26.0, LANE_HEIGHT - 10.0)
	rect.position = Vector2(maxf(_lane_area.size.x, 480.0), 3.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lane_rows[lane].add_child(rect)

	_notes.append({"lane": lane, "rect": rect})
	_spawned += 1


func _strike(lane: int) -> void:
	var best := -1
	var best_distance := HIT_TOLERANCE + 1.0
	for i in range(_notes.size()):
		if int(_notes[i]["lane"]) != lane:
			continue
		var rect := _notes[i]["rect"] as ColorRect
		if not is_instance_valid(rect):
			continue
		var distance := absf(rect.position.x - STRIKE_X)
		if distance < best_distance:
			best_distance = distance
			best = i

	if best < 0:
		Audio.play_sfx(Audio.Sfx.THUD)
		set_status("Off the beat.")
		return
	_resolve(best, true)


func _resolve(index: int, hit: bool) -> void:
	if index < 0 or index >= _notes.size():
		return
	var note: Dictionary = _notes[index]
	var rect := note["rect"] as ColorRect
	_notes.remove_at(index)
	_resolved += 1

	if hit:
		_hits += 1
		Audio.play_sfx(Audio.Sfx.PARRY)
		Audio.play_sfx(Audio.Sfx.BELL)
		GameState.add_score(35)
		set_status("Struck true.")
	else:
		set_status("Missed.")

	if is_instance_valid(rect):
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(rect, "modulate:a", 0.0, 0.18)
		tween.tween_property(rect, "scale", Vector2(1.8, 1.8) if hit else Vector2(0.6, 0.6), 0.18)
		tween.chain().tween_callback(rect.queue_free)

	_refresh_counter()
	note_resolved.emit(hit)


func _finish() -> void:
	var needed := maxi(1, ceili(float(note_count) * required_ratio))
	if _hits >= needed:
		succeed("%d of %d threads struck true." % [_hits, note_count])
	else:
		fail("Only %d of %d threads landed. The Shadow Weaver pulls free." % [_hits, note_count])


func _refresh_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "Threads struck  %d / %d" % [_hits, note_count]
