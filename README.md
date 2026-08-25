# Dreamweaver: The Legend of Fun Kdungon

A single-player, desktop 2D isometric narrative RPG built in **Godot 4.x / GDScript**, inspired by T'boli culture and T'nalak weaving. S'lang, a young weaver chosen by the goddess Fun Kdungon, restores the world's sacred colours after the Shadow of Forgetfulness stripped them away.

The signature mechanic is **Grayscale-to-Color**: the world begins fully desaturated, each restored House blooms a pool of real colour around it, and defeating the Shadow Weaver turns the whole world back on for good.

---

## Scene flow

```
Login.tscn ──┬─ Register.tscn ─┐
             └─────────────────┴─→ MainMenu.tscn        "The Gateway"
                                        │
                          ┌─────────────┴──────────────┐
                    [NEW GAME]                   [LOAD GAME]        [LORE CODEX] [EXIT]
                          │                            │
                  StoryIntro.tscn                      │            LoreCodex.tscn
                  (5-panel prologue)                   │
                          │                            │
                          └──────→ MainGame.tscn ←─────┘
                                   (router: reads the save)
                                        │
                        ┌───────────────┴────────────────┐
                 no Lewet Staff yet                staff in hand
                        │                                │
                  Tutorial.tscn                          │
                "S'lang's Awakening"                     │
                        │                                │
                        └──────────→ HubWorld.tscn ←─────┘
                                  "The Ridge of the Five Houses"
                                        │
        ┌────────────┬────────────┬─────┴──────┬────────────────┐
   Chapter1      Chapter2      Chapter3     Chapter4        Chapter5
 Black Found.  Red Courage   Golden Sun  Dream Ancestors  Sacred Loom
        │            │            │            │                │
        └────────────┴────────────┴────────────┘                │
                  (each returns to the Hub)                     │
                                                          Ending.tscn
                                                        (rank + credits)

Any chapter, on running out of lives  →  GameOver.tscn  →  retry that chapter
Any chapter, [Esc]                    →  PauseMenu (resume / codex / hub / gateway)
```

`MainGame.tscn` is a one-second routing screen rather than a menu. It is the single place that decides "tutorial or hub", so the prologue and Load Game both point at it and neither needs to know the rule.

---

## Controls

| Input | Action |
| --- | --- |
| **W / A / S / D** | Move S'lang (screen-space, squashed to the 2:1 isometric grid) |
| **E** | Interact — spirits, statues, mirrors, vats, house doors |
| **Space** | Attack — Lewet Staff swing (also the parry in the boss duel) |
| **Q** | Sonic chime — radial shockwave; lights torches, stuns shadows |
| **Esc** | Pause |
| **Mouse** | Menus, dialogue, choices, and the drag-and-drop mini-games |
| **Enter / click** | Advance dialogue |

The attack key is **Spacebar**, not mouse-click. Mini-games rebind W/A/S/D as their own note lanes and QTE prompts while they are open.

### Input Map actions (required)

| Action | Keys | Notes |
| --- | --- | --- |
| `move_left` / `move_right` | A / D | Horizontal |
| `move_up` / `move_down` | W / S | Preferred vertical names |
| `move_forward` / `move_back` | W / S | Legacy aliases (still bound) |
| `interact` | E | |
| `attack` | Space | |
| `ability` | Q | Sonic chime |
| `pause` | Esc | |

The player script reads `move_up`/`move_down` when present, otherwise falls back to `move_forward`/`move_back`.

### Physics layers & collision

| Editor layer | Name | Typical `collision_layer` value | Used by |
| --- | --- | --- | --- |
| 1 | player | `1` | `CharacterBody2D` S'lang — mask `4` (world) |
| 2 | enemies | `2` | Shadow minions |
| 3 | world | `4` | `StaticBody2D` props, room bounds, fences |
| 4 | sensors | `8` | Reserved for future Area2D solids |

Constants live in `scripts/systems/physics_layers.gd`.

**Player** (`scenes/world/Player.tscn`): `CharacterBody2D` + feet `ConvexPolygonShape2D` diamond (not full-sprite) + `move_and_slide()`.

