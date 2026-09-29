extends Node
## Keys, slices and normalises the shadow minion / Shadow Weaver sheets. Run headless:
##   Godot_v4.x_console.exe --headless --path . res://tools/PackShadowSheets.tscn
##
## Generated sheets place 8 frames at roughly even spacing on a flat plate:
## magenta for bodies, black for glowing VFX. Frames are found from the column
## gaps between them, then re-laid on an even grid so the runtime can slice
## equal cells. Every minion strip shares one body scale and one foot baseline.

const SRC_DIR := "res://assets/images/_src/shadow/"
const ENEMY_DIR := "res://assets/images/enemies/"
const MINION_DIR := "res://assets/images/enemies/minion/"
const VFX_DIR := "res://assets/images/vfx/"
const FRAMES := 8

const MINION_CELL := Vector2i(160, 160)
const MINION_BODY_H := 112.0
const MINION_BASELINE := 152

const BOSS_REFERENCE := ENEMY_DIR + "shadow_weaver_idle.png"
## Wider cells than the 1280 skill sheets: the roar flings both arms out.
## The boss slices by sheet width / 8, so the extra room is free.
const BOSS_SHEET := Vector2i(1600, 720)

const VFX_MAX_CELL := 320

var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MINION_DIR))

	# source, output name, reference frame for scale (-1 = median height)
	var minion_jobs := [
		[SRC_DIR + "shadow_minion_idle.jpg", "idle", -1],
		[SRC_DIR + "shadow_minion_walk.jpg", "walk", -1],
		[SRC_DIR + "shadow_minion_hurt.jpg", "hurt", 0],
		[SRC_DIR + "shadow_minion_death.jpg", "death", 0],
		[SRC_DIR + "shadow_minion_spawn.jpg", "spawn", 7],
		[ENEMY_DIR + "shadow_minion_attack.png", "attack", 0],
		[ENEMY_DIR + "shadow_minion_skill_dash.png", "dash", 0],
		[ENEMY_DIR + "shadow_minion_skill_cast.png", "cast", 0],
	]
	for job in minion_jobs:
		_pack_body(job[0], MINION_DIR + String(job[1]) + ".png", int(job[2]),
				MINION_CELL, MINION_BODY_H, MINION_BASELINE)

	var boss_ref := _boss_reference()
	if boss_ref.is_empty():
		_failures.append("boss idle reference unreadable")
	else:
		var cell := Vector2i(BOSS_SHEET.x / FRAMES, BOSS_SHEET.y)
		_pack_body(SRC_DIR + "shadow_weaver_hurt.jpg", ENEMY_DIR + "shadow_weaver_hurt.png", 0,
				cell, boss_ref["height"], int(boss_ref["baseline"]))
		_pack_body(SRC_DIR + "shadow_weaver_roar.jpg", ENEMY_DIR + "shadow_weaver_roar.png", 7,
				cell, boss_ref["height"], int(boss_ref["baseline"]))

	# source, output, anchor
	var vfx_jobs := [
		["shadow_hit_spark", "center"],
		["minion_claw_swipe", "center"],
		["weaver_bolt_impact", "center"],
		["weaver_charge_gather", "center"],
		["weaver_dash_burst", "bottom"],
		["weaver_stun_stars", "center"],
		["weaver_summon_portal", "center"],
	]
	for job in vfx_jobs:
		_pack_vfx(SRC_DIR + String(job[0]) + ".jpg", VFX_DIR + String(job[0]) + ".png", String(job[1]))

	print("\n===== PACK SHADOW SHEETS =====")
	if _failures.is_empty():
		print("RESULT: OK")
	else:
		for failure in _failures:
			print("  - " + failure)
	print("==============================\n")
	get_tree().quit(0 if _failures.is_empty() else 1)


# --------------------------------------------------------------------------
# Jobs
# --------------------------------------------------------------------------

