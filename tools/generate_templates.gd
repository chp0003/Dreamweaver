extends Node
## Writes a labelled size template PNG for every asset the game expects.
## Requires a rendering device, so run WITHOUT --headless:
##
##   Godot_v4.x_console.exe --path . res://tools/Templates.tscn
##
## Output goes to assets/images/_templates/, mirroring the real asset tree. It is
## deliberately NOT written to the real paths: `placeholder_prop.gd` already draws
## a self-describing labelled block for any missing texture, and dropping an
## anonymous rectangle at a real path would replace that with something less
## useful. These files are artist templates - exact canvas size, exact palette,
## asset name baked in - not runtime art.
##
## Each entry is [relative path, width, height, palette tint].

const OUT_ROOT := "res://assets/images/_templates"

const CATALOG := [
	# ---------------------------------------------------------------- UI: buttons
	["ui/btn_primary_default.png", 320, 50, Palette.RED_SACRED],
	["ui/btn_primary_hover.png", 320, 50, Palette.RED_CRIMSON],
	["ui/btn_primary_pressed.png", 320, 50, Palette.RED_DEEP],
	["ui/btn_primary_disabled.png", 320, 50, Palette.CURSED_ASH],
	["ui/btn_secondary_default.png", 240, 40, Palette.BLACK_SOOT],
	["ui/btn_secondary_hover.png", 240, 40, Palette.BLACK_CHARCOAL],
	["ui/btn_secondary_pressed.png", 240, 40, Palette.BLACK_PITCH],
	["ui/btn_secondary_disabled.png", 240, 40, Palette.CURSED_DEEP],

	# ----------------------------------------------------------------- UI: panels
	["ui/panel_dialogue.png", 880, 200, Palette.BLACK_SOOT],
	["ui/panel_minigame.png", 720, 520, Palette.BLACK_SOOT],
	["ui/panel_inventory.png", 420, 300, Palette.BLACK_SOOT],
	["ui/panel_pause.png", 480, 420, Palette.BLACK_SOOT],
	["ui/panel_quiz.png", 720, 440, Palette.BLACK_SOOT],

	# ----------------------------------------------------------------- UI: inputs
	["ui/input_field.png", 320, 40, Palette.BLACK_PITCH],
	["ui/input_field_focus.png", 320, 40, Palette.BLACK_PITCH],
	["ui/checkbox_off.png", 32, 32, Palette.BLACK_SOOT],
	["ui/checkbox_on.png", 32, 32, Palette.GOLD_SACRED],
	["ui/dropdown.png", 240, 40, Palette.BLACK_SOOT],
	["ui/slider_track.png", 240, 12, Palette.BLACK_PITCH],
	["ui/slider_grip.png", 24, 24, Palette.GOLD_BRASS],

	# -------------------------------------------------------------------- UI: HUD
	["ui/hud/heart_full.png", 16, 16, Palette.RED_SACRED],
	["ui/hud/heart_empty.png", 16, 16, Palette.CURSED_ASH],
	["ui/hud/objective_box.png", 360, 72, Palette.BLACK_SOOT],
	["ui/hud/essence_black.png", 16, 16, Palette.BLACK_CHARCOAL],
	["ui/hud/essence_red.png", 16, 16, Palette.RED_SACRED],
	["ui/hud/essence_gold.png", 16, 16, Palette.GOLD_SACRED],
	["ui/hud/master_pattern.png", 16, 16, Palette.CREAM_WARP],
	["ui/hud/weaving_meter.png", 240, 14, Palette.GOLD_DEEP],
	["ui/hud/minimap_frame.png", 160, 160, Palette.BLACK_SOOT],

	# ------------------------------------------------------------------ UI: icons
	["ui/icons/icon_settings.png", 32, 32, Palette.GOLD_BRASS],
	["ui/icons/icon_save.png", 32, 32, Palette.GOLD_BRASS],
	["ui/icons/icon_volume.png", 32, 32, Palette.GOLD_BRASS],
	["ui/icons/icon_exit.png", 32, 32, Palette.GOLD_BRASS],
	["ui/icons/icon_back.png", 32, 32, Palette.GOLD_BRASS],
	["ui/icons/icon_confirm.png", 32, 32, Palette.GOLD_SACRED],
	["ui/icons/icon_quest.png", 32, 32, Palette.GOLD_SACRED],
	["ui/icons/icon_lore.png", 32, 32, Palette.CREAM_WARP],

	# ------------------------------------------------------- UI: cursor and chrome
	["ui/cursor_default.png", 32, 32, Palette.GOLD_SUN],
	["ui/cursor_point.png", 32, 32, Palette.GOLD_SUN],
	["ui/fade_overlay.png", 64, 64, Palette.CURSED_VOID],
	["ui/spinner_spindle.png", 64, 64, Palette.GOLD_BRASS],
	["ui/title_lockup.png", 640, 220, Palette.GOLD_SACRED],
	["ui/gateway_backdrop.png", 1280, 720, Palette.CURSED_VOID],

	# ----------------------------------------------------------------- UI: motifs
	["ui/motifs/motif_kleng.png", 64, 32, Palette.GOLD_BRASS],
	["ui/motifs/motif_diamond.png", 64, 32, Palette.RED_SACRED],
	["ui/motifs/motif_frog.png", 32, 32, Palette.RED_SACRED],
	["ui/motifs/motif_bird.png", 32, 32, Palette.GOLD_BRASS],
	["ui/motifs/motif_tofi.png", 32, 32, Palette.CREAM_WARP],

	# -------------------------------------------------------------- Characters
	["characters/slang.png", 32, 56, Palette.RED_SACRED],
	["characters/slang_idle_ne.png", 32, 56, Palette.RED_SACRED],
	["characters/slang_idle_nw.png", 32, 56, Palette.RED_SACRED],
	["characters/slang_idle_se.png", 32, 56, Palette.RED_SACRED],
	["characters/slang_idle_sw.png", 32, 56, Palette.RED_SACRED],
	["characters/slang_walk_ne.png", 192, 56, Palette.RED_SACRED],
	["characters/slang_walk_nw.png", 192, 56, Palette.RED_SACRED],
	["characters/slang_walk_se.png", 192, 56, Palette.RED_SACRED],
	["characters/slang_walk_sw.png", 192, 56, Palette.RED_SACRED],
	["characters/slang_attack.png", 256, 64, Palette.GOLD_SACRED],
	["characters/slang_staff_pose.png", 48, 64, Palette.GOLD_SUN],
	["characters/spirit_of_the_fiber.png", 56, 64, Palette.CREAM_STONE],
	["characters/spirit_of_the_fiber_restored.png", 56, 64, Palette.CREAM_WARP],
	["characters/master_weaver_ghost.png", 48, 72, Palette.CREAM_WARP],
	["characters/villager_1.png", 32, 56, Palette.EARTH_CLAY],
	["characters/villager_2.png", 32, 56, Palette.EARTH_CLAY],
	["characters/villager_3.png", 32, 48, Palette.EARTH_CLAY],
	["characters/villager_4.png", 32, 56, Palette.EARTH_CLAY],

	# ------------------------------------------------------------------ Enemies
	["enemies/shadow_minion.png", 32, 40, Palette.BLACK_CHARCOAL],
	["enemies/shadow_minion_attack.png", 160, 48, Palette.BLACK_CHARCOAL],
	["enemies/shadow_minion_death.png", 160, 48, Palette.BLACK_SOOT],
	["enemies/shadow_vine.png", 64, 96, Palette.BLACK_SOOT],
	["enemies/shadow_weaver_boss.png", 160, 200, Palette.BLACK_PITCH],
	["enemies/shadow_weaver_windup.png", 160, 200, Palette.CURSED_LINEN],
	["enemies/shadow_weaver_stunned.png", 160, 200, Palette.CURSED_ASH],
	["enemies/shadow_weaver_dissolve.png", 640, 200, Palette.CURSED_DUST],

	# -------------------------------------------------------------------- Props
	["props/lewet_staff.png", 20, 96, Palette.GOLD_SUN],
	["props/guno_bong_1.png", 112, 140, Palette.BLACK_CHARCOAL],
	["props/guno_bong_2.png", 112, 140, Palette.RED_SACRED],
	["props/guno_bong_3.png", 112, 140, Palette.GOLD_SACRED],
	["props/guno_bong_4.png", 112, 140, Palette.CREAM_STONE],
	["props/guno_bong_5.png", 150, 190, Palette.GOLD_SUN],
	["props/backstrap_loom.png", 84, 58, Palette.EARTH_WOOD],
	["props/loom_small.png", 72, 52, Palette.EARTH_WOOD],
	["props/drying_rack.png", 80, 96, Palette.EARTH_BAMBOO],
	["props/sacred_vat.png", 72, 56, Palette.BLACK_CHARCOAL],
	["props/abaca_plant.png", 64, 80, Palette.LIVING_LEAF],
	["props/abaca_strand.png", 24, 24, Palette.CREAM_PAPER],
	["props/mortar_pestle.png", 56, 52, Palette.CURSED_STONE],
	["props/hulo_root.png", 24, 24, Palette.RED_SACRED],
	["props/red_flowers.png", 48, 40, Palette.RED_CRIMSON],
	["props/wall_torch.png", 32, 64, Palette.GOLD_BRASS],
	["props/brass_mirror.png", 48, 64, Palette.GOLD_BRASS],
	["props/golden_spindle.png", 72, 96, Palette.GOLD_SACRED],
	["props/ablun_loom.png", 128, 96, Palette.EARTH_WOOD],
	["props/ancestor_statue_1.png", 48, 96, Palette.CREAM_STONE],
	["props/ancestor_statue_2.png", 48, 96, Palette.CREAM_STONE],
	["props/ancestor_statue_3.png", 48, 96, Palette.CREAM_STONE],
	["props/ancestor_statue_4.png", 48, 96, Palette.CREAM_STONE],
	["props/sacred_loom.png", 192, 160, Palette.GOLD_SUN],

	# ------------------------------------------------------------- Environments
	["environments/hub/tileset_ridge.png", 256, 256, Palette.EARTH_LOAM],
	["environments/house_black/tileset.png", 256, 256, Palette.BLACK_CHARCOAL],
	["environments/house_red/tileset.png", 256, 256, Palette.RED_DEEP],
	["environments/house_gold/tileset.png", 256, 256, Palette.GOLD_DEEP],
	["environments/house_ancestors/tileset.png", 256, 256, Palette.CREAM_STONE],
	["environments/final_chapter/tileset.png", 256, 256, Palette.BLACK_SOOT],
	["environments/prologue/golden_era.png", 1280, 720, Palette.GOLD_SACRED],
	["environments/prologue/great_bleaching.png", 1280, 720, Palette.CURSED_ASH],
	["environments/prologue/slang_room.png", 1280, 720, Palette.CURSED_DEEP],

	# ------------------------------------------------------------------ Effects
	["effects/shadow_sweep.png", 512, 256, Palette.BLACK_PITCH],
	["effects/chime_shockwave.png", 256, 256, Palette.GOLD_SUN],
	["effects/rhythm_burst.png", 128, 128, Palette.GOLD_SACRED],
	["effects/bleach_projectile.png", 64, 64, Palette.CURSED_BONE],
	["effects/bleach_impact.png", 128, 128, Palette.CURSED_LINEN],
	["effects/color_burst.png", 256, 256, Palette.RED_CRIMSON],
	["effects/gold_streak.png", 512, 128, Palette.GOLD_SUN],
	["effects/torch_glow.png", 128, 128, Palette.GOLD_BRASS],
]

