"""Pack generated S'lang walk cycles onto a locked 256x192 feet-bottom canvas."""

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat

GEN = Path(r"C:\Users\Admin\.cursor\projects\e-dreamweaver\assets")
ROOT = Path(r"e:\dreamweaver")
SRC_DIR = ROOT / "assets/images/characters/slang_8dir_src"
OUT_DIR = ROOT / "assets/images/characters/slang_8dir"
FALLBACK = ROOT / "assets/images/characters"
INDIV_DIR = ROOT / "assets/images/characters/slang_walk_plant"

FRAME_W, FRAME_H = 256, 192
FRAME_PAD = 10
PLATE_DIST = 0.34


def luma(c: tuple) -> float:
    r, g, b, _a = c
    return (r * 0.299 + g * 0.587 + b * 0.114) / 255.0


def chroma(c: tuple) -> float:
    r, g, b, _a = c
    return (max(r, g, b) - min(r, g, b)) / 255.0


def dist(a: tuple, b: tuple) -> float:
    return (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])) / 255.0


def is_plate(c: tuple, plates: list[tuple]) -> bool:
    if c[3] < 18:
        return True
    r, g, b, a = c
    # Hot magenta / pink studio plates.
    if r > 150 and b > 60 and g < 90 and chroma(c) > 0.32:
        return True
    for plate in plates:
        if dist(c, plate) < PLATE_DIST:
            return True
        if luma(plate) > 0.72 and luma(c) > 0.78 and chroma(c) < 0.12:
            return True
    return False


