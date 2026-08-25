extends MiniGameBase
## Chapter 4 - "Warp Alignment".
##
## The target dream pattern is shown above the loom. The warp threads below are
## out of order. Click two threads to swap them; match the pattern within the
## move budget. The scramble is built by applying a known number of swaps to the
## solution, so every deal is guaranteed solvable within the budget.

const THREADS := 6
const SCRAMBLE_SWAPS := 4
const MOVE_BUDGET := 8

const THREAD_COLORS := [
	Color(0.16, 0.15, 0.15),
	Color(0.72, 0.18, 0.15),
	Color(0.9, 0.76, 0.34),
	Color(0.88, 0.83, 0.7),
	Color(0.45, 0.3, 0.2),
	Color(0.3, 0.28, 0.34),
]

const THREAD_NAMES = ["Black", "Red", "Gold", "Cream", "Earth", "Smoke"]

var _target_row: HBoxContainer
var _warp_row: HBoxContainer
var _moves_label: Label

var _target: Array[int] = []
var _current: Array[int] = []
var _buttons: Array[Button] = []
var _selected := -1
var _moves := 0


func _configure() -> void:
	mini_game_title = "Warp Alignment"
	mini_game_subtitle = "House of the Dream Ancestors"
	instructions = "Click two warp threads to swap them. Rearrange the loom until it matches the dream pattern above, within %d moves." % MOVE_BUDGET
	time_limit = 90.0


func _build_content(parent: Control) -> void:
	var target_tag := Label.new()
	target_tag.text = "THE DREAM PATTERN"
	target_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_tag.theme_type_variation = &"FieldLabel"
	parent.add_child(target_tag)

	_target_row = HBoxContainer.new()
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_row.add_theme_constant_override("separation", 10)
	parent.add_child(_target_row)

	var divider := Control.new()
	divider.custom_minimum_size = Vector2(0.0, 16.0)
	parent.add_child(divider)

	var warp_tag := Label.new()
	warp_tag.text = "THE ABLUN LOOM - YOUR WARP"
	warp_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warp_tag.theme_type_variation = &"FieldLabel"
	parent.add_child(warp_tag)

	_warp_row = HBoxContainer.new()
	_warp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_warp_row.add_theme_constant_override("separation", 10)
	parent.add_child(_warp_row)

	_moves_label = Label.new()
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 18)
	_moves_label.add_theme_color_override("font_color", Color(0.9, 0.83, 0.6))
	parent.add_child(_moves_label)

	for i in range(THREADS):
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(44.0, 110.0)
		_target_row.add_child(swatch)

		var button := Button.new()
		button.custom_minimum_size = Vector2(44.0, 168.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_thread_pressed.bind(i))
		_warp_row.add_child(button)
		_buttons.append(button)


func _reset_round() -> void:
	_moves = 0
	_selected = -1

	_target.clear()
	for i in range(THREADS):
		_target.append(i)
	_target.shuffle()

	_current = _target.duplicate()
	# Scramble by valid swaps only, so the puzzle is always solvable in budget.
	for _swap in range(SCRAMBLE_SWAPS):
		var a := randi() % THREADS
		var b := randi() % THREADS
		if a != b:
			var held: int = _current[a]
			_current[a] = _current[b]
			_current[b] = held
	if _current == _target:
		# A scramble that cancelled itself out; nudge it.
		var held: int = _current[0]
		_current[0] = _current[1]
		_current[1] = held

	_paint_target()
	_paint_warp()
	_refresh_moves()


func _paint_target() -> void:
	for i in range(THREADS):
		var swatch := _target_row.get_child(i) as Panel
		swatch.add_theme_stylebox_override("panel", _thread_style(_target[i], false))


func _paint_warp() -> void:
	for i in range(THREADS):
		var button := _buttons[i]
		var chosen := i == _selected
		button.text = THREAD_NAMES[_current[i]]
		button.add_theme_stylebox_override("normal", _thread_style(_current[i], chosen))
		button.add_theme_stylebox_override("hover", _thread_style(_current[i], true))
		button.add_theme_stylebox_override("pressed", _thread_style(_current[i], true))
		button.add_theme_color_override("font_color", _label_color(_current[i]))
		button.add_theme_color_override("font_hover_color", _label_color(_current[i]))
		button.add_theme_font_size_override("font_size", 11)


func _on_thread_pressed(index: int) -> void:
	if not running:
		return

	if _selected < 0:
		_selected = index
		Audio.play_sfx(Audio.Sfx.PICKUP)
		_paint_warp()
		set_status("Holding the %s thread. Click another to swap." % THREAD_NAMES[_current[index]])
		return

	if _selected == index:
		_selected = -1
		_paint_warp()
		set_status("Released.")
		return

	var held: int = _current[_selected]
	_current[_selected] = _current[index]
	_current[index] = held
	_selected = -1
	_moves += 1
	Audio.play_sfx(Audio.Sfx.HIT)
	_paint_warp()
	_refresh_moves()

	if _current == _target:
		GameState.unlock_lore("damgo")
		_celebrate_warp()
		succeed("The warp matches the dream. %d move%s - the Master Weaver inclines her head." % [
			_moves, "" if _moves == 1 else "s"])
	elif _moves >= MOVE_BUDGET:
		fail("The move budget is spent and the warp still fights the dream.")


func _refresh_moves() -> void:
	var matched := 0
	for i in range(THREADS):
		if _current[i] == _target[i]:
			matched += 1
	_moves_label.text = "Moves  %d / %d      Threads in place  %d / %d" % [
		_moves, MOVE_BUDGET, matched, THREADS]
	set_status("Click a thread, then click the thread you want it to trade places with.")


func _celebrate_warp() -> void:
	if _warp_row == null:
		return
	var tween := create_tween()
	tween.tween_property(_warp_row, "modulate", Color(1.2, 1.12, 0.9), 0.18)
	tween.tween_property(_warp_row, "modulate", Color.WHITE, 0.35)


func _thread_style(thread_index: int, highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = THREAD_COLORS[thread_index]
	style.border_color = Color(0.98, 0.92, 0.68) if highlight \
		else Color(0.35, 0.3, 0.24, 0.9)
	style.set_border_width_all(3 if highlight else 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	if highlight:
		style.shadow_color = Color(0.98, 0.9, 0.55, 0.45)
		style.shadow_size = 12
	return style


## Keeps the thread name legible against both the black and the cream swatch.
func _label_color(thread_index: int) -> Color:
	var base: Color = THREAD_COLORS[thread_index]
	return Color(0.08, 0.06, 0.05) if base.get_luminance() > 0.5 \
		else Color(0.96, 0.92, 0.82)
