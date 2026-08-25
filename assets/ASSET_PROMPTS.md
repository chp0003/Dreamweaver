# Dreamweaver — AI Generation Prompts

One ready-to-paste prompt per asset. Paths and sizes are in [`assets_manifest.md`](assets_manifest.md); the rules behind these prompts are in [`style_guide.md`](style_guide.md).

## How to use this

**Prepend the style lock to every prompt.** It is the whole reason the assets will look like one game:

> Hand-crafted 16-bit pixel art, visible square pixels, flat shading with at most three values per colour, 1px black outline. T'boli T'nalak textile world of Lake Sebu, Mindanao. Palette restricted to: charcoal black #0a0807, crimson #9e2823, brass gold #b08a2e, bright gold #edd172, cream #f4ead6, earth brown #4d382a. Geometric zigzag (kleng) lightning motifs and diamond lozenges. Light source upper-left. No purple, no cyan, no neon, no glow bloom, no photorealism, no anime cel shading, no gradients, no letters, no watermark, no UI chrome.

Then three rules that matter more than the prompt text:

1. **Always generate in full colour.** Never ask for a grey version. `shaders/color_restoration.gdshader` desaturates at runtime; grey art can never be restored and would stay dead after the Color Burst.
2. **Add `isometric three-quarter view, 2:1 dimetric projection` to every world asset.** Without it you get front-on sprites that cannot sit on the floor grid.
3. **Add `transparent background, origin at the base of the object` to every sprite.** The world is Y-sorted by an object's feet.

---

## 1. UI kit

### Buttons

Generate one 320×50 sheet per state, or one 320×200 sheet with all four stacked.

| Asset | Prompt |
| --- | --- |
| `btn_primary_default` | Horizontal pixel-art game button. Deep crimson #9e2823 woven-cloth fill, 2px brass #b08a2e border, a single row of small kleng zigzags along the top and bottom inside edges, solid brass corner bosses. Empty centre for a text label. |
| `btn_primary_hover` | Same button, fill lifted to brighter crimson #c8352b, border to bright gold #edd172, zigzags slightly brighter. Reads as illuminated, not glowing. |
| `btn_primary_pressed` | Same button, fill darkened to #59140f, border to #7a5c1c, whole face shifted down 1px and the top inner edge darkened, as if pushed in. |
| `btn_primary_disabled` | Same button drained to warm greys #484543 fill and #6b6763 border, zigzags barely visible. Flat and lifeless. |
| `btn_secondary_default` | Slimmer 240×40 pixel-art button. No fill — transparent centre with only a 1px brass #b08a2e underline along the bottom and small brass ticks at each end. A quiet link-style control. |
| `btn_secondary_hover` | Same, underline brightened to #edd172 and thickened to 2px, with a faint #181312 panel appearing behind the centre. |
| `btn_secondary_pressed` | Same, underline dimmed to #7a5c1c, contents shifted down 1px. |
| `btn_secondary_disabled` | Same, underline in flat grey #6b6763, no ticks. |

### Panels

| Asset | Prompt |
| --- | --- |
| `panel_dialogue` | Wide pixel-art dialogue frame, 880×200. Near-black #181312 interior. A woven T'nalak border 12px thick on all sides: alternating crimson and brass kleng zigzags on black. Solid brass corner bosses. Large empty interior for text. Bottom-right corner has a small brass diamond marking where a continue prompt sits. |
| `panel_minigame` | Tall pixel-art panel, 720×520, for a mini-game overlay. Near-black interior, 14px woven T'nalak border with diamond-lozenge chain instead of zigzag, brass corner bosses. A narrower inner header band across the top for a title. |
| `panel_quiz` | Pixel-art panel, 720×440, in the ancestral style: cream-grey #b4a88e carved stone frame instead of woven cloth, with the tofi human-figure motif repeated along the top edge in brass. Dark interior. Solemn. |
| `panel_inventory` | Pixel-art panel, 420×300, styled as a folded T'nalak cloth: visible weave texture in the border, a subtle fold crease down the left side, brass pin at the top corners. Dark interior with a faint 4×3 grid of empty slot outlines. |
| `panel_pause` | Pixel-art panel, 480×420. Same woven border as the dialogue frame but doubled at the top into a wider header. Very dark, near-opaque interior. |

### Inputs

