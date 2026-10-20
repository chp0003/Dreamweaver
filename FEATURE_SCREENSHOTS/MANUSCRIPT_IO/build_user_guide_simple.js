const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, ImageRun, AlignmentType } = require("docx");

const OUT_DIR = path.join("e:", "dreamweaver", "FEATURE_SCREENSHOTS", "MANUSCRIPT_IO");
const SHOTS = path.join("e:", "dreamweaver", "tools", "shots", "user_guide");

function p(children, opts = {}) {
  return new Paragraph({
    spacing: { after: opts.after ?? 120, before: opts.before ?? 0 },
    alignment: opts.align ?? AlignmentType.LEFT,
    children,
  });
}

function t(text, opts = {}) {
  return new TextRun({
    text,
    font: "Times New Roman",
    size: opts.size ?? 24,
    bold: !!opts.bold,
    italics: !!opts.italics,
  });
}

function heading(text) {
  return p([t(text, { bold: true, size: 26 })], { before: 240, after: 120 });
}

function body(text) {
  return p([t(text)], { after: 120 });
}

function bullet(text) {
  return p([t("•  " + text)], { after: 80 });
}

function shot(file, caption) {
  const full = path.join(SHOTS, file);
  if (!fs.existsSync(full)) throw new Error("Missing " + full);
  const bytes = fs.readFileSync(full);
  const width = 520;
  const height = Math.round((width * 720) / 1280);
  return [
    p(
      [
        new ImageRun({
          type: "png",
          data: bytes,
          transformation: { width, height },
          altText: { title: caption, description: caption, name: file },
        }),
      ],
      { align: AlignmentType.CENTER, before: 100, after: 60 }
    ),
    p([t(caption, { italics: true, size: 22 })], {
      align: AlignmentType.CENTER,
      after: 180,
    }),
  ];
}

async function main() {
  const children = [];

  children.push(
    p([t("USER GUIDE", { bold: true, size: 32 })], {
      align: AlignmentType.CENTER,
      after: 60,
    }),
    p([t("Dreamweaver: The Legend of Fun Kdungon", { bold: true, size: 24 })], {
      align: AlignmentType.CENTER,
      after: 240,
    })
  );

  // How to Start
  children.push(heading("How to Start"));
  children.push(
    body(
      "Sign in or register first. The Gateway then offers Continue when a save exists, New Game, Load Game, Lore Codex, Leaderboard, Settings, Log Out, and Quit. Settings covers master volume, music, effects, and fullscreen. New Game asks before it overwrites a save already on the account."
    )
  );
  children.push(...shot("01_login.png", "Login screen"));
  children.push(...shot("02_register.png", "Register screen"));
  children.push(...shot("03_gateway.png", "The Gateway after sign-in"));
  children.push(...shot("04_settings_audio.png", "Settings — volume, music, and effects"));

  // Controls
  children.push(heading("Controls"));
  children.push(bullet("W, A, S, D — move S’lang."));
  children.push(bullet("E — talk, use a station, or start a weave."));
  children.push(bullet("R — pick up strands, roots, and other items."));
  children.push(bullet("Space — swing the Lewet Staff."));
  children.push(
    bullet("Shift, or the right mouse button — roll. For a short moment, attacks pass through her.")
  );
  children.push(
    bullet(
      "Q — sonic shockwave. It wakes the torches in the House of the Golden Sun. After the Harvest Queen grants Life-Thread, it bursts the corrupted thorns in the House of Red Courage."
    )
  );
  children.push(bullet("1 — raises the woven ward."));
  children.push(bullet("2 — fires the light beam (see below for when it unlocks)."));
  children.push(bullet("Left click an enemy — run in and strike."));
  children.push(bullet("I — opens the satchel."));
  children.push(bullet("Esc — pauses."));
  children.push(
    body(
      "The tutorial teaches these prompts on screen. Use that room to learn movement, dialogue, and the first objectives before you reach the hub."
    )
  );
  children.push(...shot("08_tutorial_controls.png", "Tutorial — on-screen control guides"));

  // Light Beam
  children.push(heading("The Light Beam"));
  children.push(
    body(
      "The 2 key is a blast from the staff, fired straight along the way S’lang is facing. She gathers for a moment, then the beam goes out, and it has to cool before it can be used again. It is not on the staff in the early houses. In the final house the shadows come in three waves. Clear the third wave. Before she walks to the loom and before the Shadow Weaver appears, a banner says Light beam. From that point, including the boss fight, she can fire it. The screen also shows a meter for it."
    )
  );
  children.push(...shot("16_chapter5_sacred_loom.png", "Final house — Sacred Loom (light beam unlocks after Wave III)"));

  // Final House
  children.push(heading("The Final House"));
  children.push(
    body(
      "Wave I, Wave II, and Wave III are fought with Space, Shift, and Q. After Wave III, 1 and 2 are both shown. At the loom, roll or ward the bleach attacks. When the Weaver is staggered, press E and match W, A, S, D on the rhythm track. When he falls, the last stitch is another W, A, S, D sequence, and the colour returns."
    )
  );
  children.push(...shot("17_hub_restored.png", "World restored after the final stitch"));

  // Satchel, Pause, Codex
  children.push(heading("Satchel, Pause, and Codex"));
  children.push(
    body(
      "I opens the satchel, which holds the staff, the dye essences, the notes, and the other items she has gathered. Esc opens the pause menu: Resume, Settings, Lore Codex, return to the hub, or back to the main menu. Lore entries are earned from the houses and can be read again from the Gateway, the pause menu, or the credits. The leaderboard on the Gateway lists scores."
    )
  );
  children.push(...shot("11_satchel.png", "Satchel (press I)"));
  children.push(...shot("10_pause_menu.png", "Pause menu (press Esc)"));
  children.push(...shot("05_lore_codex.png", "Lore Codex"));
  children.push(...shot("06_leaderboard.png", "Leaderboard"));

  // Quick map of the journey
  children.push(heading("The Five Houses"));
  children.push(
    body(
      "From the hub, enter each House in order. Black Foundation, Red Courage, Golden Sun, Dream Ancestors, then the Sacred Loom."
    )
  );
  children.push(...shot("09_hub_world.png", "Hub — Crossroads of the Five Houses"));
  children.push(...shot("12_chapter1.png", "Chapter 1 — Black Foundation"));
  children.push(...shot("13_chapter2.png", "Chapter 2 — Red Courage"));
  children.push(...shot("14_chapter3.png", "Chapter 3 — Golden Sun"));
  children.push(...shot("15_chapter4.png", "Chapter 4 — Dream Ancestors"));
  children.push(...shot("16_chapter5_sacred_loom.png", "Chapter 5 — The Sacred Loom"));
  children.push(...shot("18_ending.png", "Ending screen"));

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

  const outPath = path.join(OUT_DIR, "Dreamweaver_User_Guide.docx");
  fs.writeFileSync(outPath, await Packer.toBuffer(doc));
  console.log("WROTE", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