**World solids**: every `PlaceholderProp` with `blocks_movement = true` auto-adds a feet-only `StaticBody2D` on the world layer. Soft labels (mats, grass, doorways, staff…) stay passable — see `PlaceholderProp.is_soft_label()`.

**Recipe to copy** for a custom fence/tree/rock: open `scenes/world/SolidPropExample.tscn` — `StaticBody2D` (`collision_layer = 4`) + `CollisionShape2D` with a small diamond at the visual base.

**Adding collision to a new object going forward**

1. Prefer `spawn_prop(...)` — solid by default.
2. Floor dressing: `spawn_prop(..., { "blocks_movement": false })` or a soft label.
3. Hand-placed nodes: duplicate `SolidPropExample.tscn`'s `WorldBlocker` child, size the diamond to the object's **feet**, keep `collision_layer = 4`.
4. When you move to a real `TileMap` / `TileSet`, paint collision polygons on each solid tile instead of per-prop bodies.

### Walk animation

S'lang uses `AnimatedSprite2D` with:

| Animation | Notes |
| --- | --- |
| `idle_down` / `idle_up` / `idle_left` / `idle_right` | Standing |
| `walk_down` / `walk_up` / `walk_left` / `walk_right` | Looping walk |

**Frame contract (do not break — prevents idle↔walk shrink/jump):**

| Setting | Value |
| --- | --- |
| Frame canvas | **64 × 96 px** for every frame |
| Anchor | Feet at **bottom-centre** of that canvas |
| `AnimatedSprite2D.offset` | `(0, -46)` |
| `AnimatedSprite2D.scale` | `(56/64, 92/96)` — one fixed scale, never per-animation |

Left facing uses the right-facing frames with `flip_h = true`. Movement code in `scripts/world/player.gd` → `_update_animation()`.

Walk frames are built from `slang.png` (same art as idle) so stature never changes. Optional replacement: `assets/images/characters/slang_walk_cycle.png` (4 frames, 256×96, transparent, same footprint as idle) — rejected automatically if it would shrink/grow the character.

---

## Win / lose

**Win** — restore all four Houses (Black, Red, Gold, Master Pattern), then beat the Shadow Weaver's three phases at the Sacred Loom. The Color Burst permanently disables the grayscale shader, the closing cutscene plays, and `Ending.tscn` shows the final rank.

**Lose** — either:
- **Lives.** Three lives, global and persisted. Combat damage that empties S'lang's health spends one and respawns her at the chapter's entrance; the third loss goes to `GameOver.tscn`.
- **Quizzes.** Three wrong answers inside one chapter forces a retake. Chapter 4's ancestor quizzes are the only place this applies.

`GameOver.tscn` restarts **the current chapter**, not the run. Lives refill and quiz mistakes reset; essences, lore and score are kept.

**Ranking** — score comes from collectibles, mini-game rewards, lore entries (+100 each), House completions (+500) and the victory bonus (+1500), minus 50 per wrong quiz answer. Ranks run Thread Gatherer → Apprentice Weaver → Dye Mistress → Keeper of the Loom → Master Dreamweaver. The Lore Codex is reachable from the Gateway, the pause menu and the ending.

---

## The five Houses

| # | House | Quest phase | Mini-game | Reward |
| --- | --- | --- | --- | --- |
| 1 | Black Foundation | Collect 10 Faded Abaca Strands | **Fiber Sorting** (drag brittle vs. viable) | Black Dye Essence |
| 2 | Red Courage | Cut the Shadow Vines, hunt 5 Hulo Roots past minions | **Pigment Mashing** (rhythm) | Red Dye Essence |
| 3 | Golden Sun | Chime the torches alight, then the Brass Mirror beam puzzle | **Pattern Memory** (Simon-says snake pattern) | Gold Essence |
| 4 | Dream Ancestors | Four statue riddles, quizzed on T'boli culture | **Warp Alignment** (thread logic puzzle) | Sacred Master Pattern |
| 5 | The Sacred Loom | Breach → Duel of Rhythms → Finishing Stitch | **Rhythm Track** + **QTE Sequence** | Full colour, globally |