| Asset | Prompt |
| --- | --- |
| `input_field` | Pixel-art text input field, 320×40. Sunken near-black #0a0807 well, 1px brass #b08a2e border, tiny brass corner ticks, a 1px darker inner shadow along the top and left to read as recessed. |
| `input_field_focus` | Same field with the border brightened to #edd172 and a 1px bright gold caret line at the left inner edge. |
| `checkbox_off` | 32×32 pixel-art checkbox. Empty sunken black square with a 2px brass border and small corner ticks. |
| `checkbox_on` | Same 32×32 checkbox filled with bright gold #edd172 and a chunky 2px charcoal check mark drawn as a stepped pixel diagonal, not a smooth tick. |
| `dropdown` | Pixel-art dropdown control, 240×40. Dark #181312 fill, brass border, and a small solid brass downward triangle in a divided compartment on the right. |
| `slider_track` | Pixel-art slider track, 240×12. Sunken black channel with a 1px brass rim and a repeating diamond-lozenge chain running along the inside. |
| `slider_grip` | 24×24 pixel-art slider handle shaped as a tiny brass weaving shuttle seen side-on, with a 1px black outline. |

### HUD

| Asset | Prompt |
| --- | --- |
| `heart_full` | 16×16 pixel-art life icon. Not a Western heart: a small crimson #9e2823 diamond lozenge with a single bright gold centre pixel and a 1px black outline. Reads at 16px. |
| `heart_empty` | Same 16×16 diamond lozenge, hollow — grey #484543 outline only, empty dark centre. |
| `objective_box` | Pixel-art HUD plate, 360×72. A torn strip of dark woven cloth with frayed left and right edges, a single brass kleng zigzag along the bottom, mostly empty for two lines of text. Semi-transparent dark fill. |
| `essence_black` | 16×16 pixel-art icon: a tiny clay dye pot filled with glossy black dye, one bright highlight pixel on the rim. |
| `essence_red` | 16×16 pixel-art icon: a tiny clay dye pot filled with deep crimson dye, one bright highlight pixel on the rim. |
| `essence_gold` | 16×16 pixel-art icon: a tiny clay dye pot filled with molten brass gold, two bright highlight pixels. |
| `master_pattern` | 16×16 pixel-art icon: a folded square of cream T'nalak cloth showing one tiny tofi human figure in crimson. The most precious item in the game. |
| `weaving_meter` | Pixel-art progress bar, 240×14. Empty state is a row of bare warp threads in dark brown; the fill is finished T'nalak cloth in crimson-black-gold. Brass end caps. |
| `minimap_frame` | Pixel-art square frame, 160×160, woven T'nalak border 10px thick, fully transparent centre. |

### Icons — all 32×32, 2px stroke, flat, 1px black outline

| Asset | Prompt |
| --- | --- |
| `icon_settings` | A brass weaving-loom heddle seen face-on, reading as a gear: a ring with six square teeth and a square hub. |
| `icon_save` | A small spool of thread with a thread end trailing off to the right, in brass and cream. |
| `icon_volume` | A brass bell in profile with two short curved sound lines to its right. |
| `icon_exit` | A traditional doorway with a raised threshold and a short ladder, with an arrow leaving through it. |
| `icon_back` | A stepped pixel arrow pointing left, drawn as a chunky chevron in brass, with a short tail. |
| `icon_confirm` | A stepped diagonal check mark in bright gold, thick and blocky, no smoothing. |
| `icon_quest` | A bright gold diamond lozenge standing on its point with three short radiating lines above it, like a marker pin. |
| `icon_lore` | An open folded cloth or codex page in cream with two faint lines of crimson pattern on it. |

### Cursor, transitions, title

| Asset | Prompt |
| --- | --- |
| `cursor_default` | 32×32 pixel-art cursor: a small brass weaving needle pointing up-left, threaded with one bright gold thread that curls behind it. Sharp 1px tip at the exact top-left pixel. Transparent background. |
| `cursor_point` | Same brass needle, tilted upright, with the gold thread lifted and a small bright gold spark at the tip — the interactive state. |
| `fade_overlay` | 64×64 seamless tiling pixel texture of pure near-black woven cloth, extremely subtle weave visible, no pattern. For a fade-to-black that still reads as fabric. |
| `spinner_spindle` | 64×64 pixel-art loading spinner: a brass drop spindle seen from above with four arms and a diamond-lozenge ring around it, drawn so it reads correctly when rotated. |
| `title_lockup` | 640×220 pixel-art title treatment. The word DREAMWEAVER in tall carved Roman capitals in brass and bright gold, resting on a horizontal band of crimson-and-gold kleng zigzag, with a small T'nalak diamond emblem centred above it. Transparent background. |
| `gateway_backdrop` | Full-bleed 1280×720 pixel-art title-screen background. Silhouetted T'boli mountain ridges at night, layered so distant ridges are hazier. Three stilted steep-roofed Guno Bong longhouses on the left slope, one with a single lit doorway. A low waning gold moon at the upper right, faint stars, and a band of very subtle kleng zigzag worked into the cloud layer. Very dark, heavily silhouetted, empty upper-centre so a title can sit there. No people. |