func _pack_body(src: String, dst: String, ref_frame: int, cell: Vector2i,
		body_h: float, baseline: int) -> void:
	var image := _load(src)
	if image == null:
		_failures.append("missing " + src)
		return
	_key_magenta(image)
	_despeckle(image)
	var frames := _find_frames(image)
	var heights: Array[int] = []
	for rect in frames:
		heights.append(rect.size.y)
	var ref_h := 0
	if ref_frame >= 0 and ref_frame < frames.size():
		ref_h = frames[ref_frame].size.y
	else:
		var sorted := heights.duplicate()
		sorted.sort()
		ref_h = sorted[sorted.size() / 2]
	if ref_h < 8:
		_failures.append("no body found in " + src)
		return
	var scale_factor := body_h / float(ref_h)

	var sheet := Image.create(cell.x * FRAMES, cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in range(frames.size()):
		var rect: Rect2i = frames[i]
		if rect.size.x < 2 or rect.size.y < 2:
			continue
		var crop := image.get_region(rect)
		var feet_x := _feet_centroid_x(crop)
		var tw := maxi(1, int(round(rect.size.x * scale_factor)))
		var th := maxi(1, int(round(rect.size.y * scale_factor)))
		crop.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var origin := Vector2i(
			i * cell.x + cell.x / 2 - int(round(feet_x * scale_factor)),
			baseline - th
		)
		_blit_clipped(sheet, crop, origin, Rect2i(i * cell.x, 0, cell.x, cell.y))
	_save(sheet, dst)
	print("body  %-34s frames=%d ref_h=%d scale=%.3f" % [dst.get_file(), frames.size(), ref_h, scale_factor])


func _pack_vfx(src: String, dst: String, anchor: String) -> void:
	var image := _load(src)
	if image == null:
		_failures.append("missing " + src)
		return
	_key_black(image)
	_despeckle(image)
	var frames := _find_frames(image)
	var extent := 16
	for rect in frames:
		extent = maxi(extent, maxi(rect.size.x, rect.size.y))
	var scale_factor := minf(1.0, float(VFX_MAX_CELL - 8) / float(extent))
	var side := mini(VFX_MAX_CELL, int(ceil(extent * scale_factor)) + 8)
	side += side % 2

	var sheet := Image.create(side * FRAMES, side, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in range(frames.size()):
		var rect: Rect2i = frames[i]
		if rect.size.x < 1 or rect.size.y < 1:
			continue
		var crop := image.get_region(rect)
		var tw := maxi(1, int(round(rect.size.x * scale_factor)))
		var th := maxi(1, int(round(rect.size.y * scale_factor)))
		if scale_factor < 0.999:
			crop.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var oy := (side - th) / 2 if anchor == "center" else side - 4 - th
		var origin := Vector2i(i * side + (side - tw) / 2, oy)
		_blit_clipped(sheet, crop, origin, Rect2i(i * side, 0, side, side))
	_save(sheet, dst)
	print("vfx   %-34s frames=%d cell=%d scale=%.3f" % [dst.get_file(), frames.size(), side, scale_factor])


func _boss_reference() -> Dictionary:
	var image := _load(BOSS_REFERENCE)
	if image == null:
		return {}
	var fw := image.get_width() / FRAMES
	var heights: Array[int] = []
	var bottoms: Array[int] = []
	for i in range(FRAMES):
		var used := image.get_region(Rect2i(i * fw, 0, fw, image.get_height())).get_used_rect()
		if used.size.y > 8:
			heights.append(used.size.y)
			bottoms.append(used.position.y + used.size.y)
	if heights.is_empty():
		return {}
	heights.sort()
	bottoms.sort()
	print("boss reference: median height=%d baseline=%d" % [heights[heights.size() / 2], bottoms[bottoms.size() / 2]])
	return {"height": float(heights[heights.size() / 2]), "baseline": bottoms[bottoms.size() / 2]}


# --------------------------------------------------------------------------
# Keying
# --------------------------------------------------------------------------

## Plate colour is averaged from the four corners because generated plates
## carry faint noise. Already-transparent sheets are left alone.
func _key_magenta(image: Image) -> void:
	var key := _corner_colour(image)
	if key.a < 0.5:
		return
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	const HARD := 0.22
	const SOFT := 0.38
	for i in range(0, w * h * 4, 4):
		var r := data[i] / 255.0
		var g := data[i + 1] / 255.0
		var b := data[i + 2] / 255.0
		var d := sqrt((r - key.r) * (r - key.r) + (g - key.g) * (g - key.g) + (b - key.b) * (b - key.b))
		var bright_magenta := r > 0.62 and b > 0.5 and g < 0.3 and (r + b) > g * 4.0
		if d < HARD or bright_magenta:
			data[i + 3] = 0
			continue
		if d < SOFT:
			var keep := (d - HARD) / (SOFT - HARD)
			var spill := minf(r, b) - g
			if spill > 0.0:
				r -= spill * (1.0 - keep)
				b -= spill * (1.0 - keep)
			data[i] = int(clampf(r, 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf(b, 0.0, 1.0) * 255.0)
			data[i + 3] = int(data[i + 3] * keep)
	image.set_data(w, h, false, Image.FORMAT_RGBA8, data)


## Glow on black: brightness becomes alpha and colour is un-premultiplied,
## so additive and normal blending both reproduce the original look.
func _key_black(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	const FLOOR := 0.07
	for i in range(0, w * h * 4, 4):
		var r := data[i] / 255.0
		var g := data[i + 1] / 255.0
		var b := data[i + 2] / 255.0
		var m := maxf(r, maxf(g, b))
		if m <= FLOOR:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
			data[i + 3] = 0
			continue
		var alpha := clampf((m - FLOOR) / (1.0 - FLOOR), 0.0, 1.0)
		data[i] = int(clampf(r / m, 0.0, 1.0) * 255.0)
		data[i + 1] = int(clampf(g / m, 0.0, 1.0) * 255.0)
		data[i + 2] = int(clampf(b / m, 0.0, 1.0) * 255.0)
		data[i + 3] = int(alpha * 255.0)
	image.set_data(w, h, false, Image.FORMAT_RGBA8, data)


func _corner_colour(image: Image) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for corner in [Vector2i(2, 2), Vector2i(w - 10, 2), Vector2i(2, h - 10), Vector2i(w - 10, h - 10)]:
		for y in range(8):
			for x in range(8):
				sum += image.get_pixel(corner.x + x, corner.y + y)
				count += 1
	return sum / float(count)


## Drops lone opaque pixels left by plate noise.
func _despeckle(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var out := data.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := (y * w + x) * 4 + 3
			if data[i] < 26:
				continue
			var neighbours := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and data[((y + dy) * w + x + dx) * 4 + 3] >= 26:
						neighbours += 1
			if neighbours <= 1:
				out[i] = 0
	image.set_data(w, h, false, Image.FORMAT_RGBA8, out)


# --------------------------------------------------------------------------
# Frame detection
# --------------------------------------------------------------------------

## Column runs are assigned to the nearest of 8 even slots, so sparks that
## drift between figures still join the right frame.
func _find_frames(image: Image) -> Array[Rect2i]:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var column := PackedInt32Array()
	column.resize(w)
	for y in range(h):
		var row := y * w * 4
		for x in range(w):
			if data[row + x * 4 + 3] >= 26:
				column[x] += 1

	var pitch := float(w) / float(FRAMES)
	var slot_min: Array[int] = []
	var slot_max: Array[int] = []
	for i in range(FRAMES):
		slot_min.append(w)
		slot_max.append(-1)

	var x := 0
	while x < w:
		if column[x] < 1:
			x += 1
			continue
		var start := x
		while x < w and column[x] >= 1:
			x += 1
		var end := x - 1
		# A wide blast is still one frame; only a run covering two frame
		# centres is two touching figures, and those are cut between centres.
		var centres: Array[int] = []
		for slot in range(FRAMES):
			var centre := (slot + 0.5) * pitch
			if centre >= start and centre <= end:
				centres.append(slot)
		if centres.size() <= 1:
			var slot := centres[0] if centres.size() == 1 else clampi(int(((start + end) * 0.5) / pitch), 0, FRAMES - 1)
			slot_min[slot] = mini(slot_min[slot], start)
			slot_max[slot] = maxi(slot_max[slot], end)
			continue
		var piece_start := start
		for i in range(centres.size()):
			var slot: int = centres[i]
			var piece_end := end if i == centres.size() - 1 else int((slot + 1) * pitch) - 1
			slot_min[slot] = mini(slot_min[slot], piece_start)
			slot_max[slot] = maxi(slot_max[slot], piece_end)
			piece_start = piece_end + 1

	var frames: Array[Rect2i] = []
	for i in range(FRAMES):
		if slot_max[i] < 0:
			frames.append(Rect2i())
			continue
		var top := h
		var bottom := -1
		for y in range(h):
			var row := y * w * 4
			for sx in range(slot_min[i], slot_max[i] + 1):
				if data[row + sx * 4 + 3] >= 26:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					break
		if bottom < 0:
			frames.append(Rect2i())
			continue
		frames.append(Rect2i(slot_min[i], top, slot_max[i] - slot_min[i] + 1, bottom - top + 1))
	return frames


## Feet stay planted across poses, so frames are aligned on the lower body
## rather than on a bounding box that swings with every arm and wisp.
func _feet_centroid_x(crop: Image) -> float:
	var w := crop.get_width()
	var h := crop.get_height()
	var from_y := int(h * 0.72)
	var sum := 0.0
	var count := 0.0
	for y in range(from_y, h):
		for x in range(w):
			var a := crop.get_pixel(x, y).a
			if a > 0.1:
				sum += x * a
				count += a
	return sum / count if count > 0.0 else w * 0.5


# --------------------------------------------------------------------------
# IO
# --------------------------------------------------------------------------

func _blit_clipped(dst: Image, src: Image, origin: Vector2i, clip: Rect2i) -> void:
	var src_rect := Rect2i(Vector2i.ZERO, src.get_size())
	var placed := Rect2i(origin, src.get_size()).intersection(clip)
	if placed.size.x <= 0 or placed.size.y <= 0:
		return
	src_rect.position += placed.position - origin
	src_rect.size = placed.size
	dst.blend_rect(src, src_rect, placed.position)


func _load(path: String) -> Image:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, path: String) -> void:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_failures.append("save failed %s (%d)" % [path, err])