Houses unlock in order. House 5 additionally checks for all three essences *and* the Master Pattern, so it cannot be entered under-equipped even if the door is open.

---

## Project layout

### Autoloads

| Autoload | File | Role |
| --- | --- | --- |
| `AccountManager` | `scripts/account_manager.gd` | Accounts, session, and per-account progress in `user://accounts.json` |
| `GameState` | `scripts/systems/game_state.gd` | Live run: lives, chapter, unlocks, essences, items, lore, score. Writes through on every change |
| `ColorRestoration` | `scripts/systems/color_restoration.gd` | Owns the desaturation shader — global level plus up to 8 local colour zones |
| `Audio` | `scripts/systems/audio_director.gd` | Procedurally synthesises wind, brass bells and stingers (no audio files shipped yet) |
| `SceneFader` | `scripts/scene_fader.gd` | Fade between scenes |
| `GameManager` | `scripts/game_manager.gd` | Unchanged from the earlier prototype |

### Frameworks

| File | Role |
| --- | --- |
| `scripts/chapters/chapter_base.gd` | Spine for every chapter: player, camera, HUD, dialogue, pause, lives, retry. Subclasses implement `_build_world()` and `_run_chapter()` |
| `scripts/minigames/mini_game_base.gd` | Spine for every mini-game: chrome, timer, attempts, pass/fail, reward. Subclasses implement `_build_content()` |
| `scripts/systems/houses.gd` | Static catalogue of the five Houses — names, scenes, essences, hub positions, accent colours |
| `scripts/systems/culture_data.gd` | Quiz bank and lore entries |
| `scripts/world/iso.gd` | Isometric grid maths (64×32 diamond cells) |
| `scripts/world/placeholder_prop.gd` | Draws a labelled block, or the real texture the moment a PNG appears at its `texture_path` |

### Directories

| Path | Contents |
| --- | --- |
| `scenes/` | Flow scenes, the five chapters, menus, ending |
| `scenes/minigames/` | One scene per named mini-game |
| `scenes/ui/`, `scenes/world/` | HUD, dialogue, pause; player and minion |
| `scripts/chapters/` | `chapter_base.gd` + one script per chapter |
| `scripts/minigames/` | `mini_game_base.gd` + seven implementations |
| `scripts/world/` | Player, minions, collectibles, interactables, vines, mirror puzzle, boss |
| `shaders/color_restoration.gdshader` | Screen-space desaturation with up to 8 restored zones |
| `tools/` | Build checks — see below |

---

## Running and testing

1. Open the folder as a Godot **4.x** project (developed against 4.7).
2. Main scene is `res://scenes/Login.tscn`. Press **F5**.
3. Register or log in → the Gateway → **NEW GAME** → prologue → tutorial → hub.

To jump straight into one chapter, open its scene and press **F6**. Chapters read `GameState`, so a chapter run in isolation starts with no staff and no essences; set them in the remote inspector, or run the smoke test first, which seeds a mid-run save on a throwaway `smoketest` account.

### Build checks

Both are headless, take seconds, and exit non-zero on failure:

```
godot --headless --path . res://tools/Validate.tscn   # loads every script, scene, shader, theme
godot --headless --path . res://tools/Smoke.tscn      # actually runs every chapter and mini-game for 90 frames
```

`Validate` proves things *load*. `Smoke` proves they *run*: it signs in, seeds a mid-run save, then mounts each scene and mini-game under the root so `_build_world()` and the opening beats of `_run_chapter()` really execute. Any failure appears as an `ERROR` / `SCRIPT ERROR` line above the summary.

Two more tools need a rendering device, so run them **without** `--headless`:

```
godot --path . res://tools/Shot.tscn        # renders each screen to tools/shots/*.png
godot --path . res://tools/Templates.tscn   # writes asset size templates, see Art assets
```

`Shot` is how to check what a screen actually looks like. It matters here because the grayscale veil is an autoload: whether a screen is bleached is not visible anywhere in that screen's own scene file, and it prints the veil's value alongside each capture. All four are development-only and can be deleted before shipping.

