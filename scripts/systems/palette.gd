class_name Palette
extends RefCounted
## The single source of truth for colour in Dreamweaver.
##
## Every hex value in assets/style_guide.md is mirrored here, so procedural art
## (the ridge backdrop, placeholder props, the isometric floors, the placeholder
## PNG generator) and hand-authored art can never drift apart. When a value
## changes it changes here and in the style guide together.
##
## The palette is organised by the story, not by hue. The world begins in CURSED,
## and each restored House unlocks one of the three sacred dye families.

# --------------------------------------------------------------------------
# Cursed - the bleached world. Deliberately narrow and slightly warm, so it
# reads as "drained cloth" rather than "black and white photograph".
# --------------------------------------------------------------------------

const CURSED_VOID := Color("#0d0c0c")
const CURSED_DEEP := Color("#1a1918")
const CURSED_STONE := Color("#2e2c2a")
const CURSED_ASH := Color("#484543")
const CURSED_DUST := Color("#6b6763")
const CURSED_LINEN := Color("#9a948d")
const CURSED_BONE := Color("#c9c2b8")

# --------------------------------------------------------------------------
# Black Dye Essence - Chapter 1. Abaca soaked in black earth. The foundation
# every T'nalak cloth is built on, so these are structural colours: frames,
# panel fills, shadow.
# --------------------------------------------------------------------------

const BLACK_PITCH := Color("#0a0807")
const BLACK_SOOT := Color("#181312")
const BLACK_CHARCOAL := Color("#241c1a")
const BLACK_BARK := Color("#3a2c27")

# --------------------------------------------------------------------------
# Red Dye Essence - Chapter 2. Hulo root, crushed and fixed. The colour of
# courage; used for primary actions, health, and danger.
# --------------------------------------------------------------------------

const RED_DEEP := Color("#59140f")
const RED_SACRED := Color("#9e2823")
const RED_CRIMSON := Color("#c8352b")
const RED_EMBER := Color("#e2604a")

# --------------------------------------------------------------------------
# Gold Essence - Chapter 3. Brass, sunlight and the turning spindle. Used for
# every border, highlight, header and sacred object.
# --------------------------------------------------------------------------

const GOLD_DEEP := Color("#7a5c1c")
const GOLD_BRASS := Color("#b08a2e")
const GOLD_SACRED := Color("#edd172")
const GOLD_SUN := Color("#f8e9a8")

# --------------------------------------------------------------------------
# Cream - Chapter 4's ancestral stone and the undyed warp threads. Also every
# body of text.
# --------------------------------------------------------------------------

const CREAM_WARP := Color("#f4ead6")
const CREAM_PAPER := Color("#ded2b8")
const CREAM_STONE := Color("#b4a88e")

# --------------------------------------------------------------------------
# Earth - wood, bamboo, soil. The neutral of the restored world.
# --------------------------------------------------------------------------

const EARTH_LOAM := Color("#2b201a")
const EARTH_WOOD := Color("#4d382a")
const EARTH_BAMBOO := Color("#7d6141")
const EARTH_CLAY := Color("#a97f4e")

# --------------------------------------------------------------------------
# Restored - the post-victory world. The only place greens and sky blues are
# permitted, which is what makes the ending land.
# --------------------------------------------------------------------------

const LIVING_MOSS := Color("#3d5230")
const LIVING_LEAF := Color("#6b8a45")
const SKY_DUSK := Color("#1d2c40")
const SKY_DAWN := Color("#c47a3c")

# --------------------------------------------------------------------------
# Dream - the twilight the interface lives in.
#
# The dye families above are the *world's* colours and they stay untouched.
# These are the colours *behind* the world: the night Fun Kdungon speaks from.
# They are cool on purpose. Gold is this game's hero colour, and gold laid on
# warm brown-black turns to mud - it only becomes lantern-light when it sits on
# a cold ground. Every menu wash, panel fill and glow halo comes from here.
# --------------------------------------------------------------------------

const DREAM_ABYSS := Color("#070912")
const DREAM_NIGHT := Color("#0e1326")
const DREAM_INDIGO := Color("#161d3a")
const DREAM_COBALT := Color("#232f5c")
const DREAM_TEAL := Color("#17414a")
const DREAM_VIOLET := Color("#33255a")
## The one cold highlight allowed. Used for focus rings and spirit light, never
## for large fills - it reads as "magic" precisely because it is rationed.
const DREAM_AURORA := Color("#63d6c6")
## Cool muted text, for secondary copy that should recede on a dark ground.
const DREAM_MIST := Color("#93a6cc")
## Warm lantern light. The colour of every glow halo in the game.
const DREAM_LANTERN := Color("#f7e0a4")

# --------------------------------------------------------------------------
# Semantic roles. UI code should reach for these rather than a raw hue, so a
# palette change stays a one-line edit.
# --------------------------------------------------------------------------

const UI_BACKDROP := DREAM_ABYSS
const UI_PANEL := DREAM_NIGHT
const UI_PANEL_RAISED := DREAM_INDIGO
const UI_BORDER := GOLD_BRASS
const UI_BORDER_FOCUS := GOLD_SACRED
const UI_GLOW := DREAM_LANTERN
const UI_FOCUS_RING := DREAM_AURORA
const UI_ACTION := RED_SACRED
const UI_ACTION_HOVER := RED_CRIMSON
const UI_ACTION_PRESSED := RED_DEEP
const UI_TEXT := CREAM_WARP
const UI_TEXT_MUTED := CREAM_STONE
const UI_TEXT_COOL := DREAM_MIST
const UI_TEXT_LABEL := GOLD_BRASS
const UI_HEADING := GOLD_SACRED
const UI_DANGER := RED_EMBER
const UI_DISABLED := CURSED_DUST

## Essence id -> its signature colour. Mirrors Houses.ESSENCE_COLORS.
const ESSENCE := {
	"black": BLACK_CHARCOAL,
	"red": RED_SACRED,
	"gold": GOLD_SACRED,
}


## The accent a House paints its interior and its Hub door with.
static func house_accent(house_id: int) -> Color:
	match house_id:
		1: return BLACK_CHARCOAL
		2: return RED_SACRED
		3: return GOLD_SACRED
		4: return CREAM_STONE
		5: return GOLD_SUN
	return CURSED_ASH


## `color` at a given opacity. Saves writing `Color(Palette.X, 0.4)` everywhere.
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(a, 0.0, 1.0))


## Pushes a colour toward light without washing out its hue, for hover states.
static func lift(color: Color, amount := 0.18) -> Color:
	return color.lerp(Color(1.0, 0.97, 0.9, color.a), clampf(amount, 0.0, 1.0))


## Pushes a colour toward the twilight ground, for recessed or disabled chrome.
static func sink(color: Color, amount := 0.35) -> Color:
	return color.lerp(Color(DREAM_ABYSS, color.a), clampf(amount, 0.0, 1.0))


## Drains a colour toward the cursed palette. `amount` of 1.0 is fully bleached.
## Matches what color_restoration.gdshader does per pixel, so procedural art can
## pre-bleach itself and still agree with the screen shader.
static func bleach(color: Color, amount: float = 1.0) -> Color:
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	# The same faintly warm tint the shader uses, so gray never goes blue.
	var gray := Color(luma * 1.02, luma * 0.99, luma * 0.94, color.a)
	return color.lerp(gray, clampf(amount, 0.0, 1.0))
