class_name UiStyle
extends RefCounted
## StyleBox factory for the interface's "lit glass" look.
##
## Every panel in the game is the same object: a cool translucent pane sitting
## on the twilight, held by a thin warm hairline, with a soft halo bleeding out
## behind it. Nothing is a hard-edged black rectangle any more.
##
## The three things that do the work:
##   - `shadow_size` with a matching `shadow_color` is Godot's only built-in
##     soft edge for a StyleBoxFlat. Tinting it warm turns a drop shadow into a
##     glow, which is what carries the lantern feel.
##   - Border alpha stays low (0.2-0.5). A full-strength gold outline looks like
##     a spreadsheet; a faint one looks like gilding.
##   - Corners are always rounded. Sharp corners are the single biggest reason
##     procedural UI reads as programmer art.

## Shared corner radius, so nothing looks bolted on from a different screen.
const RADIUS := 10
const RADIUS_SMALL := 6
const RADIUS_PILL := 999


# --------------------------------------------------------------------------
# Panels
# --------------------------------------------------------------------------

## The standard pane: dialogue boxes, HUD plates, mini-game shells.
static func glass(fill := Palette.DREAM_NIGHT, opacity := 0.82, pad := 18,
		border := Palette.GOLD_BRASS, border_opacity := 0.28) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.alpha(fill, opacity)
	box.set_border_width_all(1)
	box.border_color = Palette.alpha(border, border_opacity)
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(float(pad))
	box.shadow_color = Palette.alpha(Palette.DREAM_ABYSS, 0.55)
	box.shadow_size = 14
	box.anti_aliasing = true
	return box


## A pane that is lit from within - the focused card on a screen. The halo is
## warm rather than black, so it reads as light spilling out instead of depth.
static func glass_lit(fill := Palette.DREAM_INDIGO, opacity := 0.9, pad := 18,
		glow := Palette.DREAM_LANTERN, glow_strength := 0.28) -> StyleBoxFlat:
	var box := glass(fill, opacity, pad)
	box.border_color = Palette.alpha(Palette.GOLD_SACRED, 0.62)
	box.shadow_color = Palette.alpha(glow, glow_strength)
	box.shadow_size = 24
	return box


## Nearly invisible - just enough tint to lift text off a busy background.
## Used for HUD plates, where a solid panel would fight the world art.
static func veil(opacity := 0.42, pad := 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.alpha(Palette.DREAM_ABYSS, opacity)
	box.set_border_width_all(0)
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(float(pad))
	box.shadow_color = Palette.alpha(Palette.DREAM_ABYSS, opacity * 0.7)
	box.shadow_size = 18
	box.anti_aliasing = true
	return box


## A house/essence-coloured card. The accent shows as a warm inner wash and a
## brighter left edge, which is how the Hub tells five doors apart at a glance.
static func accent_card(accent: Color, opacity := 0.8, pad := 16) -> StyleBoxFlat:
	var box := glass(Palette.DREAM_NIGHT.lerp(accent, 0.22), opacity, pad)
	box.border_color = Palette.alpha(accent, 0.5)
	box.border_width_left = 3
	box.shadow_color = Palette.alpha(accent, 0.22)
	box.shadow_size = 18
	return box


# --------------------------------------------------------------------------
# Buttons
# --------------------------------------------------------------------------

## Buttons are pills. `tint` colours the fill, `glow` the halo behind it.
static func button(tint: Color, opacity := 0.55, glow_strength := 0.0,
		border_opacity := 0.35) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.alpha(tint, opacity)
	box.set_border_width_all(1)
	box.border_color = Palette.alpha(Palette.GOLD_BRASS, border_opacity)
	box.set_corner_radius_all(RADIUS_PILL)
	box.content_margin_left = 30.0
	box.content_margin_right = 30.0
	box.content_margin_top = 13.0
	box.content_margin_bottom = 13.0
	box.shadow_color = Palette.alpha(Palette.DREAM_LANTERN, glow_strength)
	box.shadow_size = 20 if glow_strength > 0.0 else 0
	box.anti_aliasing = true
	return box


# --------------------------------------------------------------------------
# Bars
# --------------------------------------------------------------------------

## Bar tracks are dark and recessed, so a half-empty bar still reads as a
## complete object rather than a floating stub of colour.
static func bar_track(height := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.alpha(Palette.DREAM_ABYSS, 0.72)
	box.set_border_width_all(1)
	box.border_color = Palette.alpha(Palette.GOLD_BRASS, 0.22)
	box.set_corner_radius_all(maxi(2, height / 2))
	box.anti_aliasing = true
	return box


## Bar fills glow in their own colour, which is what sells a health bar as
## something burning down rather than a red rectangle getting shorter.
static func bar_fill(color: Color, height := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(0)
	box.set_corner_radius_all(maxi(2, height / 2))
	box.shadow_color = Palette.alpha(color, 0.45)
	box.shadow_size = 7
	box.anti_aliasing = true
	return box


# --------------------------------------------------------------------------
# Text
# --------------------------------------------------------------------------

## Dark outline so light text survives on top of bright world art. Kept as a
## helper because the outline colour must match the twilight, not pure black -
## a black halo around cream text looks like a sticker.
static func outline_label(label: Label, size := 6,
		color := Palette.DREAM_ABYSS) -> void:
	label.add_theme_color_override("font_outline_color", Palette.alpha(color, 0.9))
	label.add_theme_constant_override("outline_size", size)


## Warm glow behind text, for headings that should look lit. Godot has no text
## glow, so this fakes it with a wide, very soft outline in the glow colour
## underneath the usual dark one.
static func glow_label(label: Label, color := Palette.DREAM_LANTERN,
		size := 10) -> void:
	label.add_theme_color_override("font_shadow_color", Palette.alpha(color, 0.30))
	label.add_theme_constant_override("shadow_outline_size", size)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