def collect_plates(img: Image.Image) -> list[tuple]:
    w, h = img.size
    px = img.load()
    pts = [
        (2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3),
        (w // 2, 2), (w // 2, h - 3), (2, h // 3), (w - 3, h // 3),
        (w // 4, 2), (3 * w // 4, 2),
    ]
    plates: list[tuple] = []
    for x, y in pts:
        c = px[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]
        if c[3] < 80 or luma(c) < 0.12:
            continue
        if any(dist(c, other) < 0.12 for other in plates):
            continue
        plates.append(c)
    return plates or [(226, 14, 130, 255)]


def key_plate(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    plates = collect_plates(img)
    seen = bytearray(w * h)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if seen[idx]:
            continue
        seen[idx] = 1
        if not is_plate(px[x, y], plates):
            continue
        px[x, y] = (0, 0, 0, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((y, y - 1) if False else (x, y - 1))

    for y in range(h):
        for x in range(w):
            if is_plate(px[x, y], plates):
                px[x, y] = (0, 0, 0, 0)

    for _ in range(4):
        kill: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if c[3] < 20:
                    continue
                near_clear = False
                for oy in (-1, 0, 1):
                    for ox in (-1, 0, 1):
                        nx, ny = x + ox, y + oy
                        if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] < 20:
                            near_clear = True
                            break
                    if near_clear:
                        break
                if not near_clear:
                    continue
                if is_plate(c, plates) or (luma(c) > 0.62 and chroma(c) < 0.18):
                    kill.append((x, y))
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    return img


def opaque_bbox(img: Image.Image):
    alpha = img.split()[-1]
    return alpha.getbbox()


def head_cx(img: Image.Image) -> float:
    box = opaque_bbox(img)
    if not box:
        return img.width / 2.0
    x0, y0, x1, y1 = box
    band = img.crop((x0, y0, x1, y0 + max(4, int((y1 - y0) * 0.30))))
    alpha = band.split()[-1]
    total = 0.0
    weight = 0.0
    px = alpha.load()
    bw, bh = band.size
    for y in range(bh):
        for x in range(bw):
            a = px[x, y]
            if a < 40:
                continue
            total += x * a
            weight += a
    if weight < 1:
        return (x0 + x1) / 2.0
    return x0 + (total / weight)


def lock_feet(cell: Image.Image, shared_h: int) -> Image.Image:
    box = opaque_bbox(cell)
    if not box:
        return cell
    x0, _y0, x1, y1 = box
    pad_x = 14
    top = y1 - shared_h
    if top < 0:
        extra = -top
        padded = Image.new("RGBA", (cell.width, cell.height + extra), (0, 0, 0, 0))
        padded.paste(cell, (0, extra), cell)
        cell = padded
        y1 += extra
        top = 0
    return cell.crop((
        max(0, x0 - pad_x),
        max(0, top),
        min(cell.width, x1 + pad_x),
        y1,
    ))


def fit_frame(cell: Image.Image, scale: float, idle_foot_y: int | None = None) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    if cell.size[0] < 1 or cell.size[1] < 1:
        return canvas
    tw = max(1, int(round(cell.size[0] * scale)))
    th = max(1, int(round(cell.size[1] * scale)))
    scaled = cell.resize((tw, th), Image.Resampling.LANCZOS)
    if tw > FRAME_W:
        cx = head_cx(scaled)
        left = int(cx - FRAME_W / 2.0)
        left = max(0, min(tw - FRAME_W, left))
        scaled = scaled.crop((left, 0, left + FRAME_W, th))
        tw = FRAME_W
    if th > FRAME_H:
        scaled = scaled.crop((0, th - FRAME_H, tw, FRAME_H))
        th = FRAME_H
    ox = int((FRAME_W - tw) / 2.0)
    if idle_foot_y is None:
        oy = max(0, FRAME_H - FRAME_PAD - th)
    else:
        oy = max(0, idle_foot_y - th)
        if oy + th > FRAME_H:
            oy = FRAME_H - th
    canvas.paste(scaled, (ox, oy), scaled)
    return recenter_head(canvas)


def recenter_head(canvas: Image.Image) -> Image.Image:
    cx = head_cx(canvas)
    shift = int(round(FRAME_W / 2.0 - cx))
    if shift == 0:
        return canvas
    shifted = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    shifted.paste(canvas, (shift, 0), canvas)
    return shifted


def idle_metrics(path: Path) -> tuple[int, int]:
    if not path.exists():
        return FRAME_H - FRAME_PAD * 2, FRAME_H - FRAME_PAD
    img = Image.open(path).convert("RGBA")
    box = opaque_bbox(img)
    if not box:
        return FRAME_H - FRAME_PAD * 2, FRAME_H - FRAME_PAD
    return box[3] - box[1], box[3]


def split_grid(img: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    width, height = img.size
    cell_w, cell_h = width // cols, height // rows
    cells: list[Image.Image] = []
    inset_x = max(2, cell_w // 40)
    inset_y = max(2, cell_h // 40)
    for row in range(rows):
        for col in range(cols):
            cells.append(img.crop((
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                (col + 1) * cell_w - inset_x,
                (row + 1) * cell_h - inset_y,
            )))
    return cells


def pack_cells(cells: list[Image.Image], dest: Path, idle_path: Path | None = None) -> list[Image.Image]:
    shared_h = 1
    for cell in cells:
        box = opaque_bbox(cell)
        if box:
            shared_h = max(shared_h, box[3] - box[1])
    cells = [lock_feet(cell, shared_h) for cell in cells]
    idle_h, idle_foot = idle_metrics(idle_path) if idle_path else (0, FRAME_H - FRAME_PAD)
    if idle_h > 8:
        scale = float(idle_h) / float(shared_h)
    else:
        scale = float(FRAME_H - FRAME_PAD * 2) / float(shared_h + 8)
    # Keep a little headroom if the idle-matched scale would clip the staff.
    max_scale = float(FRAME_H - 6) / float(shared_h)
    scale = min(scale, max_scale)
    frames = [fit_frame(cell, scale, idle_foot) for cell in cells]
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    prev = None
    diffs: list[int] = []
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * FRAME_W, 0), frame)
        box = opaque_bbox(frame)
        if prev is not None:
            delta = ImageChops.difference(prev, frame).split()[-1]
            diffs.append(int(ImageStat.Stat(delta).sum[0] / 255.0))
        prev = frame
        print(f"  frame {i + 1:02d} bbox={box}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    strip.save(dest)
    print(f"wrote {dest} {strip.size} diffs={diffs}")
    return frames


def pack_grid(src: Path, dest: Path, cols: int, rows: int, idle_path: Path | None = None) -> None:
    keyed = key_plate(Image.open(src))
    cells = split_grid(keyed, cols, rows)
    pack_cells(cells, dest, idle_path)


def pack_individuals(paths: list[Path], dest: Path, idle_path: Path | None = None) -> None:
    cells = [key_plate(Image.open(p)) for p in paths]
    pack_cells(cells, dest, idle_path)


def copy_src(src: Path, name: str) -> Path:
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    dest = SRC_DIR / name
    dest.write_bytes(src.read_bytes())
    print(f"src {dest}")
    return dest


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    INDIV_DIR.mkdir(parents=True, exist_ok=True)

    jobs = [
        (GEN / "slang_walk_down_right_12f.png", "slang_walk_down_right_plant_12f.png",
         OUT_DIR / "walk_down_right.png", 4, 3, OUT_DIR / "idle_down_right.png"),
        (GEN / "slang_walk_down_8f.png", "slang_walk_down_plant_8f.png",
         OUT_DIR / "walk_down.png", 4, 2, OUT_DIR / "idle_down.png"),
        (GEN / "slang_walk_right_8f.png", "slang_walk_right_plant_8f.png",
         OUT_DIR / "walk_right.png", 4, 2, OUT_DIR / "idle_right.png"),
        (GEN / "slang_walk_up_right_8f.png", "slang_walk_up_right_plant_8f.png",
         OUT_DIR / "walk_up_right.png", 4, 2, OUT_DIR / "idle_up_right.png"),
        (GEN / "slang_walk_up_8f.png", "slang_walk_up_plant_8f.png",
         OUT_DIR / "walk_up.png", 4, 2, OUT_DIR / "idle_up.png"),
    ]
    for src, src_name, dest, cols, rows, idle in jobs:
        if not src.exists():
            raise FileNotFoundError(src)
        copy_src(src, src_name)
        print(f"PACK {src.name} -> {dest.name}")
        pack_grid(src, dest, cols, rows, idle)

    # Also keep an 8-frame down-right strip from the tighter cycle.
    eight = GEN / "slang_walk_down_right_8f.png"
    copy_src(eight, "slang_walk_down_right_plant_8f.png")
    pack_grid(
        eight,
        OUT_DIR / "walk_down_right_8f.png",
        4, 2,
        OUT_DIR / "idle_down_right.png",
    )

    indiv = [
        GEN / "slang_walk_dr_01_contact_r.png",
        GEN / "slang_walk_dr_02_down_r.png",
        GEN / "slang_walk_dr_03_pass_r.png",
        GEN / "slang_walk_dr_04_high_r.png",
        GEN / "slang_walk_dr_05_contact_l.png",
        GEN / "slang_walk_dr_06_down_l.png",
        GEN / "slang_walk_dr_07_pass_l.png",
        GEN / "slang_walk_dr_08_high_l.png",
    ]
    for path in indiv:
        (INDIV_DIR / path.name).write_bytes(path.read_bytes())
    pack_individuals(indiv, OUT_DIR / "walk_down_right_indiv.png", OUT_DIR / "idle_down_right.png")

    # Game fallback strip is the facing actually used most.
    (FALLBACK / "slang_walk_cycle.png").write_bytes((OUT_DIR / "walk_down_right.png").read_bytes())
    print("fallback slang_walk_cycle.png")


if __name__ == "__main__":
    main()