### Motif tiles

| Asset | Prompt |
| --- | --- |
| `motif_kleng` | 64×32 seamless horizontally-tiling pixel-art border tile. A hard 45-degree zigzag lightning band, alternating crimson and brass gold on near-black, 4px amplitude. Must tile with no seam. |
| `motif_diamond` | 64×32 seamless horizontally-tiling pixel-art border tile. A chain of hollow diamond lozenges joined at their points, each with one bright centre pixel, brass on near-black. |
| `motif_frog` | 32×32 pixel-art T'boli bangala frog motif: a squat splayed four-legged figure, near-symmetrical, solid crimson with a 1px black outline, on transparent background. |
| `motif_bird` | 32×32 pixel-art T'boli sawo bird motif: a long-necked bird in profile with a stepped rectangular tail, solid brass gold, 1px black outline, transparent background. |
| `motif_tofi` | 32×32 pixel-art T'boli tofi human-figure motif: a stick-limbed standing figure with a triangular skirt and both arms raised, cream with a 1px black outline, transparent background. The sacred pattern — use sparingly. |

---

## 2. Characters

**S'lang** — the four facings must be the same character at the same scale, readable at 32px.

| Asset | Prompt |
| --- | --- |
| `slang` / `slang_idle_se` | Isometric three-quarter-view pixel-art sprite, 2:1 dimetric, facing down-right. A young T'boli weaver girl, Southeast Asian features, long black hair tied back with a red cord, crimson and black T'nalak wrap skirt, cream sleeveless top, brass anklets and beaded necklace, barefoot. She holds a brass-tipped wooden weaving beater like a short staff at her side. Small readable silhouette, strong outline. Transparent background, origin at her feet. |
| `slang_idle_sw` | Same character and scale, facing down-left. Mirror the pose but keep the staff in her right hand and the beadwork on the same side of her body. |
| `slang_idle_ne` | Same character, facing up-right, seen from behind three-quarters: hair and the back of the wrap skirt dominate, face barely visible, staff visible over the shoulder. |
| `slang_idle_nw` | Same character, facing up-left, seen from behind three-quarters. |
| `slang_walk_se` | 6-frame horizontal walk-cycle strip, 192×56, of the same character facing down-right. Contact, down, pass, contact, down, pass. Skirt and hair swing one frame behind the legs. Consistent baseline across all frames. |
| `slang_walk_sw` / `_ne` / `_nw` | Same 6-frame walk strip for each of the remaining three facings. |
| `slang_attack` | 4-frame horizontal strip, 256×64, of the same character swinging the brass weaving beater in a downward arc to the down-right. Frame 1 windup overhead, frame 2 mid-swing with a bright gold motion arc, frame 3 full extension, frame 4 recovery. The gold arc is the only bright element. |
| `slang_staff_pose` | 48×64 hero pose of the same character holding the Lewet Staff raised in both hands overhead, bright gold light running down the staff onto her hands. For the tutorial pickup moment. |

**NPCs**

| Asset | Prompt |
| --- | --- |
| `spirit_of_the_fiber` | Isometric pixel-art NPC, seated. An ancestral spirit woven entirely from raw abaca fibre: a hollow body of pale dry cream strands, no face, a few loose threads drifting upward. Slumped against a corner, motionless, exhausted. Sorrowful and gentle, never monstrous. Transparent background. |
| `spirit_of_the_fiber_restored` | The same seated abaca spirit, now upright and full. Its fibre body is dense and bright cream with crimson and gold threads woven through it, two soft gold points where eyes would be, threads lifting as if in a breeze. The same silhouette, restored. |
| `master_weaver_ghost` | Isometric pixel-art NPC. The semi-transparent ghost of an elder T'boli master weaver: deeply lined face, ceremonial beaded headdress and brass hair combs, full T'nalak malong in crimson and gold. Her lower body dissolves into floating gold threads instead of legs. Dignified, patient, faintly luminous cream-gold. 60% opacity. Transparent background. |
| `villager_1` | Isometric pixel-art NPC, 32×56. An elder T'boli woman in a crimson malong with brass hair combs and heavy beaded necklaces, standing, hands folded. Warm and alive. |
| `villager_2` | Isometric pixel-art NPC, 32×56. A young T'boli man carrying a bundle of pale abaca stalks over one shoulder, brown wrap trousers, bare chest, brass armband. Mid-stride. |
| `villager_3` | Isometric pixel-art NPC, 32×48. A T'boli child holding a wooden weaving shuttle in both hands, simple cream tunic, looking up. |
| `villager_4` | Isometric pixel-art NPC, 32×56. A T'boli woman mid-stride carrying a folded finished T'nalak cloth across both forearms, gold and crimson dress. Purposeful. |

