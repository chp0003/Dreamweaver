# Dreamweaver — Visual Style Guide

The single reference every asset in this project must match. Palette values here are mirrored exactly in `scripts/systems/palette.gd`, which procedural art reads at runtime — **change a colour in both places or not at all.**

---

## 1. The core rule

The world is a cloth that has had its colour taken out of it, and S'lang puts it back. Every visual decision serves that one idea:

- **Generate and author all art in full colour.** Never hand in pre-greyed art. Desaturation is applied at runtime by `shaders/color_restoration.gdshader`, and art that ships grey can never be restored — it would stay dead after the Color Burst.
- **Colour is a reward, not decoration.** In gameplay scenes the only saturated things are the Lewet Staff, restored Houses, and the HUD. If everything glows, nothing does.
- **The UI is outside the curse.** Menus, dialogue and the HUD stay in full colour at all times. The veil renders on canvas layer 100; the HUD sits at 110+ deliberately so it stays readable while the world behind it is drained.

---

## 2. Palette

Organised by the story rather than by hue. Each family arrives with the House that restores it.

### Cursed — the bleached world

Deliberately narrow and very slightly warm, so it reads as drained cloth rather than a black-and-white photograph.

| Token | Hex | Use |
| --- | --- | --- |
| `CURSED_VOID` | `#0d0c0c` | Deepest shadow, letterbox bars, fade overlay |
| `CURSED_DEEP` | `#1a1918` | Bleached floor base |
| `CURSED_STONE` | `#2e2c2a` | Bleached walls and large props |
| `CURSED_ASH` | `#484543` | Bleached mid-tone, locked-house tint |
| `CURSED_DUST` | `#6b6763` | Disabled text and controls |
| `CURSED_LINEN` | `#9a948d` | Bleached highlight |
| `CURSED_BONE` | `#c9c2b8` | Brightest bleached value |

### Black Dye Essence — Chapter 1

Abaca soaked in black earth. The foundation every T'nalak is built on, so these are the structural colours: frames, panel fills, shadow.

| Token | Hex | Use |
| --- | --- | --- |
| `BLACK_PITCH` | `#0a0807` | Text outlines, silhouettes |
| `BLACK_SOOT` | `#181312` | World wood, cursed interiors |
| `BLACK_CHARCOAL` | `#241c1a` | Raised panel, Black essence icon |
| `BLACK_BARK` | `#3a2c27` | Dark wood |

### Red Dye Essence — Chapter 2

Hulo root, crushed and fixed. The colour of courage: primary actions, health, danger.

| Token | Hex | Use |
| --- | --- | --- |
| `RED_DEEP` | `#59140f` | Pressed button, deep shadow in red cloth |
| `RED_SACRED` | `#9e2823` | **Primary button fill**, health bar, Red essence |
| `RED_CRIMSON` | `#c8352b` | Hover state, woven highlight |
| `RED_EMBER` | `#e2604a` | Damage flash, error text |

### Gold Essence — Chapter 3

Brass, sunlight, the turning spindle. Every border, heading and sacred object.

| Token | Hex | Use |
| --- | --- | --- |
| `GOLD_DEEP` | `#7a5c1c` | Border shadow |
| `GOLD_BRASS` | `#b08a2e` | **Default border**, field labels |
| `GOLD_SACRED` | `#edd172` | Headings, focus border, Gold essence |
| `GOLD_SUN` | `#f8e9a8` | Brightest highlight, staff glow, moonlight |

### Cream — Chapter 4

Ancestral stone and undyed warp thread. Also all body text.

| Token | Hex | Use |
| --- | --- | --- |
| `CREAM_WARP` | `#f4ead6` | **Body and dialogue text** |
| `CREAM_PAPER` | `#ded2b8` | Secondary text |
| `CREAM_STONE` | `#b4a88e` | Statues, muted text, roof moonlight |

### Earth — the neutral of the restored world