### Save data

`user://accounts.json` — on Windows, usually `%APPDATA%\Godot\app_userdata\Dreamweaver\accounts.json`. Progress is nested per account under `progress`. Delete the file to reset all testers.

---

## Art assets

The design system is now the authority on art, in three files:

| File | Contents |
| --- | --- |
| [`assets/style_guide.md`](assets/style_guide.md) | Palette hex tokens, typography, iconography rules, the five T'nalak motifs, isometric rules |
| [`assets/assets_manifest.md`](assets/assets_manifest.md) | Every asset: path, size, grayscale/restored variant, final-vs-template status, runtime fallback, plus the full audio list |
| [`assets/ASSET_PROMPTS.md`](assets/ASSET_PROMPTS.md) | One ready-to-paste generation prompt per asset — a superset of the list further down this page |

Palette values are mirrored in code at `scripts/systems/palette.gd`, which the procedural art reads at runtime, so the guide and the game cannot drift apart.

`godot --path . res://tools/Templates.tscn` writes a labelled size template for all 115 assets into `assets/images/_templates/`, mirroring the real tree. Templates deliberately do **not** go to the real paths: `scripts/world/placeholder_prop.gd` draws a labelled block whenever the texture it wants is missing, so **the project runs fully with zero art** and an anonymous rectangle at a real path would be a downgrade. Every placeholder names the asset it stands in for and already points at the path where its PNG belongs — drop a file there and it is picked up with no code change.

The per-asset prompts below are the earlier, smaller subset, kept only so existing links do not break. Prefer `ASSET_PROMPTS.md`.

Style lock, prepend to every prompt:

> Hand-crafted 16-bit pixel art, visible square pixels. T'boli T'nalak textile world of Mindanao. Sacred palette only: charcoal black, crimson red, warm gold, cream, earth brown. Geometric zigzag (kleng) lightning motifs and diamond lozenges. No purple, no cyan neon, no glow bloom, no photorealism, no anime cel shading, no letters, no watermark, no UI chrome.

Two notes specific to this build. Almost everything is seen from a **2:1 isometric three-quarter view**, so say so in the prompt or you will get front-on sprites that cannot sit on the floor grid. And because the world starts bleached, **generate everything in full colour** — the shader does the desaturation, and art that is already gray can never be restored.

Every path below is the exact one the code already asks for. Sprites want a **transparent background** and an origin at the **base** of the object, since props are Y-sorted by their feet.

### Characters

**S'lang** — `characters/slang.png` (~32×56)
> Isometric three-quarter-view pixel-art sprite of a young T'boli weaver girl, Southeast Asian features, long black hair, crimson and black T'nalak wrap skirt, brass anklets and beadwork, barefoot. She carries a brass-tipped wooden weaving beater like a staff. Small readable silhouette, strong outline, full colour.

**Spirit of the Fiber** — `characters/spirit_of_the_fiber.png` (Ch. 1)
> Isometric pixel-art NPC. A seated ancestral spirit woven entirely from raw abaca fibre — a hollow body of pale dry strands, no face, a few loose threads drifting upward. Slumped, motionless, exhausted, sitting in a corner. Sorrowful and gentle, not monstrous.

**Master Weaver ghost** — `characters/master_weaver_ghost.png` (Ch. 4)
> Isometric pixel-art NPC. Semi-transparent ghost of an elder T'boli master weaver, deeply lined face, ceremonial beaded headdress and brass combs, full T'nalak malong. Her lower body dissolves into floating gold thread. Dignified, patient, faintly luminous cream-gold.

**Restored villagers** — `characters/villager_1.png` … `villager_4.png` (Ch. 5 closing cutscene)
> Isometric pixel-art NPC sprites, a set of four distinct T'boli villagers: an elder woman with brass combs, a young man carrying abaca bundles, a child with a shuttle, a weaver mid-stride. Everyday highland dress in crimson, gold and earth brown. Alive, mid-motion, warm — these replace gray statues the moment colour returns.