---

## 3. Enemies

| Asset | Prompt |
| --- | --- |
| `shadow_minion` | Isometric pixel-art enemy sprite, 32×40. A small hunched figure made of unravelled black thread and smoke, tangled loose ends trailing behind it, two dim pale grey eyes, no mouth. Its lower body dissolves into a dark pool. Charcoal black with cold grey highlights only — no colour anywhere. Transparent background. |
| `shadow_minion_attack` | 5-frame strip, 160×48, of the same minion lunging: crouch, wind back with thread-arms drawn in, whip both thread-arms forward, extended, recover. The thread ends blur into streaks at full extension. |
| `shadow_minion_death` | 5-frame strip, 160×48, of the same minion coming apart: struck and recoiling, threads loosening, body unravelling upward into separate strands, strands scattering, an empty dark stain on the floor. |
| `shadow_vine` | Isometric pixel-art barrier prop, 64×96. Thick vines of black unravelled thread and thorned shadow crossing a doorway, knotted together badly, frayed ends twitching outward. Charcoal black with cold grey highlights. Transparent background. |
| `shadow_weaver_boss` | Isometric pixel-art boss sprite, 160×200, imposing and detailed. A towering entity of black smoke and unravelled thread shaped like a hunched weaver bent over a loom. Six thread-arms of frayed black cord reach outward; a hollow mask-like face of woven shadow with no eyes; the body dissolves into a wide spreading dark pool. Charcoal black and cold bleached grey, with exactly one crimson thread still caught in its mass — the only colour on it. Transparent background. |
| `shadow_weaver_windup` | The same boss at 160×200, telegraphing a Bleach Attack: all six thread-arms drawn back and up, the mask tilted, the whole mass pulled taut and stretched thin, and a pale bleached-white #c9c2b8 charge gathering at the centre of its chest. Clearly readable as "about to strike" at a glance. |
| `shadow_weaver_stunned` | The same boss at 160×200, staggered: mass slumped and sagging sideways, thread-arms hanging loose and tangled, the mask cracked and hanging forward, the crimson thread pulled tight. Vulnerable. |
| `shadow_weaver_dissolve` | 4-frame strip, 640×200, of the same boss being undone: mask splitting, thread-arms unravelling into loose strands, the whole mass coming apart into individual black threads, and finally a scatter of loose thread on the floor with the single crimson thread lying on top, intact. |

---

## 4. Props

Add `isometric three-quarter view, 2:1 dimetric, transparent background, origin at the base` to each.

