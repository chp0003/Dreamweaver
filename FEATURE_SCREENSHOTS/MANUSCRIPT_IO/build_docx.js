const fs = require("fs");
const path = require("path");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ImageRun,
  AlignmentType,
  HeadingLevel,
} = require("docx");

const OUT_DIR = __dirname;
const SHOTS = path.join("e:", "dreamweaver", "tools", "shots");

const entries = [
  {
    n: 1,
    title: "Game Login",
    input:
      "The player opens the installed Dreamweaver application. Action: Enters a registered email or username and password, then selects Login.",
    output:
      "The Login screen displays the Dreamweaver title art with fields for account credentials and options to sign in or create a new account.",
    file: "01_login.png",
    cap: "Sample login screen output",
  },
  {
    n: 2,
    title: "Create Account",
    input:
      "A new player opens the Register screen. Action: Enters account details and confirms registration.",
    output:
      "The registration form is submitted. Successful registration allows the player to sign in and continue to the Gateway (Main Menu). Validation messages guide the player if required fields are incomplete.",
    file: "01b_register.png",
    cap: "Sample input screen for account registration",
  },
  {
    n: 3,
    title: "Main Menu (The Gateway)",
    input:
      "The player completes sign-in with a valid account. Action: Lands on the Gateway after authentication.",
    output:
      "The Main Menu displays the Dreamweaver title, account controls, Settings, and Log Out. From the Gateway the player begins a new playthrough or continues a saved run.",
    file: "02_main_menu.png",
    cap: "Sample Main Menu output after sign-in",
  },
  {
    n: 4,
    title: "Story Prologue",
    input:
      "The player selects New Game from the Gateway. Action: Advances through the prologue panels.",
    output:
      "The Story Intro presents the prologue narrative with a progress track and a Skip option. Selecting Begin the journey continues into the tutorial.",
    file: "03_story_intro.png",
    cap: "Sample story prologue output",
  },
  {
    n: 5,
    title: "Tutorial — S’lang’s Awakening",
    input:
      "The player finishes the prologue and enters the tutorial scene. Action: Moves S’lang and advances narrator dialogue with E.",
    output:
      "The tutorial room appears in a bleached grayscale state. The HUD shows lives and health, the objective is shown, and the dialogue box types narrator text with an E · continue prompt.",
    file: "04_tutorial.png",
    cap: "Sample tutorial dialogue and objective output",
  },
  {
    n: 6,
    title: "Hub World — Crossroads of the Five Houses",
    input:
      "The player completes the tutorial and receives the Lewet Staff. Action: Follows the guide markers to Black Foundation and presses E at the porch.",
    output:
      "The hub shows five labeled Houses. Black Foundation is marked open while later Houses remain locked. The objective banner, HUD bars, and essence slots are visible.",
    file: "05_hub.png",
    cap: "Sample hub world output",
  },
  {
    n: 7,
    title: "Chapter 1 — House of the Black Foundation",
    input:
      "The player enters Black Foundation from the hub. Action: Explores the cold hall to find the Spirit of the Fiber.",
    output:
      "The chapter interior loads with the House objective, HUD, and Lewet Staff essence indicators inside the isometric room.",
    file: "06_chapter1.png",
    cap: "Sample Chapter 1 house interior output",
  },
  {
    n: 8,
    title: "Chapter 2 — House of Red Courage",
    input:
      "The player unlocks and enters Red Courage. Action: Cuts shadow vines and hunts objectives past shadow minions.",
    output:
      "The Red Courage chapter scene loads with combat-capable enemies and House quest UI while the player proceeds through the restoration tasks.",
    file: "06b_chapter2.png",
    cap: "Sample Chapter 2 house output",
  },
  {
    n: 9,
    title: "Chapter 3 — House of the Golden Sun",
    input:
      "The player enters Golden Sun. Action: Lights torches with the chime and solves the brass mirror beam puzzle.",
    output:
      "The Golden Sun chapter displays the hall layout, puzzle props, and current House objective on the HUD.",
    file: "06c_chapter3.png",
    cap: "Sample Chapter 3 house output",
  },
  {
    n: 10,
    title: "Chapter 4 — House of the Dream Ancestors",
    input:
      "The player enters Dream Ancestors. Action: Speaks with the ancestor statues and answers the T’boli culture quizzes.",
    output:
      "The Dream Ancestors chapter loads the statue hall with quiz and lore prompts. Wrong answers count toward the chapter retake limit.",
    file: "06d_chapter4.png",
    cap: "Sample Chapter 4 Dream Ancestors output",
  },
  {
    n: 11,
    title: "Chapter 5 — The Sacred Loom",
    input:
      "The player enters the Sacred Loom with all essences and the Master Pattern. Action: Breaches the hall and duels the Shadow Weaver.",
    output:
      "Chapter 5 loads the final Sacred Loom encounter space with the boss fight preparation, HUD, and endgame objective.",
    file: "06e_chapter5.png",
    cap: "Sample Chapter 5 Sacred Loom output",
  },
  {
    n: 12,
    title: "Color Restoration — World Restored",
    input:
      "The player restores the Houses and defeats the Shadow Weaver. Action: Triggers the Color Burst at the end of Chapter 5.",
    output:
      "The grayscale veil clears. The Crossroads returns to full colour and House labels show restored status.",
    file: "hub_restored.png",
    cap: "Sample color restoration output after Color Burst",
  },
  {
    n: 13,
    title: "Ending",
    input:
      "The player completes the final Sacred Loom sequence. Action: Watches the closing sequence and ending screen.",
    output:
      "The Ending scene displays the final rank, score summary, and return options after the world is restored.",
    file: "07_ending.png",
    cap: "Sample ending screen output",
  },
];

