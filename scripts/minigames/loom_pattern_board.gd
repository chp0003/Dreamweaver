class_name LoomPatternBoard
extends VBoxContainer
## GridContainer of ThreadCells. Click handling lives on the cells; this board
## only lays them out and forwards the press. Prefer this over TileMap at 8x8:
## every cell is already a Control, so binds/ties need no atlas and no pick mask.

const CELL_SCENE := preload("res://scenes/minigames/ThreadCell.tscn")

signal cell_pressed(cell: Vector2i)

@export var board_title := ""
@export var interactive := false:
	set(value):
		interactive = value
		_sync_interactive()

var _grid: GridContainer
var _title: Label
var _cells: Array = []
var _size := Vector2i.ZERO
var _show_ties := true


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	if _title == null:
		_title = get_node_or_null("Title") as Label
		if _title == null:
			_title = Label.new()
			_title.name = "Title"
			_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_title.theme_type_variation = &"FieldLabel"
			add_child(_title)
	_title.text = board_title
	if _grid == null:
		_grid = get_node_or_null("Frame/Grid") as GridContainer
		if _grid == null:
			_ensure_grid()


func set_title(text: String) -> void:
	board_title = text
	if _title != null:
		_title.text = text


func rebuild(size: Vector2i, show_ties: bool) -> void:
	if _grid == null:
		_ensure_grid()
	_show_ties = show_ties
	_size = size
	while _grid.get_child_count() > 0:
		var old := _grid.get_child(0)
		_grid.remove_child(old)
		old.free()
	_cells.clear()
	_grid.columns = maxi(size.x, 1)
	var frame := get_node_or_null("Frame") as AspectRatioContainer
	if frame != null and size.y > 0:
		frame.ratio = float(size.x) / float(size.y)
		if size.y == 1:
			frame.custom_minimum_size = Vector2(240.0, 36.0)
			frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			frame.custom_minimum_size = Vector2(240.0, 240.0)
			frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for y in range(size.y):
		var row: Array = []
		for x in range(size.x):
			var cell := CELL_SCENE.instantiate() as ThreadCell
			cell.cell = Vector2i(x, y)
			cell.cell_pressed.connect(_on_cell_pressed)
			_grid.add_child(cell)
			row.append(cell)
		_cells.append(row)
	_sync_interactive()


func paint(grid: Array) -> void:
	if _cells.is_empty() or grid.is_empty():
		return
	for y in range(_size.y):
		var src: Array = grid[y]
		for x in range(_size.x):
			(_cells[y][x] as ThreadCell).set_thread(int(src[x]), _show_ties)


func set_cell(cell: Vector2i, state: int) -> void:
	if cell.y < 0 or cell.y >= _cells.size():
		return
	var row: Array = _cells[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return
	(row[cell.x] as ThreadCell).set_thread(state, _show_ties)


func _on_cell_pressed(cell: Vector2i) -> void:
	if interactive:
		cell_pressed.emit(cell)


func _sync_interactive() -> void:
	for row in _cells:
		for cell in row:
			(cell as ThreadCell).set_interactive(interactive)


func _ensure_grid() -> void:
	var frame := get_node_or_null("Frame") as AspectRatioContainer
	if frame == null:
		frame = AspectRatioContainer.new()
		frame.name = "Frame"
		frame.ratio = 1.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
		frame.custom_minimum_size = Vector2(240.0, 240.0)
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(frame)
	_grid = frame.get_node_or_null("Grid") as GridContainer
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "Grid"
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.add_theme_constant_override("h_separation", 3)
		_grid.add_theme_constant_override("v_separation", 3)
		frame.add_child(_grid)
