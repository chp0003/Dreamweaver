"""Pack generated 4x2 NPC walk grids onto 256x192 feet-bottom strips."""

from pathlib import Path

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "assets/images/_src/npc_walk_grids"
OUT = ROOT / "assets/images/characters/npc_stride"
FRAME_DIR = OUT / "frames"
FRAME_W, FRAME_H = 256, 192
FOOT_PAD = 4

JOBS = [
    ("chief", "right", "chief_walk_right_8f.jpg"),
    ("chief", "down_right", "chief_walk_down_right_8f.jpg"),
    ("chief", "down", "chief_walk_down_8f.jpg"),
    ("chief", "up", "chief_walk_up_8f.jpg"),
    ("chief", "up_right", "chief_walk_up_right_8f.jpg"),
    ("chief", "right", "chief_walk_right_8f.png"),
    ("chief", "down_right", "chief_walk_down_right_8f.png"),
    ("chief", "down", "chief_walk_down_8f.png"),
    ("chief", "up", "chief_walk_up_8f.png"),
    ("chief", "up_right", "chief_walk_up_right_8f.png"),
    ("fun", "right", "fun_walk_right_8f.jpg"),
    ("fun", "down_right", "fun_walk_down_right_8f.jpg"),
    ("fun", "down", "fun_walk_down_8f.jpg"),
    ("fun", "up", "fun_walk_up_8f.jpg"),
    ("fun", "up_right", "fun_walk_up_right_8f.jpg"),
    ("fun", "right", "fun_walk_right_8f.png"),
    ("fun", "down_right", "fun_walk_down_right_8f.png"),
    ("fun", "down", "fun_walk_down_8f.png"),
    ("fun", "up", "fun_walk_up_8f.png"),
    ("fun", "up_right", "fun_walk_up_right_8f.png"),
]


def key_black(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 12:
                px[x, y] = (0, 0, 0, 0)
                continue
            luma = (r * 299 + g * 587 + b * 114) / 1000
            if luma < 18:
                px[x, y] = (0, 0, 0, 0)
            elif luma < 28 and max(r, g, b) - min(r, g, b) < 12:
                px[x, y] = (0, 0, 0, 0)
    return img


def opaque_bbox(img: Image.Image):
    return img.split()[-1].getbbox()


def split_grid(img: Image.Image, cols: int = 4, rows: int = 2) -> list[Image.Image]:
    w, h = img.size
    cw, ch = w // cols, h // rows
    inset_x = max(2, cw // 50)
    inset_y = max(2, ch // 50)
    cells = []
    for row in range(rows):
        for col in range(cols):
            cells.append(img.crop((
                col * cw + inset_x,
                row * ch + inset_y,
                (col + 1) * cw - inset_x,
                (row + 1) * ch - inset_y,
            )))
    return cells


def fit_frame(cell: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    box = opaque_bbox(cell)
    if not box:
        return canvas
    cropped = cell.crop(box)
    tw, th = cropped.size
    max_h = FRAME_H - FOOT_PAD * 2
    max_w = FRAME_W - 8
    scale = min(max_w / tw, max_h / th, 1.35)
    nw = max(1, int(round(tw * scale)))
    nh = max(1, int(round(th * scale)))
    if (nw, nh) != (tw, th):
        cropped = cropped.resize((nw, nh), Image.Resampling.NEAREST)
        tw, th = nw, nh
    ox = int((FRAME_W - tw) / 2)
    oy = FRAME_H - FOOT_PAD - th
    canvas.paste(cropped, (ox, oy), cropped)
    return canvas


def pack(sheet_id: str, dir_name: str, filename: str) -> bool:
    src = GEN / filename
    if not src.exists():
        return False
    img = key_black(Image.open(src))
    cells = [fit_frame(key_black(cell)) for cell in split_grid(img)]
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    strip = Image.new("RGBA", (FRAME_W * len(cells), FRAME_H), (0, 0, 0, 0))
    prev = None
    diffs = []
    for i, frame in enumerate(cells):
        strip.paste(frame, (i * FRAME_W, 0), frame)
        frame.save(FRAME_DIR / f"{sheet_id}_{dir_name}_{i + 1:02d}.png")
        if prev is not None:
            delta = ImageChops.difference(prev, frame).split()[-1]
            diffs.append(int(ImageStat.Stat(delta).sum[0] / 255.0))
        prev = frame
    dest = OUT / f"{sheet_id}_{dir_name}.png"
    strip.save(dest)
    print(f"wrote {dest.relative_to(ROOT)} diffs={diffs}")
    return True


def main() -> None:
    done: set[tuple[str, str]] = set()
    for sheet_id, dir_name, filename in JOBS:
        key = (sheet_id, dir_name)
        if key in done:
            continue
        if pack(sheet_id, dir_name, filename):
            done.add(key)
    missing = [
        (who, d)
        for who in ("chief", "fun")
        for d in ("down", "down_right", "right", "up_right", "up")
        if (who, d) not in done
    ]
    if missing:
        print("still missing:", missing)


if __name__ == "__main__":
    main()