### Enemies

**Shadow Minion** — `enemies/shadow_minion.png` (Ch. 2, Ch. 5)
> Isometric pixel-art enemy sprite. A small hunched figure made of unravelled black thread and smoke, tangled loose ends trailing behind it, two dim pale eyes. Rising out of a dark pool on the floor. Charcoal black with faint cold gray highlights, no bright colour.

**Shadow Vine** — `enemies/shadow_vine.png` (Ch. 2 barrier)
> Isometric pixel-art barrier prop. Thick vines of black unravelled thread and thorned shadow crossing a doorway, woven together like a bad knot, frayed ends twitching. Charcoal black with cold gray highlights.

**Shadow Weaver** — `enemies/shadow_weaver_boss.png` (Ch. 5, large)
> Isometric pixel-art boss sprite, imposing. A towering entity of black smoke and unravelled thread shaped like a hunched weaver at a loom. Many thread-arms of frayed black cord reach outward; a hollow mask-like face of woven shadow; a body that dissolves into a spreading dark pool. Charcoal black and cold bleached gray, with a single crimson thread still caught in it.

### Props

**Lewet Staff** — `props/lewet_staff.png` (~20×96, tutorial)
> Isometric pixel-art item sprite. A T'boli weaving beater as a slender staff: dark polished hardwood shaft, hammered brass head carved with zigzag kleng motifs, a wrapped cord grip, one small gold thread trailing from the tip. The only glowing object in a colourless room.

**Guno Bong exteriors** — `props/guno_bong_1.png` … `guno_bong_5.png` (Hub)
> Isometric three-quarter-view pixel-art building. A traditional T'boli Guno Bong longhouse on stilts: steep thatched roof, dark hardwood walls, a short ladder to a raised doorway, woven mat panels. Number 5 is markedly larger and grander — the great central house.

| Path | Prompt (after the style lock) |
| --- | --- |
| `props/backstrap_loom.png` | A small traditional T'boli backstrap loom on the floor, warp threads stretched to a wooden bar, an unfinished strip of T'nalak on it, a shuttle resting across the threads. *(tutorial room)* |
| `props/loom_small.png` | A stripped backstrap loom leaning against a wall, no cloth on it, warp threads slack and dusty. Abandoned. *(Ch. 1)* |
| `props/drying_rack.png` | A tall wooden drying rack hung with long pale abaca fibres, bamboo crossbars, fibres swaying. *(Ch. 1)* |
| `props/sacred_vat.png` | A wide ceremonial dye vat of dark fired clay on a low stone ring, filled with deep black dye, a wooden stirring paddle across the rim, kleng zigzags around the belly. *(Ch. 1)* |
| `props/abaca_plant.png` | A living abaca plant — broad banana-like leaves, thick fibrous stalk, growing in dark earth. *(Ch. 1 garden)* |
| `props/abaca_strand.png` | Small collectible: a short loose bundle of pale abaca fibre, slightly curled, tied once at the middle. Reads clearly at 24 pixels. *(Ch. 1 pickup)* |
| `props/mortar_pestle.png` | A heavy carved stone mortar with a thick wooden pestle resting in it, crushed crimson root pulp staining the bowl. *(Ch. 2)* |
| `props/hulo_root.png` | Small collectible: a knobbly red-brown dye root with fine hair roots and a cut face showing deep crimson flesh. Reads clearly at 24 pixels. *(Ch. 2 pickup)* |
| `props/red_flowers.png` | A low cluster of vivid crimson highland flowers on dark stems. The first thing in the world to get its colour back. *(Ch. 2 restoration)* |
| `props/wall_torch.png` | An ancient brass wall sconce on dark wood, shaped with kleng zigzags, holding a resin torch. Provide it unlit — the game lights it. *(Ch. 3)* |
| `props/brass_mirror.png` | A round polished brass mirror on a pivoting carved wooden stand, tarnished rim with zigzag engraving, clearly rotatable. *(Ch. 3 puzzle)* |
| `props/golden_spindle.png` | A large ceremonial spindle of hammered brass and dark wood on a carved dais, wound with radiant sun-gold thread, kleng zigzags around its base. Warm and holy. *(Ch. 3 goal)* |
| `props/ablun_loom.png` | A massive ceremonial Ablun floor loom of dark hardwood, strung with tall pale cream warp threads, carved ancestor figures on the end posts. *(Ch. 4)* |
| `props/ancestor_statue_1.png` … `_4.png` | Four distinct weathered gray stone statues of T'boli ancestors in ceremonial dress — one holding a shuttle, one a bundle of fibre, one a brass bell, one with open empty hands. Carved kleng patterns on the bases, moss in the crevices. Solemn. *(Ch. 4)* |
| `props/sacred_loom.png` | Monumental: an enormous ancient backstrap loom of dark hardwood and brass, strung with a vast half-finished T'nalak cloth whose pattern is the world itself. Half rich crimson-black-gold, half bleached and unravelling. *(Ch. 5)* |

