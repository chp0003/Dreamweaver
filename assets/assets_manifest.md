# Dreamweaver — Asset Manifest

Every asset the game expects, at a glance. Generation prompts live in [`ASSET_PROMPTS.md`](ASSET_PROMPTS.md); the rules all art must follow live in [`style_guide.md`](style_guide.md).

## How to read this

| Column | Meaning |
| --- | --- |
| **Path** | Relative to `res://assets/images/`. This is the exact path the code loads — put the final PNG here and it is picked up with no code change. |
| **Size** | Canvas size in pixels. A matching labelled template exists at `assets/images/_templates/<path>`. |
| **Variants** | `full` = author in full colour only; the runtime shader handles bleaching. `both` = needs two hand-authored files because the two states differ in more than saturation (a lit torch, a living statue). `n/a` = UI, which is never bleached. |
| **Status** | `FINAL` shipped art · `TEMPLATE` size template only · `PROCEDURAL` drawn in code, art optional |
| **Fallback** | What the player sees today if the file is absent. |

**Current totals: 8 final, 115 templates, 6 procedural systems. Zero missing-resource errors** — every texture load in the codebase is guarded by `ResourceLoader.exists()`, so absent art degrades to a labelled placeholder instead of an error. Verify with `godot --headless --path . res://tools/Validate.tscn`.

---

## 1. Final art (already in the repo)

| Path | Size | Variants | Status |
| --- | --- | --- | --- |
| `ui/login_register_bg.png` | 1920×1080 | n/a | FINAL |
| `ui/logo_emblem.png` | 512×512 | n/a | FINAL |
| `ui/auth_panel_frame.png` | 683×1024 | n/a | FINAL |
| `story/intro_01_sacred_world.png` | 1920×1080 | n/a | FINAL |
| `story/intro_02_darkness.png` | 1920×1080 | n/a | FINAL |
| `story/intro_03_fun_kdungon.png` | 1920×1080 | n/a | FINAL |
| `story/intro_04_slang_chosen.png` | 1920×1080 | n/a | FINAL |
| `story/intro_05_journey.png` | 1920×1080 | n/a | FINAL |

---

## 2. UI kit

### Buttons

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/btn_primary_default.png` | 320×50 | n/a | TEMPLATE | Theme StyleBoxFlat |
| `ui/btn_primary_hover.png` | 320×50 | n/a | TEMPLATE | Theme StyleBoxFlat |
| `ui/btn_primary_pressed.png` | 320×50 | n/a | TEMPLATE | Theme StyleBoxFlat |
| `ui/btn_primary_disabled.png` | 320×50 | n/a | TEMPLATE | Theme StyleBoxFlat |
| `ui/btn_secondary_default.png` | 240×40 | n/a | TEMPLATE | Theme `GhostButton` |
| `ui/btn_secondary_hover.png` | 240×40 | n/a | TEMPLATE | Theme `GhostButton` |
| `ui/btn_secondary_pressed.png` | 240×40 | n/a | TEMPLATE | Theme `GhostButton` |
| `ui/btn_secondary_disabled.png` | 240×40 | n/a | TEMPLATE | Theme `GhostButton` |

All four button states are already implemented as StyleBoxFlat entries in `assets/themes/dreamweaver.tres`, so these PNGs are an upgrade path (swap to StyleBoxTexture), not a blocker.

### Panels

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/panel_dialogue.png` | 880×200 | n/a | TEMPLATE | Theme panel |
| `ui/panel_minigame.png` | 720×520 | n/a | TEMPLATE | Theme panel |
| `ui/panel_quiz.png` | 720×440 | n/a | TEMPLATE | Theme panel |
| `ui/panel_inventory.png` | 420×300 | n/a | TEMPLATE | Theme panel |
| `ui/panel_pause.png` | 480×420 | n/a | TEMPLATE | Theme panel |

### Inputs

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/input_field.png` | 320×40 | n/a | TEMPLATE | Theme LineEdit |
| `ui/input_field_focus.png` | 320×40 | n/a | TEMPLATE | Theme LineEdit |
| `ui/checkbox_off.png` | 32×32 | n/a | TEMPLATE | Theme CheckBox |
| `ui/checkbox_on.png` | 32×32 | n/a | TEMPLATE | Theme CheckBox |
| `ui/dropdown.png` | 240×40 | n/a | TEMPLATE | Theme OptionButton |
| `ui/slider_track.png` | 240×12 | n/a | TEMPLATE | Theme HSlider |
| `ui/slider_grip.png` | 24×24 | n/a | TEMPLATE | Theme HSlider |

### HUD

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/hud/heart_full.png` | 16×16 | n/a | TEMPLATE | Drawn `♥` glyph, `RED_SACRED` |
| `ui/hud/heart_empty.png` | 16×16 | n/a | TEMPLATE | Drawn `♥` glyph, `CURSED_ASH` |
| `ui/hud/objective_box.png` | 360×72 | n/a | TEMPLATE | Theme panel |
| `ui/hud/essence_black.png` | 16×16 | n/a | TEMPLATE | Coloured chip |
| `ui/hud/essence_red.png` | 16×16 | n/a | TEMPLATE | Coloured chip |
| `ui/hud/essence_gold.png` | 16×16 | n/a | TEMPLATE | Coloured chip |
| `ui/hud/master_pattern.png` | 16×16 | n/a | TEMPLATE | Coloured chip |
| `ui/hud/weaving_meter.png` | 240×14 | n/a | TEMPLATE | ProgressBar |
| `ui/hud/minimap_frame.png` | 160×160 | n/a | TEMPLATE | **Not used** — no minimap in the current design |

