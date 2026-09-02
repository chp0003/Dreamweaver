class_name FiberCard
extends PanelContainer
## One strand of abaca in the Fiber Sorting mini-game.
##
## Draggable with Godot's built-in drag API. The player has to judge from the
## strand's description whether it is viable or brittle - the descriptions are
## the actual tell, not a colour code. Visuals still distinguish fibre quality:
## viable strands are long and cream; brittle ones are short, split, and ashen.

const CARD_SIZE := Vector2(176.0, 96.0)

@export var brittle := false
@export var descriptor := ""

var _label: Label
var _strand: _StrandArt


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag onto a basket"
	add_theme_stylebox_override("panel", _card_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(column)

	_strand = _StrandArt.new()
	_strand.brittle = brittle
	_strand.custom_minimum_size = Vector2(0.0, 26.0)
	_strand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_strand)

	_label = Label.new()
	_label.text = descriptor
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = 3
	_label.clip_text = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.custom_minimum_size = Vector2(148.0, 42.0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color",
		Color(0.78, 0.7, 0.58) if brittle else Color(0.94, 0.9, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_label)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = CARD_SIZE
	preview.size = CARD_SIZE
	preview.clip_contents = true
	preview.add_theme_stylebox_override("panel", _card_style())

	var ghost := Label.new()
	ghost.text = descriptor
	ghost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ghost.max_lines_visible = 3
	ghost.clip_text = true
	ghost.custom_minimum_size = Vector2(160.0, 72.0)
	ghost.size = Vector2(160.0, 72.0)
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.add_theme_font_size_override("font_size", 12)
	preview.add_child(ghost)
	preview.modulate = Color(1, 1, 1, 0.9)

	set_drag_preview(preview)
	modulate = Color(1, 1, 1, 0.4)
	return {"card": self}


## Called by the mini-game when a drop is rejected, to put the card back.
func restore_opacity() -> void:
	modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_inside_tree():
		restore_opacity()


func flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)


## Undyed abaca all looks similar; brittle fibre is ashen, viable fibre is cream.
func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if brittle:
		style.bg_color = Color(0.16, 0.14, 0.13, 0.96)
		style.border_color = Color(0.48, 0.36, 0.3, 0.85)
	else:
		style.bg_color = Color(0.2, 0.17, 0.14, 0.96)
		style.border_color = Color(0.72, 0.62, 0.4, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	return style


class _StrandArt extends Control:
	var brittle := false

	func _ready() -> void:
		queue_redraw()
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := maxf(size.x, 8.0)
		var h := maxf(size.y, 8.0)
		var strands := 3 if brittle else 5
		for i in range(strands):
			var y := h * (0.25 + float(i) / float(strands + 1))
			var color := Color(0.55, 0.48, 0.4, 0.9) if brittle \
				else Color(0.9, 0.82, 0.62, 0.95)
			var pts := PackedVector2Array()
			var segs := 8 if brittle else 12
			for s in range(segs + 1):
				var t := float(s) / float(segs)
				var x := w * (0.08 + t * 0.84)
				if brittle:
					x = w * (0.18 + t * 0.55)
				var jag := sin(t * PI * 4.0 + float(i)) * (6.0 if brittle else 3.0)
				if brittle and s % 3 == 0:
					jag += 5.0
				pts.append(Vector2(x, y + jag))
			draw_polyline(pts, color, 2.2 if brittle else 1.8, true)
		if brittle:
			draw_line(Vector2(w * 0.62, h * 0.2), Vector2(w * 0.78, h * 0.8),
				Color(0.42, 0.32, 0.28, 0.7), 1.2)
