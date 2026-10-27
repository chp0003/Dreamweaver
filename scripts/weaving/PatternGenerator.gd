class_name PatternGenerator
extends RefCounted

const BEIGE := 0
const RED := 1
const BLACK := 2
const GOLD := 3
const GREEN := 4

## Compatibility generator for older isolated weaving scripts.
## The active simple lesson uses PatternData.gd.
static func generate(pattern_id: String, _seed: int, size: Vector2i = Vector2i(24, 18)) -> Array:
	var grid: Array = []
	for row_index in range(size.y):
		var row: Array[int] = []
		for column_index in range(size.x):
			var value := BEIGE
			if pattern_id == "zigzag":
				var point: int = row_index if row_index < size.y / 2 else size.y - 1 - row_index
				value = BLACK if column_index == point * 2 or column_index == point * 2 + 1 else BEIGE
			elif pattern_id == "diamond":
				var center_x: int = size.x / 2
				var center_y: int = size.y / 2
				value = RED if absi(column_index - center_x) == absi(row_index - center_y) else BEIGE
			row.append(value)
		grid.append(row)
	return grid