var _viewport: SubViewport
var _background: ColorRect
var _name_label: Label
var _size_label: Label


func _ready() -> void:
	_build_renderer()
	var written := 0

	for entry in CATALOG:
		if await _render_one(entry as Array):
			written += 1

	print("\n===== ASSET TEMPLATES =====")
	print("Written %d / %d to %s" % [written, CATALOG.size(), OUT_ROOT])
	print("===========================\n")
	get_tree().quit(0 if written == CATALOG.size() else 1)


## One reused SubViewport, resized per asset, rather than one per file.
func _build_renderer() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_background)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_viewport.add_child(column)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	_name_label.add_theme_color_override("font_outline_color", Palette.BLACK_PITCH)
	_name_label.add_theme_constant_override("outline_size", 4)
	column.add_child(_name_label)

	_size_label = Label.new()
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_size_label.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	_size_label.add_theme_color_override("font_outline_color", Palette.BLACK_PITCH)
	_size_label.add_theme_constant_override("outline_size", 4)
	column.add_child(_size_label)


func _render_one(entry: Array) -> bool:
	var rel_path := str(entry[0])
	var width := int(entry[1])
	var height := int(entry[2])
	var tint := entry[3] as Color

	_viewport.size = Vector2i(width, height)
	_background.color = tint.darkened(0.55)

	# Below roughly 64 px a name simply will not fit; those get a colour block
	# plus the border, and the manifest carries the name instead.
	var roomy := width >= 64 and height >= 40
	_name_label.visible = roomy
	_size_label.visible = roomy
	if roomy:
		var font_size := clampi(int(float(width) / 16.0), 8, 18)
		_name_label.text = rel_path.get_file().get_basename().replace("_", " ")
		_name_label.add_theme_font_size_override("font_size", font_size)
		_size_label.text = "%d x %d" % [width, height]
		_size_label.add_theme_font_size_override("font_size", maxi(8, font_size - 3))

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var image := _viewport.get_texture().get_image()
	_draw_chrome(image, tint)

	var out_path := OUT_ROOT.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var error := image.save_png(out_path)
	if error != OK:
		print("FAILED %s (%d)" % [rel_path, error])
		return false
	return true


## A brass border plus a kleng zigzag along the top, drawn straight into the
## pixels so the template reads as this project's art and not a stock swatch.
func _draw_chrome(image: Image, tint: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()

	for x in range(w):
		image.set_pixel(x, 0, Palette.GOLD_BRASS)
		image.set_pixel(x, h - 1, Palette.GOLD_BRASS)
	for y in range(h):
		image.set_pixel(0, y, Palette.GOLD_BRASS)
		image.set_pixel(w - 1, y, Palette.GOLD_BRASS)

	if h < 8 or w < 8:
		return

	# Zigzag: 4 px period, 3 px amplitude, inset 2 px from the border.
	var amplitude := mini(3, floori(float(h) / 6.0))
	if amplitude < 1:
		return
	for x in range(2, w - 2):
		var phase := x % (amplitude * 2)
		var offset := phase if phase <= amplitude else amplitude * 2 - phase
		image.set_pixel(x, 2 + offset, tint)
		image.set_pixel(x, h - 3 - offset, tint)