### Screens

**Gateway backdrop** — `ui/gateway_backdrop.png` (16:9, optional)
> Full-bleed 16:9 pixel-art title-screen background. Silhouetted T'boli mountain ridges at night, one great steep-roofed Guno Bong on the centre ridge with a single lit doorway, a low gold moon, faint T'nalak zigzags in the cloud shapes. Very dark, heavily silhouetted, empty upper-centre so a title can sit there. No people.

This is the one asset with a procedural fallback: `mountain_silhouette.gd` draws its own ridge and longhouse when the file is absent, which is why the Gateway and the ending already look finished. Drop the PNG in and it takes over.

### Room interiors — reference art

Chapter floors are drawn procedurally by `iso_floor.gd`, so these prompts feed **mood and prop direction**, not a drop-in file. Generate them to pin down each House's look, then pull individual props out of them.

| House | Prompt (after the style lock) |
| --- | --- |
| 1. Black Foundation | Isometric interior of a T'boli highland weaving house. Cold, still, silent. A large sacred dye vat of black earth pigment at the centre, raw abaca on drying racks, a stripped loom against the wall, a doorway to a garden. Dark charcoal wood, hard-packed earth floor on a 2:1 diamond grid. |
| 2. Red Courage | Isometric interior of a cramped prison-like storage room. Narrow corridors between stacked woven baskets and crimson dye jars, a stone mortar on the floor, hulo roots drying on a rack, one barred window. Deep red earth walls, cramped and dim. |
| 3. Golden Sun | Isometric tall ceremonial hall. Brass torch sconces along the walls, large pivoting brass mirrors on wooden stands, a great Golden Spindle on a raised dais wound with sun-gold thread, a high smoke opening in the roof. Warm brass on dark wood. |
| 4. Dream Ancestors | Isometric grand hall of ancestors. Four tall carved gray stone statues facing inward, a massive Ablun loom at the centre strung with pale cream warp, dream patterns carved into the floor. Solemn, cathedral-like, cream stone and pale gold. |
| 5. Sacred Loom | Isometric interior of the great central Guno Bong. A vast ceremonial hall, the enormous Sacred Loom at the far end strung with the unfinished cloth of the world, spreading pools of black shadow on the floor, cracked support pillars. Epic scale, final-battle arena. |

### Color Burst

Chapter 5's burst is 900 `GPUParticles2D` points driven by a gold → crimson → charcoal colour ramp built in code, so it needs no file. To art-direct it instead, generate a sheet and set it as the emitter's `texture`:

> Pixel-art particle sheet on a transparent background. Small bright fragments of woven thread and diamond lozenge shards in crimson, gold, cream and deep black, radiating outward. Several sizes in a grid, each individually readable. Sacred palette only, no white glow bloom.

### Phase 1 assets (already in the repo)

The prologue and auth art from the earlier build is in place: `ui/login_register_bg.png`, `ui/logo_emblem.png`, `ui/auth_panel_frame.png`, and `story/intro_01_sacred_world.png` through `story/intro_05_journey.png`. Their prompts follow the same style lock — replace a file in place, same name, to regenerate.