| Token | Hex | Use |
| --- | --- | --- |
| `EARTH_LOAM` | `#2b201a` | Soil, house bodies |
| `EARTH_WOOD` | `#4d382a` | Loom frames, beams |
| `EARTH_BAMBOO` | `#7d6141` | Bamboo posts, staff shaft |
| `EARTH_CLAY` | `#a97f4e` | Pots, vats, skin-adjacent warm tone |

### Restored — post-victory only

The only place greens and sky blues are permitted. Holding them back for the ending is what makes the Color Burst land.

| Token | Hex | Use |
| --- | --- | --- |
| `LIVING_MOSS` | `#3d5230` | Restored foliage shadow |
| `LIVING_LEAF` | `#6b8a45` | Restored foliage |
| `SKY_DUSK` | `#1d2c40` | Dawn sky, upper |
| `SKY_DAWN` | `#c47a3c` | Dawn sky, horizon |

### Dream — the twilight the interface lives in

Cool night behind the world's dye families. Gold only becomes lantern-light when it sits on a cold ground, which is why menus, panels and glow halos come from here rather than from `BLACK_PITCH`.

| Token | Hex | Use |
| --- | --- | --- |
| `DREAM_ABYSS` | `#070912` | Screen clear, fade overlay, deepest UI shadow |
| `DREAM_NIGHT` | `#0e1326` | Panel fill, glass pane |
| `DREAM_INDIGO` | `#161d3a` | Raised / focused pane |
| `DREAM_COBALT` | `#232f5c` | Distant mist, aurora shadow |
| `DREAM_TEAL` | `#17414a` | Cool spirit accent (rationed) |
| `DREAM_VIOLET` | `#33255a` | Horizon of the dream-sky |
| `DREAM_AURORA` | `#63d6c6` | Focus ring, spirit light — never a large fill |
| `DREAM_MIST` | `#93a6cc` | Cool secondary copy |
| `DREAM_LANTERN` | `#f7e0a4` | Glow halo, title bloom |

### Forbidden

No purple fills. No cyan or neon except the rationed `DREAM_AURORA` highlight. No pure `#ffffff` or pure `#000000` — use `GOLD_SUN` and `DREAM_ABYSS`. Soft lantern glow (via `StyleBoxFlat.shadow_size` and wide text shadows) is allowed on UI; world art still uses value contrast, not bloom.

---

## 3. Typography

Two families, both already in `assets/fonts/`, both free for commercial use (OFL).

| Role | Font | Sizes | Notes |
| --- | --- | --- | --- |
| Titles & headings | **Cinzel** (Bold / Regular) | 54 title, 40 screen heading, 20–24 sub | Roman capitals with a carved feel — reads as inscription, which suits ancestor statues and sacred objects. Always tracked slightly wide. |
| Body, dialogue, UI | **Crimson Pro** (Regular / Italic) | 20 dialogue, 16 UI, 13–14 label | An old-style serif that stays readable small. Italic is reserved for narration, so the player can tell the narrator from a speaker at a glance. |

Rules:

- **Every piece of text over art gets an outline.** `DREAM_ABYSS`, size 4–8. Non-negotiable: the backdrops are busy and unoutlined text disappears into the weave. Headings may add a warm `DREAM_LANTERN` glow via `font_shadow`.
- Field labels are `GOLD_BRASS`, upper case, letter-spaced.
- Headings are `GOLD_SACRED`. Body is `CREAM_WARP`. Muted/secondary is `CREAM_STONE`.
- Never centre a paragraph of more than two lines; dialogue is left-aligned.

---

## 4. Iconography

| Rule | Value |
| --- | --- |
| Base grid | **32 × 32** for UI icons, **16 × 16** for HUD pips (hearts, essence chips) |
| Stroke width | **2 px** at 32 × 32, **1 px** at 16 × 16 — uniform, no tapering |
| Shading | **Flat, three values max**: shadow, body, highlight. No dithering on icons |
| Dithering | Permitted on *environment* art only, and only as a 50 % checker to blend two adjacent palette values |
| Outline | 1 px `BLACK_PITCH` on all sides of every icon, so icons read on any panel |
| Light source | Upper-left, consistently, across every asset in the game |
| Scaling | Integer multiples only (×2, ×3). Never scale pixel art by a fraction |
| Silhouette test | Fill the icon solid black; if you cannot name it, redraw it |

