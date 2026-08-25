extends MiniGameBase
## Chapter 3 - "Pattern Memory".
##
## A snake pattern (the klawang motif) lights up across nine floor tiles. The
## player replays it by clicking the tiles in order. Three rounds of growing
## length; one wrong tile costs the attempt.

const ROUNDS := 3
const START_LENGTH := 3
const FLASH_ON := 0.42
const FLASH_GAP := 0.18

var _grid: GridContainer
var _tiles: Array[Button] = []
var _sequence: Array[int] = []
var _input_index := 0
var _round := 0
var _accepting := false


func _configure() -> void:
	mini_game_title = "Pattern Memory"
	mini_game_subtitle = "House of the Golden Sun"
	instructions = "Watch the snake pattern travel across the floor tiles, then repeat it in the same order. Three patterns, each longer than the last."
	time_limit = 0.0
	max_attempts = 3


func _build_content(parent: Control) -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_grid)

	for i in range(9):
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(112.0, 84.0)
		tile.text = ""
		tile.add_theme_stylebox_override("normal", _tile_style(false))
		tile.add_theme_stylebox_override("hover", _tile_style(false, true))
		tile.add_theme_stylebox_override("pressed", _tile_style(true))
		tile.focus_mode = Control.FOCUS_NONE
		tile.pressed.connect(_on_tile_pressed.bind(i))
		_grid.add_child(tile)
		_tiles.append(tile)


func _reset_round() -> void:
	_round = 0
	_start_next_pattern()


func _start_next_pattern() -> void:
	_round += 1
	if _round > ROUNDS:
		GameState.unlock_lore("kleng")
		succeed("Three patterns held in memory. The floor remembers the snake, and the room remembers the sun.")
		return

	_sequence = _make_snake(START_LENGTH + _round - 1)
	_input_index = 0
	set_status("Pattern %d of %d - watch." % [_round, ROUNDS])
	_play_sequence()


## Builds a path where each step is adjacent to the last, so it reads as a snake
## crossing the floor rather than random blinking.
func _make_snake(length: int) -> Array[int]:
	var path: Array[int] = []
	path.append(randi() % 9)
	while path.size() < length:
		var current: int = path[path.size() - 1]
		var neighbours := _neighbours(current)
		neighbours.shuffle()
		var picked := -1
		for candidate in neighbours:
			if not path.has(candidate):
				picked = candidate
				break
		if picked < 0:
			# Boxed in: restart the walk rather than repeat a tile.
			path.clear()
			path.append(randi() % 9)
			continue
		path.append(picked)
	return path


func _neighbours(index: int) -> Array[int]:
	var x := index % 3
	var y := floori(float(index) / 3.0)
	var result: Array[int] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for offset in offsets:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx >= 0 and nx < 3 and ny >= 0 and ny < 3:
			result.append(ny * 3 + nx)
	return result


func _play_sequence() -> void:
	_accepting = false
	for index in _sequence:
		if not running or not is_inside_tree():
			return
		_light_tile(index, Color(0.95, 0.83, 0.42))
		Audio.play_sfx(Audio.Sfx.PICKUP)
		await get_tree().create_timer(FLASH_ON).timeout
		if not running or not is_inside_tree():
			return
		_unlight_tile(index)
		await get_tree().create_timer(FLASH_GAP).timeout
	if not running or not is_inside_tree():
		return
	_accepting = true
	set_status("Pattern %d of %d - now repeat it." % [_round, ROUNDS])


func _on_tile_pressed(index: int) -> void:
	if not running or not _accepting:
		return

	if index == _sequence[_input_index]:
		_input_index += 1
		GameState.add_score(15)
		_pulse_tile(index, Color(0.6, 0.85, 0.55))
		if _input_index >= _sequence.size():
			_accepting = false
			await get_tree().create_timer(0.4).timeout
			if running and is_inside_tree():
				_start_next_pattern()
	else:
		_accepting = false
		_pulse_tile(index, Color(0.85, 0.3, 0.26))
		fail("The pattern broke at step %d. The snake does not double back." % (_input_index + 1))


func _light_tile(index: int, color: Color) -> void:
	_tiles[index].add_theme_stylebox_override("normal", _tile_style(true, false, color))


func _unlight_tile(index: int) -> void:
	_tiles[index].add_theme_stylebox_override("normal", _tile_style(false))


func _pulse_tile(index: int, color: Color) -> void:
	_light_tile(index, color)
	var tile := _tiles[index]
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(func() -> void:
		if is_instance_valid(tile):
			tile.add_theme_stylebox_override("normal", _tile_style(false)))


## Floor tiles are drawn as flat rectangles rather than diamonds; the mini-game
## is a UI overlay, so a clean grid reads better than a fake isometric one.
func _tile_style(lit: bool, hover := false, lit_color := Color(0.95, 0.83, 0.42)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if lit:
		style.bg_color = lit_color
		style.border_color = lit_color.lightened(0.3)
		style.shadow_color = Color(lit_color, 0.55)
		style.shadow_size = 18
	else:
		style.bg_color = Color(0.16, 0.15, 0.14, 0.95) if not hover \
			else Color(0.22, 0.2, 0.17, 0.95)
		style.border_color = Color(0.5, 0.42, 0.26, 0.8)
		style.shadow_size = 0
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	# Woven floor tile: a faint inner diamond via extra left/right border weight.
	style.border_width_left = 3
	style.border_width_right = 3
	return style
