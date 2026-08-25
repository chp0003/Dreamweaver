class_name EssenceChip
extends Control
## Essence pip. Owned dyes burn like a held lantern; missing ones are frost rings.

var essence_id := "black"
var owned := false


func _ready() -> void:
	custom_minimum_size = Vector2(58.0, 54.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = Houses.essence_name(essence_id)


func configure(id: String, is_owned: bool) -> void:
	essence_id = id
	owned = is_owned
	tooltip_text = Houses.essence_name(id)
	queue_redraw()


func _draw() -> void:
	var color: Color = Houses.essence_color(essence_id)
	var cx := size.x * 0.5
	var cy := 18.0
	if owned:
		draw_circle(Vector2(cx, cy), 16.0, Palette.alpha(color, 0.18))
		draw_circle(Vector2(cx, cy), 11.0, Palette.alpha(color, 0.4))
		draw_circle(Vector2(cx, cy), 7.5, color)
		draw_circle(Vector2(cx - 2.4, cy - 2.6), 2.2, Palette.alpha(Palette.GOLD_SUN, 0.7))
		draw_arc(Vector2(cx, cy), 11.0, 0.0, TAU, 28, Palette.alpha(Palette.DREAM_LANTERN, 0.45), 1.2)
	else:
		draw_arc(Vector2(cx, cy), 8.5, 0.0, TAU, 28, Palette.alpha(Palette.DREAM_MIST, 0.35), 1.6)
		draw_circle(Vector2(cx, cy), 3.0, Palette.alpha(Palette.DREAM_MIST, 0.18))

	var caption := Houses.essence_name(essence_id).replace(" Essence", "").replace(" Dye", "")
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0.0, 48.0),
		caption.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		10,
		Palette.alpha(Palette.CREAM_WARP, 0.95) if owned else Palette.alpha(Palette.DREAM_MIST, 0.5)
	)