| Asset | Prompt |
| --- | --- |
| `lewet_staff` | Pixel-art item sprite, 20×96. A T'boli weaving beater as a slender staff: dark polished hardwood shaft, hammered brass head carved with kleng zigzags, a wrapped cord grip, one bright gold thread trailing from the tip. Lit as though it is the only bright object in a dark room. |
| `guno_bong_1` | A traditional T'boli Guno Bong longhouse on stilts. Steep thatched roof with deep overhanging eaves, dark hardwood walls, a short notched ladder to a raised doorway, woven mat panels. Charcoal and dark-wood palette. Weathered but sound. |
| `guno_bong_2` | The same longhouse type, with crimson-dyed cloth panels hung under the eaves and red earth staining the stilts. |
| `guno_bong_3` | The same longhouse type, with brass ornaments and small brass bells hung along the eaves catching light. |
| `guno_bong_4` | The same longhouse type, older and more ceremonial: pale weathered cream-grey timber, carved ancestor figures on the corner posts, moss on the roof. |
| `guno_bong_5` | The same longhouse type but markedly larger and grander, 150×190 — the great central house. Double-height steep roof, a wide ceremonial platform and stair at the front, carved posts, bright gold cloth hung in the doorway. |
| `backstrap_loom` | A small traditional T'boli backstrap loom resting on the floor: warp threads stretched from a wooden bar to a body strap, an unfinished strip of crimson-and-black T'nalak on it, a wooden shuttle laid across the threads. |
| `loom_small` | A stripped backstrap loom leaning against a wall, no cloth on it, warp threads slack and dusty, shuttle missing. Abandoned mid-work. |
| `drying_rack` | A tall bamboo drying rack hung with long pale abaca fibres reaching almost to the floor, bamboo crossbars lashed with cord. |
| `sacred_vat` | A wide ceremonial dye vat of dark fired clay on a low stone ring, filled to the brim with glossy black dye, a worn wooden stirring paddle resting across the rim, kleng zigzags and a bangala frog motif carved around the belly. |
| `abaca_plant` | A living abaca plant: broad banana-like leaves, thick fibrous stalk, growing from dark earth. Deep green, one of very few green things in the game. |
| `abaca_strand` | Small collectible, 24×24. A short loose bundle of pale cream abaca fibre, slightly curled, tied once at the middle. Must read clearly at 24 pixels. |
| `mortar_pestle` | A heavy carved stone mortar with a thick wooden pestle standing in it, crushed crimson root pulp staining the inside of the bowl and splashed on the rim. |
| `hulo_root` | Small collectible, 24×24. A knobbly red-brown dye root with fine hair roots and a cut face showing deep crimson flesh. Must read clearly at 24 pixels. |
| `red_flowers` | A low cluster of vivid crimson highland flowers on dark stems with small dark leaves. The first thing in the world to get its colour back, so it must be the most saturated red in the game. |
| `wall_torch` | An ancient brass wall sconce mounted on dark wood, shaped with kleng zigzags, holding an unlit resin torch. Provide it **unlit** — cold, dark, dead. |
| `wall_torch_lit` | The same brass sconce with the resin torch burning: a small bright gold flame, warm light spilling on the brass and the wood behind it. Same size and mount position as the unlit version so the two can be swapped. |
| `brass_mirror` | A round polished brass mirror on a pivoting carved wooden stand, tarnished rim engraved with zigzags, the pivot clearly visible so it reads as rotatable. The mirror face catches one bright highlight. |
| `golden_spindle` | A large ceremonial spindle of hammered brass and dark hardwood standing on a carved stone dais, wound thickly with radiant sun-gold thread, kleng zigzags around the base. Warm and holy — the goal of a chapter. |
| `ablun_loom` | A massive ceremonial Ablun floor loom of dark hardwood, 128×96, strung with tall pale cream warp threads, carved ancestor figures on the end posts, a heavy brass beater resting across it. |
| `ancestor_statue_1` | A weathered cream-grey stone statue of a T'boli ancestor in ceremonial dress, holding a wooden weaving shuttle across the chest. Carved kleng patterns on the base, moss in the crevices. Solemn, eyes closed. |
| `ancestor_statue_2` | The same style of stone ancestor statue, holding a bundle of abaca fibre in both arms. Distinct face and headdress from statue 1. |
| `ancestor_statue_3` | The same style of stone ancestor statue, holding a small brass bell raised in one hand. |
| `ancestor_statue_4` | The same style of stone ancestor statue with both hands open and empty, palms up, offering nothing. The unsettling one. |
| `sacred_loom` | Monumental pixel-art centrepiece, 192×160. An enormous ancient backstrap loom of dark hardwood and brass, strung with a vast half-finished T'nalak cloth whose woven pattern is a map of the world itself. The left half of the cloth is rich crimson-black-gold and complete; the right half is bleached grey and visibly unravelling, loose threads hanging. |

---

## 5. Environments

**Tilesets** — each an 8×8 grid of 32×32 cells on a 256×256 sheet, containing 4 floor variants, 4 floor-edge pieces, 4 wall runs, 2 wall corners, and small props and debris. Add: `isometric tileset sheet, 2:1 dimetric, 64x32 diamond floor tiles, cells aligned to a strict 32x32 grid, seamless where tiles meet`.

