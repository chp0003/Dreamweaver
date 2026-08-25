extends Node
## Bakes a T'nalak isometric floor mark so the quest tile is art, not a wireframe.

const OUT := "res://assets/images/props/quest_mark.png"
const SIZE := Vector2i(128, 64)


func _ready() -> void:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint(img)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("quest_mark saved err=%d" % err)
	get_tree().quit(0 if err == OK else 1)


func _paint(img: Image) -> void:
	var cx := SIZE.x * 0.5
	var cy := SIZE.y * 0.5
	var hw := 60.0
	var hh := 30.0
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var nx := (float(x) - cx) / hw
			var ny := (float(y) - cy) / hh
			var d := absf(nx) + absf(ny)
			if d > 1.0:
				continue
			var edge := 1.0 - d
			var weave := 0.5 + 0.5 * sin((nx + ny) * 14.0) * sin((nx - ny) * 9.0)
			var gold := Palette.GOLD_BRASS.lerp(Palette.GOLD_SUN, clampf(edge * 0.85 + weave * 0.25, 0.0, 1.0))
			var cream := Palette.CREAM_WARP
			var col := gold.lerp(cream, weave * 0.28)
			if d > 0.86:
				col = Palette.GOLD_SACRED
			elif d < 0.18:
				col = Palette.GOLD_SUN
			col.a = clampf(0.55 + edge * 0.45, 0.0, 1.0)
			img.set_pixel(x, y, col)