Character and prop sprites use an **origin at the base** (the feet), not the centre, because the world is Y-sorted by that point.

---

## 5. Motif library

Five recurring T'nalak-derived geometric patterns. Reuse these rather than inventing new ornament — repetition is what makes the world feel woven by one culture.

1. **Kleng (lightning zigzag)** — a hard 45° zigzag, 4 px amplitude at base scale, alternating `GOLD_BRASS` and `RED_SACRED` on `BLACK_SOOT`. The workhorse: panel borders, button edges, the band in the Gateway's clouds, floor accents.
2. **Diamond lozenge chain** — hollow diamonds joined at their points, each with a single centre pixel. Used for dividers, progress meters, and the loading spinner's track.
3. **Frog (bangala)** — a squat, splayed four-legged figure, near-symmetrical, in `RED_SACRED`. A fertility motif; use sparingly as a corner accent and on the Chapter 1 dye vat.
4. **Bird (sawo)** — a long-necked bird in profile with a stepped tail, in `GOLD_BRASS`. Used on the login backdrop and ancestor statues.
5. **Human figure (tofi)** — a stick-limbed standing figure with a triangular skirt, arms raised. This is the sacred pattern of Chapter 4, so it appears **only** on the Ablun loom, the Master Pattern item, and the Sacred Loom's cloth. Never as generic decoration.

Border construction: motif band → 1 px `GOLD_DEEP` inner rule → panel fill. Corners get a solid brass boss rather than trying to turn the zigzag through 90°.

---

## 6. Isometric rules

- One floor cell is a **64 × 32 diamond** (2:1 dimetric). All tiles and floor decals must fit that.
- Props are drawn in **three-quarter view** from a fixed camera; there is no rotation, so each prop needs exactly one facing.
- S'lang needs **four** facings (NE, NW, SE, SW). Enemies need one facing plus a flip.
- Prop shadows are a flat 30 %-alpha `BLACK_PITCH` ellipse at the base, never a cast direction-accurate shadow.

---

## 7. Folder layout

```
assets/
  fonts/                    Cinzel, Crimson Pro
  themes/dreamweaver.tres   Godot Theme built from the palette above
  style_guide.md            this file
  assets_manifest.md        every asset, path, variant, status
  ASSET_PROMPTS.md          one ready-to-paste generation prompt per asset
  images/
    ui/                     buttons, panels, inputs, hud, icons, cursor, transitions
    characters/             S'lang, NPCs, villagers
    enemies/                minions, vines, the Shadow Weaver
    props/                  everything placed in a room
    environments/           per-zone tilesets and backdrops
    effects/                particle and overlay textures
    story/                  prologue panels
  audio/
    music/
    sfx/
```

This differs from a plain `assets/ui`, `assets/characters` layout in one way: images are nested under `assets/images/`, so `fonts/`, `themes/` and `audio/` sit alongside rather than being mixed in with art. Every path in the codebase already follows it.

---

## 8. Working with placeholders

`scripts/world/placeholder_prop.gd` draws a **labelled block** whenever the texture it wants is missing, using the palette above. That is why the project runs and reads correctly with almost no art: each placeholder names the asset it stands in for, and already points at the path where the final PNG belongs. Drop a file there and it is picked up with no code change and no scene edit.

Consequence worth knowing: **adding a blank placeholder PNG at a real asset path is a downgrade**, because it replaces a self-describing labelled block with an anonymous rectangle. Size templates therefore generate into `assets/images/_templates/`, mirroring the real tree, and are meant to be handed to an artist — not dropped into the game. See `assets_manifest.md`.
