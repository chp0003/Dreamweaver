const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, ImageRun, AlignmentType } = require("docx");

const OUT_DIR = path.join(
  "e:",
  "dreamweaver",
  "FEATURE_SCREENSHOTS",
  "MANUSCRIPT_IO",
  "USER_GUIDE_SEPARATE"
);
const SHOTS = path.join("e:", "dreamweaver", "tools", "shots", "user_guide");

const entries = [
  {
    n: 1,
    slug: "01_Sign_In",
    title: "Sign In",
    input:
      "The player opens Dreamweaver. Action: Enters a registered email or username and password, then selects Login.",
    output:
      "The Login screen shows the Dreamweaver title art with credential fields and options to sign in or create a new account.",
    file: "01_login.png",
    cap: "Sample login screen",
  },
  {
    n: 2,
    slug: "02_Register",
    title: "Register",
    input:
      "A new player opens the Register screen. Action: Enters account details and confirms registration.",
    output:
      "The registration form is submitted. Successful registration lets the player sign in and reach the Gateway.",
    file: "02_register.png",
    cap: "Sample create-account screen",
  },
  {
    n: 3,
    slug: "03_Gateway",
    title: "The Gateway (Main Menu)",
    input:
      "The player signs in successfully. Action: Reviews the Gateway options.",
    output:
      "The Gateway offers Continue when a save exists, New Game, Load Game, Lore Codex, Leaderboard, Settings, Log Out, and Quit. New Game asks before it overwrites a save already on the account.",
    file: "03_gateway.png",
    cap: "Sample Gateway menu after sign-in",
  },
  {
    n: 4,
    slug: "04_Settings_Audio",
    title: "Settings — Audio",
    input:
      "From the Gateway (or Pause), the player opens Settings. Action: Adjusts master volume, music, and effects.",
    output:
      "The Settings overlay opens on the Audio tab with sliders for master volume, music, and effects.",
    file: "04_settings_audio.png",
    cap: "Sample Settings audio panel",
  },
  {
    n: 5,
    slug: "05_Settings_Display",
    title: "Settings — Display",
    input:
      "In Settings, the player switches to the Display tab. Action: Toggles fullscreen and related display options.",
    output:
      "The Display tab shows fullscreen and other display controls for the game window.",
    file: "04b_settings_display.png",
    cap: "Sample Settings display panel",
  },
  {
    n: 6,
    slug: "06_Lore_Codex",
    title: "Lore Codex",
    input:
      "From the Gateway or Pause menu, the player opens the Lore Codex. Action: Browses earned lore entries.",
    output:
      "The Lore Codex lists entries earned from the Houses so the player can read them again.",
    file: "05_lore_codex.png",
    cap: "Sample Lore Codex screen",
  },
  {
    n: 7,
    slug: "07_Leaderboard",
    title: "Leaderboard",
    input:
      "From the Gateway, the player opens Leaderboard. Action: Views ranked scores.",
    output:
      "The Leaderboard lists player scores for comparison.",
    file: "06_leaderboard.png",
    cap: "Sample Leaderboard screen",
  },
  {
    n: 8,
    slug: "08_Story_Prologue",
    title: "Story Prologue",
    input:
      "The player selects New Game. Action: Advances through the prologue panels.",
    output:
      "The Story Intro presents the prologue narrative. Selecting Begin the journey continues into the tutorial.",
    file: "07_story_intro.png",
    cap: "Sample story prologue",
  },
  {
    n: 9,
    slug: "09_Tutorial_Controls",
    title: "Tutorial and Basic Controls",
    input:
      "The player enters S’lang’s Awakening. Action: Moves with W A S D, advances dialogue with E, and learns the first objectives.",
    output:
      "The tutorial room shows the HUD, objective text, and dialogue. Movement and interaction are introduced here before the hub.",
    file: "08_tutorial_controls.png",
    cap: "Sample tutorial screen (movement and dialogue)",
  },
  {
    n: 10,
    slug: "10_Hub_World",
    title: "Hub World — Crossroads of the Five Houses",
    input:
      "After the tutorial, the player receives the Lewet Staff and reaches the hub. Action: Walks the boardwalk and presses E at a House porch.",
    output:
      "The hub shows the five Houses, objective guidance, health bars, essence slots, and interaction prompts.",
    file: "09_hub_world.png",
    cap: "Sample hub world",
  },
  {
    n: 11,
    slug: "11_Pause_Menu",
    title: "Pause Menu (Esc)",
    input:
      "During gameplay, the player presses Esc. Action: Chooses Resume, Settings, Lore Codex, return to hub, or main menu.",
    output:
      "The pause menu opens over the current scene with resume and navigation options.",
    file: "10_pause_menu.png",
    cap: "Sample pause menu",
  },
  {
    n: 12,
    slug: "12_Satchel",
    title: "Satchel (I)",
    input:
      "The player presses I. Action: Reviews gear, dye essences, notes, and gathered items.",
    output:
      "The satchel overlay shows the Lewet Staff, BLACK / RED / GOLD essences, notes, and other collected items.",
    file: "11_satchel.png",
    cap: "Sample satchel inventory",
  },
  {
    n: 13,
    slug: "13_Chapter1_Controls",
    title: "Controls Overview — Chapter Play",
    input:
      "Inside a House, the player uses the full control set. Action: W A S D move; E talk / use station / start a weave; R pick up strands and roots; Space swing the Lewet Staff; Shift or right mouse button roll; Q sonic shockwave; 1 woven ward; left click an enemy to run in and strike.",
    output:
      "Chapter 1 (Black Foundation) shows in-house play with HUD, objectives, and interactable stations where these controls apply.",
    file: "12_chapter1.png",
    cap: "Sample Chapter 1 gameplay (controls context)",
  },
  {
    n: 14,
    slug: "14_Chapter2_Sonic_Q",
    title: "Q — Sonic Shockwave (Red Courage)",
    input:
      "In the House of Red Courage, after the Harvest Queen grants Life-Thread, the player presses Q near corrupted thorns. Action: Fires the sonic shockwave.",
    output:
      "Chapter 2 loads the Red Courage grounds where Q bursts corrupted thorns and supports combat against shadows.",
    file: "13_chapter2.png",
    cap: "Sample Chapter 2 Red Courage (Q / combat context)",
  },
  {
    n: 15,
    slug: "15_Chapter3_Torches_Q",
    title: "Q — Torches (Golden Sun)",
    input:
      "In the House of the Golden Sun, the player aims near unlit torches. Action: Presses Q to wake the torches, then solves the brass mirror puzzle.",
    output:
      "Chapter 3 shows the Golden Sun hall where the sonic shockwave lights torches for the beam puzzle.",
    file: "14_chapter3.png",
    cap: "Sample Chapter 3 Golden Sun (torch / puzzle context)",
  },
  {
    n: 16,
    slug: "16_Chapter4_Ancestors",
    title: "Dream Ancestors — Quizzes and Notes",
    input:
      "The player enters Dream Ancestors. Action: Speaks with statues (E) and answers T’boli culture quizzes; notes in the satchel support the answers.",
    output:
      "Chapter 4 loads the ancestor hall used for lore quizzes and note-based questions.",
    file: "15_chapter4.png",
    cap: "Sample Chapter 4 Dream Ancestors",
  },
  {
    n: 17,
    slug: "17_Chapter5_Final_House",
    title: "The Final House — Sacred Loom",
    input:
      "The player enters the Sacred Loom with all essences and the Master Pattern. Action: Clears Wave I, Wave II, and Wave III with Space, Shift, and Q. After Wave III, 1 (ward) and 2 (light beam) are shown. At the loom, roll or ward bleach attacks; when the Weaver is staggered, press E and match W A S D on the rhythm track; the last stitch is another W A S D sequence.",
    output:
      "Chapter 5 loads the Sacred Loom endgame space. The light beam (2) unlocks after the third wave, before the Shadow Weaver duel, and a meter appears on screen.",
    file: "16_chapter5_sacred_loom.png",
    cap: "Sample Chapter 5 Sacred Loom (final house)",
  },
  {
    n: 18,
    slug: "18_Color_Restored",
    title: "Color Restoration — World Restored",
    input:
      "The player completes the final stitch after the Shadow Weaver falls. Action: Watches the Color Burst.",
    output:
      "The grayscale veil clears and the Crossroads returns to full colour.",
    file: "17_hub_restored.png",
    cap: "Sample restored hub after Color Burst",
  },
  {
    n: 19,
    slug: "19_Ending",
    title: "Ending",
    input:
      "After the world is restored, the closing sequence finishes. Action: Reviews rank and returns from the ending screen.",
    output:
      "The Ending screen shows the final rank, score summary, and return options. Lore entries remain readable from the Gateway, Pause, or credits.",
    file: "18_ending.png",
    cap: "Sample ending screen",
  },
];