| Asset | Prompt |
| --- | --- |
| `hub/tileset_ridge` | Highland mountain-ridge exterior. Packed red-brown earth paths, tufted grass, loose stone, low terrace retaining walls of stacked rock, bamboo fence sections, a carved wooden path marker. |
| `house_black/tileset` | Interior of a T'boli weaving house. Hard-packed dark earth floor, dark charcoal hardwood plank walls, woven mat wall panels, bundles of raw abaca, low wooden benches, clay dye jars. Cold and still. |
| `house_red/tileset` | Cramped prison-like storage interior. Deep red earth walls, narrow board floor, stacked woven storage baskets, crimson dye jars, hanging root bundles, one barred window section. |
| `house_gold/tileset` | Tall ceremonial hall interior. Polished dark wood floor with inlaid brass diamond lozenges, dark timber walls with brass sconce mounts, a raised stone dais edge, hanging brass ornaments. |
| `house_ancestors/tileset` | Grand ancestral hall. Pale cream-grey carved stone floor with tofi human-figure patterns inlaid, weathered stone block walls, carved column bases, stone offering bowls. Cathedral-like. |
| `final_chapter/tileset` | Vast ceremonial hall interior, damaged. Dark polished floor cracked and stained with spreading pools of black shadow, cracked support pillars, torn hanging cloth, scattered loose thread. Epic scale, final-battle arena. |

**Prologue backdrops** — 1280×720, no isometric constraint, these are painted panels.

| Asset | Prompt |
| --- | --- |
| `prologue/golden_era` | Full-bleed pixel-art panel. A T'boli highland village at the height of its colour, at golden sunset. Steep-roofed stilted houses, weavers at backstrap looms on raised platforms, a river catching gold light, black mountain foundations behind, red earth terraces. The land itself looks woven — hills striped with T'nalak patterns. Abundant, ancestral, whole. |
| `prologue/great_bleaching` | The same village and camera angle, mid-catastrophe. A wall of colourless grey sweeps in from the right, and everything it has touched is drained to warm grey while the left third is still fully coloured. A hard, visible boundary between colour and grey. Villagers turning to look. Terrifying but silent — no fire, no monsters, no debris. |
| `prologue/slang_room` | Interior of a small T'boli house at night, fully drained to warm greys. A sleeping mat on the floor, a backstrap loom with unfinished cloth, woven wall panels — all colourless. On the floor by the wall lies a single brass-headed weaving beater that is still fully, warmly gold: the only colour in the frame. |

---

## 6. Effects

| Asset | Prompt |
| --- | --- |
| `shadow_sweep` | 512×256 pixel-art overlay strip, transparent on the left and opaque near-black on the right, with a hard ragged vertical boundary made of unravelling thread ends and drifting loose strands. Tiles vertically. For the Great Bleaching sweeping across the screen. |
| `chime_shockwave` | 256×256 pixel-art expanding ring on a transparent background. A bright gold circular ring drawn as a stepped pixel circle, brightest at the ring itself and fading inward and outward, with small kleng zigzags worked into the ring's edge. Centred. |
| `rhythm_burst` | 128×128 pixel-art hit burst on a transparent background. Eight short bright-gold radiating spikes around a small bright centre, plus four crimson diamond lozenge shards thrown outward. Sharp and instant. |
| `bleach_projectile` | 64×64 pixel-art projectile on a transparent background. A tight clot of bleached-white and cold-grey thread, trailing three frayed strands behind it. Cold and colourless — it is what drains colour. |
| `bleach_impact` | 128×128 pixel-art impact splash on a transparent background. A ragged star of bleached-white and cold grey with grey thread ends whipping outward, and a pale grey stain spreading beneath it. |
| `color_burst` | 256×256 pixel-art particle sheet on a transparent background. A grid of small individually-readable fragments of woven thread and diamond-lozenge shards in crimson, brass gold, bright gold, cream and deep black, at three sizes. Sacred palette only, no white, no glow bloom. |
| `gold_streak` | 512×128 pixel-art light streak on a transparent background, tiling horizontally. Long soft bands of sun-gold light raking diagonally, brightest at the centre, fading at both ends. For the Chapter 3 sky. |
| `torch_glow` | 128×128 pixel-art radial light falloff on a transparent background. Warm gold at the centre fading to transparent at the edge, drawn as concentric stepped pixel rings rather than a smooth gradient. |

---

## 7. Audio

Audio is described rather than generated. The full list — twelve music cues with instrumentation and tempo, and twelve SFX — is in [`assets_manifest.md` §8](assets_manifest.md). The game is not silent without them: `scripts/systems/audio_director.gd` synthesises the wind bed, brass bell and all stingers at runtime.

Two constraints worth repeating to a composer:

- **`great_bleaching`** must end with roughly three seconds of true silence. The silence is the dramatic beat, not the sound before it.
- **`boss_shadow_weaver`** must have an unambiguous 4-beat pulse at a steady 128 BPM. Chapter 5's Weave Mode is a rhythm game and the player has to be able to feel the beat through the combat.
