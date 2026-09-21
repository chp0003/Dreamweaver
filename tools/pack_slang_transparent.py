"""Key magenta plates and pack S'lang sheets onto a transparent 256x192 canvas."""

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"D:\Users\TEMP\Desktop\sideproj\Dreamweaver")
GEN = Path(r"C:\Users\TEMP\.cursor\projects\d-Users-TEMP-Desktop-sideproj-Dreamweaver\assets")
SRC_DIR = ROOT / "assets/images/characters/slang_8dir_src"
OUT_DIR = ROOT / "assets/images/characters/slang_8dir"
FALLBACK = ROOT / "assets/images/characters"

FRAME_W, FRAME_H = 256, 192
FRAME_PAD = 12
COLS, ROWS = 4, 2
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
    for plate in plates:
        if dist(c, plate) < PLATE_DIST:
            return True
        # Hot magenta / pink studio plates, even if the corner sample drifted.
        if c[0] > 160 and c[2] > 70 and c[1] < 70 and chroma(c) > 0.35:
            return True
    return False


def collect_plates(img: Image.Image) -> list[tuple]:
    w, h = img.size
    px = img.load()
    pts = [
        (2, 2),
        (w - 3, 2),
        (2, h - 3),
        (w - 3, h - 3),
        (w // 2, 2),
        (w // 2, h - 3),
        (2, h // 3),
        (w - 3, h // 3),
    ]
    plates: list[tuple] = []
    for x, y in pts:
        c = px[x, y]
        if c[3] < 80:
            continue
        if luma(c) < 0.12:
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
        queue.append((x, y - 1))

    # Enclosed plate pockets (between arm and staff) never touch the edge.
    for y in range(h):
        for x in range(w):
            if is_plate(px[x, y], plates):
                px[x, y] = (0, 0, 0, 0)

    # Knock magenta fringe hugging the silhouette without eating dress reds.
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
    return img.split()[-1].getbbox()


def fit_frame(cell: Image.Image, scale: float) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    if cell.size[0] < 1 or cell.size[1] < 1:
        return canvas
    cropped = cell
    tw = max(1, int(round(cropped.size[0] * scale)))
    th = max(1, int(round(cropped.size[1] * scale)))
    scaled = cropped.resize((tw, th), Image.Resampling.LANCZOS)
    if tw > FRAME_W:
        left = (tw - FRAME_W) // 2
        scaled = scaled.crop((left, 0, left + FRAME_W, th))
        tw = FRAME_W
    if th > FRAME_H:
        scaled = scaled.crop((0, th - FRAME_H, tw, FRAME_H))
        th = FRAME_H
    ox = (FRAME_W - tw) // 2
    oy = max(0, FRAME_H - FRAME_PAD - th)
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas


def lock_feet(cell: Image.Image, shared_h: int) -> Image.Image:
    box = opaque_bbox(cell)
    if not box:
        return cell
    x0, _y0, x1, y1 = box
    pad_x = 10
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


def pack_grid(src: Path, dest_strip: Path, idle_path: Path | None = None) -> None:
    keyed = key_plate(Image.open(src))
    width, height = keyed.size
    cell_w, cell_h = width // COLS, height // ROWS
    cells: list[Image.Image] = []
    shared_h = 1
    for row in range(ROWS):
        for col in range(COLS):
            cell = keyed.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            box = opaque_bbox(cell)
            if box:
                shared_h = max(shared_h, box[3] - box[1])
            cells.append(cell)
    cells = [lock_feet(cell, shared_h) for cell in cells]
    scale = float(FRAME_H - FRAME_PAD * 2) / float(shared_h + 8)
    frames = [fit_frame(cell, scale) for cell in cells]
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * FRAME_W, 0), frame)
        print(f"  frame {i + 1:02d} bbox={opaque_bbox(frame)} corner={frame.getpixel((0, 0))}")
    dest_strip.parent.mkdir(parents=True, exist_ok=True)
    strip.save(dest_strip)
    print(f"wrote {dest_strip} {strip.size} a0={strip.getpixel((0, 0))}")
    if idle_path is not None:
        frames[0].save(idle_path)
        print(f"wrote {idle_path} bbox={opaque_bbox(frames[0])}")


def main() -> None:
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    walk_src = GEN / "slang_walk_down_right_8f.png"
    atk_src = GEN / "slang_attack_down_right_8f.png"
    hall_src = GEN / "sacred_loom_hall.png"

    (SRC_DIR / "slang_walk_down_right_8f.png").write_bytes(walk_src.read_bytes())
    (SRC_DIR / "slang_attack_down_right_8f.png").write_bytes(atk_src.read_bytes())

    print("WALK")
    pack_grid(walk_src, OUT_DIR / "walk_down_right.png")
    (FALLBACK / "slang_walk_cycle.png").write_bytes((OUT_DIR / "walk_down_right.png").read_bytes())

    print("ATTACK")
    pack_grid(
        atk_src,
        OUT_DIR / "attack_down_right.png",
        idle_path=OUT_DIR / "idle_down_right.png",
    )
    (FALLBACK / "slang_attack_swing.png").write_bytes((OUT_DIR / "attack_down_right.png").read_bytes())

    hall_dest = ROOT / "assets/images/environments/house_sacred/sacred_loom_hall.png"
    hall_dest.write_bytes(hall_src.read_bytes())
    print(f"wrote {hall_dest} {Image.open(hall_dest).size}")


if __name__ == "__main__":
    main()