function ioParagraph(label, text) {
  return new Paragraph({
    spacing: { after: 120 },
    children: [
      new TextRun({ text: `${label} `, bold: true, font: "Times New Roman", size: 24 }),
      new TextRun({ text, font: "Times New Roman", size: 24 }),
    ],
  });
}

function loadImage(file) {
  const full = path.join(SHOTS, file);
  if (!fs.existsSync(full)) {
    throw new Error(`Missing screenshot: ${full}`);
  }
  return fs.readFileSync(full);
}

async function main() {
  const children = [];

  children.push(
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 60 },
      children: [
        new TextRun({ text: "APPENDIX", bold: true, font: "Times New Roman", size: 28 }),
      ],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 240 },
      children: [
        new TextRun({
          text: "Sample Screenshots of Dreamweaver: The Legend of Fun Kdungon",
          bold: true,
          font: "Times New Roman",
          size: 24,
        }),
      ],
    }),
    new Paragraph({
      spacing: { after: 280 },
      children: [
        new TextRun({
          text:
            "This appendix presents sample player inputs and their corresponding screen outputs for Dreamweaver: The Legend of Fun Kdungon. Each item shows the player action (Input), the resulting game screen (Output), and a captured screenshot from the current build.",
          font: "Times New Roman",
          size: 24,
        }),
      ],
    })
  );

  for (const e of entries) {
    const bytes = loadImage(e.file);
    // Keep images manuscript-friendly width (~6.0 in)
    const width = 550;
    const height = Math.round((width * 720) / 1280);

    children.push(
      new Paragraph({
        spacing: { before: 280, after: 120 },
        children: [
          new TextRun({
            text: `${e.n}. ${e.title}`,
            bold: true,
            font: "Times New Roman",
            size: 24,
          }),
        ],
      }),
      ioParagraph("Input:", e.input),
      ioParagraph("Output:", e.output),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 120, after: 80 },
        children: [
          new ImageRun({
            type: "png",
            data: bytes,
            transformation: { width, height },
            altText: { title: e.title, description: e.cap, name: e.file },
          }),
        ],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 200 },
        children: [
          new TextRun({
            text: e.cap,
            italics: true,
            font: "Times New Roman",
            size: 22,
          }),
        ],
      })
    );

    // Also copy into this folder for backup
    fs.copyFileSync(path.join(SHOTS, e.file), path.join(OUT_DIR, `${String(e.n).padStart(2, "0")}_${e.file}`));
  }

  const doc = new Document({
    styles: {
      default: {
        document: {
          styles: [{ id: "Normal", run: { font: "Times New Roman", size: 24 } }],
        },
      },
    },
    sections: [
      {
        properties: {
          page: {
            margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
          },
        },
        children,
      },
    ],
  });

  const outPath = path.join(OUT_DIR, "Dreamweaver_Appendix_Input_Output.docx");
  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(outPath, buffer);
  console.log("WROTE", outPath, buffer.length, "bytes");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
