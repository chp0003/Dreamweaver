extends Node
## Imports AI-generated art from the Cursor assets folder into the game tree:
## chroma-keys studio mattes, crops to content, and resizes to sprite sizes.

const SRC := "C:/Users/Admin/.cursor/projects/e-dreamweaver/assets"

## [source_filename, dest_res_path, target_width, target_height]
const JOBS := [
	# Already imported core cast / hub (re-run safe)
	["slang.png", "res://assets/images/characters/slang.png", 64, 96],
	["guno_bong_1.png", "res://assets/images/props/guno_bong_1.png", 160, 200],
	["guno_bong_2.png", "res://assets/images/props/guno_bong_2.png", 160, 200],
	["guno_bong_3.png", "res://assets/images/props/guno_bong_3.png", 160, 200],
	["guno_bong_4.png", "res://assets/images/props/guno_bong_4.png", 160, 200],
	["guno_bong_5.png", "res://assets/images/props/guno_bong_5.png", 200, 240],
	["highland_grass.png", "res://assets/images/props/highland_grass.png", 48, 56],
	["tileset_ridge.png", "res://assets/images/environments/hub/tileset_ridge.png", 512, 512],

	# Floors
	["tileset_interior_wood.png", "res://assets/images/environments/prologue/tileset_interior_wood.png", 512, 512],
	["tileset_interior_wood_v2.png", "res://assets/images/environments/prologue/tileset_interior_wood.png", 512, 512],
	["tileset_house_black.png", "res://assets/images/environments/house_black/tileset.png", 512, 512],

	# Tutorial props
	["sleeping_mat.png", "res://assets/images/props/sleeping_mat.png", 120, 48],
	["backstrap_loom.png", "res://assets/images/props/backstrap_loom.png", 120, 90],
	["unfinished_tnalak.png", "res://assets/images/props/unfinished_tnalak.png", 96, 72],
	["lewet_staff.png", "res://assets/images/props/lewet_staff.png", 32, 110],
	["wall_panel.png", "res://assets/images/props/wall_panel.png", 72, 120],

	# Chapter 1
	["spirit_of_the_fiber.png", "res://assets/images/characters/spirit_of_the_fiber.png", 64, 96],
	["drying_rack.png", "res://assets/images/props/drying_rack.png", 110, 90],
	["sacred_vat.png", "res://assets/images/props/sacred_vat.png", 90, 90],
	["loom_small.png", "res://assets/images/props/loom_small.png", 110, 80],
	["abaca_plant.png", "res://assets/images/props/abaca_plant.png", 56, 110],
	["stripping_bench.png", "res://assets/images/props/stripping_bench.png", 100, 70],
	["abaca_strand.png", "res://assets/images/props/abaca_strand.png", 28, 28],
	["fibre_basket.png", "res://assets/images/props/fibre_basket.png", 48, 48],
	["doorway_garden.png", "res://assets/images/props/doorway_garden.png", 64, 80],

	# Chapter 2 — House of Red Courage
	["tileset_house_red.png", "res://assets/images/environments/house_red/tileset.png", 512, 512],
	["storage_crate.png", "res://assets/images/props/storage_crate.png", 56, 62],
	["door_frame.png", "res://assets/images/props/door_frame.png", 200, 48],
	["barred_window.png", "res://assets/images/props/barred_window.png", 48, 78],
	["mortar_pestle.png", "res://assets/images/props/mortar_pestle.png", 72, 62],
	["red_flowers.png", "res://assets/images/props/red_flowers.png", 56, 46],
	["hulo_root.png", "res://assets/images/props/hulo_root.png", 28, 28],
	["shadow_vine.png", "res://assets/images/enemies/shadow_vine.png", 40, 120],
	["shadow_minion.png", "res://assets/images/enemies/shadow_minion.png", 48, 64],
]


func _ready() -> void:
	var ok := 0
	var skipped := 0
	for job in JOBS:
		var src_name := str(job[0])
		var src_path := SRC.path_join(src_name)
		if not FileAccess.file_exists(src_path):
			print("SKIP missing source %s" % src_name)
			skipped += 1
			continue
		if _import(src_name, str(job[1]), int(job[2]), int(job[3])):
			ok += 1
	print("===== ART IMPORT =====")
	print("Imported %d   skipped %d   catalog %d" % [ok, skipped, JOBS.size()])
	print("======================")
	get_tree().quit(0 if skipped == 0 else 0)


func _import(src_name: String, dest_path: String, tw: int, th: int) -> bool:
	var src_path := SRC.path_join(src_name)
	var image := Image.new()
	var err := image.load(src_path)
	if err != OK:
		print("LOAD FAIL %s (%d)" % [src_path, err])
		return false

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var cleared := _clear_matte(image)
	image = _crop_to_alpha(image)
	if image.get_width() < 4 or image.get_height() < 4:
		print("EMPTY after key %s (cleared %d)" % [src_name, cleared])
		return false

	image = _fit_bottom(image, tw, th)
	var corner_a := image.get_pixel(0, 0).a
	DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
	err = image.save_png(ProjectSettings.globalize_path(dest_path))
	if err != OK:
		print("SAVE FAIL %s (%d)" % [dest_path, err])
		return false
	print("OK  %s -> %s (%dx%d) cleared=%d corner_a=%.2f" % [
		src_name, dest_path, tw, th, cleared, corner_a])
	return true


func _clear_matte(image: Image) -> int:
	var w := image.get_width()
	var h := image.get_height()
	var stack: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var cleared := 0

	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))

	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if seen[idx] == 1:
			continue
		seen[idx] = 1

		var c := image.get_pixel(p.x, p.y)
		if not _is_matte(c):
			continue

		if c.a > 0.01:
			c.a = 0.0
			image.set_pixel(p.x, p.y, c)
			cleared += 1

		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

	return cleared


func _is_matte(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	if chroma > 0.14:
		return false
	return luma < 0.22 or luma > 0.82


func _crop_to_alpha(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return image
	min_x = maxi(0, min_x - 2)
	min_y = maxi(0, min_y - 2)
	max_x = mini(w - 1, max_x + 2)
	max_y = mini(h - 1, max_y + 2)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


func _fit_bottom(src: Image, tw: int, th: int) -> Image:
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var sw := float(src.get_width())
	var sh := float(src.get_height())
	var scale := minf(float(tw) / sw, float(th) / sh)
	var nw := maxi(1, int(sw * scale))
	var nh := maxi(1, int(sh * scale))
	src.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)

	var out := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var ox := (tw - nw) / 2
	var oy := th - nh
	out.blit_rect(src, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
	return out