function p(children, opts = {}) {
  return new Paragraph({
    spacing: { after: opts.after ?? 120, before: opts.before ?? 0 },
    alignment: opts.align ?? AlignmentType.LEFT,
    children,
  });
}

function run(text, opts = {}) {
  return new TextRun({
    text,
    font: "Times New Roman",
    size: opts.size ?? 24,
    bold: !!opts.bold,
    italics: !!opts.italics,
  });
}

async function writeOne(e) {
  const full = path.join(SHOTS, e.file);
  if (!fs.existsSync(full)) throw new Error("Missing " + full);
  const bytes = fs.readFileSync(full);
  const width = 540;
  const height = Math.round((width * 720) / 1280);

  const children = [
    p([run(`${e.n}. ${e.title}`, { bold: true, size: 26 })], { after: 160 }),
    p([run("Input: ", { bold: true }), run(e.input)]),
    p([run("Output: ", { bold: true }), run(e.output)]),
    p(
      [
        new ImageRun({
          type: "png",
          data: bytes,
          transformation: { width, height },
          altText: { title: e.title, description: e.cap, name: e.file },
        }),
      ],
      { align: AlignmentType.CENTER, before: 140, after: 80 }
    ),
    p([run(e.cap, { italics: true, size: 22 })], {
      align: AlignmentType.CENTER,
      after: 80,
    }),
  ];

  const doc = new Document({
    sections: [
      {
        properties: {
          page: { margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
        },
        children,
      },
    ],
  });

  const outPath = path.join(OUT_DIR, `${e.slug}.docx`);
  fs.writeFileSync(outPath, await Packer.toBuffer(doc));
  return path.basename(outPath);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  // Clear old separate docs
  for (const f of fs.readdirSync(OUT_DIR)) {
    if (f.endsWith(".docx")) fs.unlinkSync(path.join(OUT_DIR, f));
  }

  const written = [];
  for (const e of entries) {
    written.push(await writeOne(e));
  }

  // Also a short intro-only file (no screenshots) for How to Start / Controls text
  const introChildren = [
    p([run("USER GUIDE — How to Start & Controls", { bold: true, size: 28 })], {
      align: AlignmentType.CENTER,
      after: 200,
    }),
    p([run("How to Start", { bold: true, size: 26 })], { after: 100 }),
    p([
      run(
        "Sign in or register first. The Gateway then offers Continue when a save exists, New Game, Load Game, Lore Codex, Leaderboard, Settings, Log Out, and Quit. Settings covers master volume, music, effects, and fullscreen. New Game asks before it overwrites a save already on the account."
      ),
    ], { after: 200 }),
    p([run("Controls", { bold: true, size: 26 })], { after: 100 }),
    p([run("W, A, S, D — move S’lang.")]),
    p([run("E — talk, use a station, or start a weave.")]),
    p([run("R — pick up strands, roots, and other items.")]),
    p([run("Space — swing the Lewet Staff.")]),
    p([run("Shift or right mouse button — roll (attacks pass through for a short moment).")]),
    p([run("Q — sonic shockwave (wakes Golden Sun torches; bursts Red Courage thorns after Life-Thread).")]),
    p([run("1 — raise the woven ward.")]),
    p([run("2 — fire the light beam (unlocks in the final house after Wave III).")]),
    p([run("Left click an enemy — run in and strike.")]),
    p([run("I — open the satchel.")]),
    p([run("Esc — pause.")], { after: 200 }),
    p([run("The Light Beam", { bold: true, size: 26 })], { after: 100 }),
    p([
      run(
        "The 2 key fires a blast from the staff along the way S’lang is facing. She gathers for a moment, then the beam goes out and must cool before reuse. It is not on the staff in the early houses. In the final house, clear Wave III; a banner says Light beam before she walks to the loom and before the Shadow Weaver appears. From that point, including the boss fight, she can fire it. The screen also shows a meter for it."
      ),
    ], { after: 200 }),
    p([run("The Final House", { bold: true, size: 26 })], { after: 100 }),
    p([
      run(
        "Wave I, Wave II, and Wave III are fought with Space, Shift, and Q. After Wave III, 1 and 2 are both shown. At the loom, roll or ward the bleach attacks. When the Weaver is staggered, press E and match W, A, S, D on the rhythm track. When he falls, the last stitch is another W, A, S, D sequence, and the colour returns."
      ),
    ], { after: 200 }),
    p([run("Satchel, Pause, and Codex", { bold: true, size: 26 })], { after: 100 }),
    p([
      run(
        "I opens the satchel, which holds the staff, the dye essences, the notes, and the other items she has gathered. Esc opens the pause menu: Resume, Settings, Lore Codex, return to the hub, or back to the main menu. Lore entries are earned from the houses and can be read again from the gateway, the pause menu, or the credits. The leaderboard on the gateway lists scores."
      ),
    ]),
  ];

  const introDoc = new Document({
    sections: [
      {
        properties: {
          page: { margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
        },
        children: introChildren,
      },
    ],
  });
  const introPath = path.join(OUT_DIR, "00_How_to_Start_and_Controls.docx");
  fs.writeFileSync(introPath, await Packer.toBuffer(introDoc));
  written.unshift(path.basename(introPath));

  console.log("WROTE", written.length, "files to", OUT_DIR);
  for (const w of written) console.log(" ", w);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