### Icons

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/icons/icon_settings.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_save.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_volume.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_exit.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_back.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_confirm.png` | 32×32 | n/a | TEMPLATE | Text button |
| `ui/icons/icon_quest.png` | 32×32 | n/a | TEMPLATE | Objective text |
| `ui/icons/icon_lore.png` | 32×32 | n/a | TEMPLATE | Text button |

### Cursor, transitions, title

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `ui/cursor_default.png` | 32×32 | n/a | TEMPLATE | OS cursor |
| `ui/cursor_point.png` | 32×32 | n/a | TEMPLATE | OS cursor |
| `ui/fade_overlay.png` | 64×64 | n/a | TEMPLATE | Flat ColorRect in `SceneFader` |
| `ui/spinner_spindle.png` | 64×64 | n/a | TEMPLATE | No spinner (loads are instant) |
| `ui/title_lockup.png` | 640×220 | n/a | TEMPLATE | Cinzel text + emblem |
| `ui/gateway_backdrop.png` | 1280×720 | n/a | PROCEDURAL | `mountain_silhouette.gd` draws the ridge, moon, stars and village |

### Motif tiles

Reference tiles for building borders and floor decals. Not loaded directly.

| Path | Size | Variants | Status |
| --- | --- | --- | --- |
| `ui/motifs/motif_kleng.png` | 64×32 | n/a | TEMPLATE |
| `ui/motifs/motif_diamond.png` | 64×32 | n/a | TEMPLATE |
| `ui/motifs/motif_frog.png` | 32×32 | n/a | TEMPLATE |
| `ui/motifs/motif_bird.png` | 32×32 | n/a | TEMPLATE |
| `ui/motifs/motif_tofi.png` | 32×32 | n/a | TEMPLATE |

---

## 3. Characters

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `characters/slang.png` | 32×56 | full | TEMPLATE | Labelled block, **loaded today** |
| `characters/slang_idle_ne.png` | 32×56 | full | TEMPLATE | Single-sprite `slang.png` |
| `characters/slang_idle_nw.png` | 32×56 | full | TEMPLATE | Single-sprite `slang.png` |
| `characters/slang_idle_se.png` | 32×56 | full | TEMPLATE | Single-sprite `slang.png` |
| `characters/slang_idle_sw.png` | 32×56 | full | TEMPLATE | Single-sprite `slang.png` |
| `characters/slang_walk_ne.png` | 192×56 (6 frames) | full | TEMPLATE | Squash-and-bob on the single sprite |
| `characters/slang_walk_nw.png` | 192×56 (6 frames) | full | TEMPLATE | Squash-and-bob |
| `characters/slang_walk_se.png` | 192×56 (6 frames) | full | TEMPLATE | Squash-and-bob |
| `characters/slang_walk_sw.png` | 192×56 (6 frames) | full | TEMPLATE | Squash-and-bob |
| `characters/slang_attack.png` | 256×64 (4 frames) | full | TEMPLATE | Drawn Polygon2D swing arc |
| `characters/slang_staff_pose.png` | 48×64 | full | TEMPLATE | Not used |
| `characters/spirit_of_the_fiber.png` | 56×64 | **both** | TEMPLATE | Labelled block |
| `characters/spirit_of_the_fiber_restored.png` | 56×64 | **both** | TEMPLATE | Tint swap on the same block |
| `characters/master_weaver_ghost.png` | 48×72 | full | TEMPLATE | Labelled block |
| `characters/villager_1.png` | 32×56 | **both** | TEMPLATE | Labelled block |
| `characters/villager_2.png` | 32×56 | **both** | TEMPLATE | Labelled block |
| `characters/villager_3.png` | 32×48 | **both** | TEMPLATE | Labelled block |
| `characters/villager_4.png` | 32×56 | **both** | TEMPLATE | Labelled block |

S'lang's four facings and walk cycles are the single biggest visual upgrade available: the player currently reads as one static sprite that squashes slightly while moving.

The villagers need `both` variants because Chapter 5's closing cutscene swaps grey statues for living people — that is a silhouette and pose change, not a saturation change, so the shader cannot do it.

---

## 4. Enemies

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `enemies/shadow_minion.png` | 32×40 | full | TEMPLATE | Labelled block, rises from the floor |
| `enemies/shadow_minion_attack.png` | 160×48 (5 frames) | full | TEMPLATE | Contact damage, no animation |
| `enemies/shadow_minion_death.png` | 160×48 (5 frames) | full | TEMPLATE | Scale-and-fade tween |
| `enemies/shadow_vine.png` | 64×96 | full | TEMPLATE | Labelled block that frays as it takes hits |
| `enemies/shadow_weaver_boss.png` | 160×200 | full | TEMPLATE | Labelled block |
| `enemies/shadow_weaver_windup.png` | 160×200 | full | TEMPLATE | Drawn telegraph ring |
| `enemies/shadow_weaver_stunned.png` | 160×200 | full | TEMPLATE | Tint + tilt |
| `enemies/shadow_weaver_dissolve.png` | 640×200 (4 frames) | full | TEMPLATE | Fade-out tween |

---

## 5. Props

All `full` variants — the shader bleaches them, and a restored House's colour zone brings them back in place.

| Path | Size | Status | Loaded today |
| --- | --- | --- | --- |
| `props/lewet_staff.png` | 20×96 | TEMPLATE | yes (Tutorial) |
| `props/guno_bong_1.png` … `_5.png` | 112×140, `_5` 150×190 | TEMPLATE | yes (Hub) |
| `props/backstrap_loom.png` | 84×58 | TEMPLATE | yes (Tutorial) |
| `props/loom_small.png` | 72×52 | TEMPLATE | yes (Ch. 1) |
| `props/drying_rack.png` | 80×96 | TEMPLATE | yes (Ch. 1) |
| `props/sacred_vat.png` | 72×56 | TEMPLATE | yes (Ch. 1) |
| `props/abaca_plant.png` | 64×80 | TEMPLATE | yes (Ch. 1) |
| `props/abaca_strand.png` | 24×24 | TEMPLATE | yes (Ch. 1 pickup ×10) |
| `props/mortar_pestle.png` | 56×52 | TEMPLATE | yes (Ch. 2) |
| `props/hulo_root.png` | 24×24 | TEMPLATE | yes (Ch. 2 pickup ×5) |
| `props/red_flowers.png` | 48×40 | TEMPLATE | yes (Ch. 2 restoration) |
| `props/wall_torch.png` | 32×64 | TEMPLATE | yes (Ch. 3) |
| `props/brass_mirror.png` | 48×64 | TEMPLATE | yes (Ch. 3 puzzle) |
| `props/golden_spindle.png` | 72×96 | TEMPLATE | yes (Ch. 3 goal) |
| `props/ablun_loom.png` | 128×96 | TEMPLATE | yes (Ch. 4) |
| `props/ancestor_statue_1.png` … `_4.png` | 48×96 | TEMPLATE | yes (Ch. 4) |
| `props/sacred_loom.png` | 192×160 | TEMPLATE | yes (Ch. 5) |

`wall_torch.png` is the one prop that wants **two** files if you want a real lit state — supply `wall_torch.png` unlit and `wall_torch_lit.png`, and the chime phase can swap them instead of tinting.

---

## 6. Environments

Chapter floors are generated by `iso_floor.gd` (64×32 diamonds, per-House palette), so tilesets are an upgrade rather than a requirement.

| Path | Size | Variants | Status | Fallback |
| --- | --- | --- | --- | --- |
| `environments/hub/tileset_ridge.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/house_black/tileset.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/house_red/tileset.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/house_gold/tileset.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/house_ancestors/tileset.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/final_chapter/tileset.png` | 256×256 | full | TEMPLATE | Procedural diamond floor |
| `environments/prologue/golden_era.png` | 1280×720 | full | TEMPLATE | `story/intro_01` covers this beat |
| `environments/prologue/great_bleaching.png` | 1280×720 | full | TEMPLATE | `story/intro_02` covers this beat |
| `environments/prologue/slang_room.png` | 1280×720 | full | TEMPLATE | Tutorial is played, not shown as a panel |

Each tileset sheet should be an 8×8 grid of 32×32 cells containing: 4 floor variants, 4 floor-edge pieces, 4 wall runs, 2 wall corners, and the rest small props and debris for that House.

---

## 7. Effects

| Path | Size | Status | Fallback |
| --- | --- | --- | --- |
| `effects/shadow_sweep.png` | 512×256 | TEMPLATE | `story/intro_02` panel |
| `effects/chime_shockwave.png` | 256×256 | PROCEDURAL | Generated radial GradientTexture2D ring |
| `effects/rhythm_burst.png` | 128×128 | TEMPLATE | Colour flash on the note lane |
| `effects/bleach_projectile.png` | 64×64 | TEMPLATE | Drawn telegraph shape |
| `effects/bleach_impact.png` | 128×128 | TEMPLATE | Screen shake + damage flash |
| `effects/color_burst.png` | 256×256 | PROCEDURAL | 900 GPUParticles2D points on a gold→crimson→charcoal ramp |
| `effects/gold_streak.png` | 512×128 | PROCEDURAL | Drawn sky streaks in Ch. 3 |
| `effects/torch_glow.png` | 128×128 | PROCEDURAL | PointLight2D with a generated radial texture |

---

## 8. Audio

**Nothing here is a file yet.** `scripts/systems/audio_director.gd` synthesises the wind bed, the brass bell and all stingers at runtime through an `AudioStreamGenerator`, so the game is never silent. Replacing it means writing files to these paths and rewriting the bodies of `set_ambience()` and `play_sfx()` — callers do not change.

### Music

| Path | Cue | Instrumentation & mood | Tempo |
| --- | --- | --- | --- |
| `audio/music/menu_ambient.ogg` | Gateway, login | Low rhythmic hum, wind, a distant brass bell every ~9 s. Almost no melody | ~60 BPM, loop |
| `audio/music/golden_era.ogg` | Prologue panel 1 | Hegelung (two-string lute) melody, hand drum, bamboo flute. Warm, pastoral, whole | 84 BPM |
| `audio/music/covenant.ogg` | Prologue, Fun Kdungon | Swelling strings under a solo bamboo flute, brass bell accents, no percussion. Sacred, vast | 66 BPM, rubato |
| `audio/music/great_bleaching.ogg` | Prologue, the bleaching | Harsh rising wind, a single struck gong, then **three seconds of true silence**. The silence is the cue | n/a, one-shot |
| `audio/music/journey_start.ogg` | Tutorial → Hub | Tribal drum pattern (kulintang + agung), rising, hopeful | 100 BPM, loop |
| `audio/music/house_black.ogg` | Chapter 1 | Melancholy sustained pad, sparse plucked lute, very low activity | 58 BPM, loop |
| `audio/music/house_red.ogg` | Chapter 2 | Fast ethnic drums, driving, physical | 132 BPM, loop |
| `audio/music/house_gold.ogg` | Chapter 3 | Ethereal bamboo flute over a shimmering brass drone. Curious, open | 72 BPM, loop |
| `audio/music/house_ancestors.ogg` | Chapter 4 | Ancestral wordless choral pad, low male voices, occasional bell | 54 BPM, loop |
| `audio/music/combat.ogg` | Ch. 2 & 5 skirmishes | Aggressive layered ethnic drums, dissonant gong hits | 144 BPM, loop |
| `audio/music/boss_shadow_weaver.ogg` | Ch. 5 duel | Epic orchestral-and-gamelan fusion: full drum ensemble, brass, choir stabs. Must have a clear 4-beat pulse — the Weave Mode rhythm game locks to it | 128 BPM, loop |
| `audio/music/restoration.ogg` | Color Burst → ending | The Golden Era melody returning in full orchestration, resolving major | 84 BPM |

### SFX

| Path | Description |
| --- | --- |
| `audio/sfx/bell_brass.ogg` | Single struck brass bell, long decay. The game's signature sound |
| `audio/sfx/footstep_01.ogg` … `_04.ogg` | Bare feet on packed earth and bamboo, randomised |
| `audio/sfx/staff_swing.ogg` | Wooden beater cutting air |
| `audio/sfx/staff_impact.ogg` | Hard wood-on-shadow thud, slightly muffled |
| `audio/sfx/chime_shockwave.ogg` | Brass chime with an expanding, airy tail — the sonic chime ability |
| `audio/sfx/parry.ogg` | Bright metallic clack, very short. Must cut through the boss track |
| `audio/sfx/pickup.ogg` | Soft two-note thread pluck, rising |
| `audio/sfx/quiz_correct.ogg` | Three ascending kulintang notes |
| `audio/sfx/quiz_wrong.ogg` | Single flat damped gong |
| `audio/sfx/unlock_fanfare.ogg` | Short brass-and-drum flourish, ~2 s — a House restored |
| `audio/sfx/life_lost.ogg` | Descending detuned lute note |
| `audio/sfx/ui_click.ogg` | Dry bamboo tick |

---

## 9. Regenerating templates

```
godot --path . res://tools/Templates.tscn
```

Runs windowed on purpose — it needs a rendering device to bake the labels. Writes all 115 files to `assets/images/_templates/`, mirroring the real tree. Add an entry to `CATALOG` in `tools/generate_templates.gd` and it appears here on the next run.
