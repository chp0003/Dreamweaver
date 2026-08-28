from collections import deque
from pathlib import Path

from PIL import Image

WALK_SRC = Path(
    r"C:\Users\TEMP\.cursor\projects\d-Users-TEMP-Desktop-sideproj-Dreamweaver\assets\slang_walk_cycle_8f.png"
)
ATK_SRC = Path(
    r"C:\Users\TEMP\.cursor\projects\d-Users-TEMP-Desktop-sideproj-Dreamweaver\assets\slang_attack_swing_8f.png"
)
DEST_DIR = Path(r"D:\Users\TEMP\Desktop\sideproj\Dreamweaver\assets\images\characters")
FRAME_W, FRAME_H = 128, 192
COLS, ROWS = 4, 2


def luma(c: tuple) -> float:
    r, g, b, _a = c
    return (r * 0.299 + g * 0.587 + b * 0.114) / 255.0


def chroma(c: tuple) -> float:
    r, g, b, _a = c
    return (max(r, g, b) - min(r, g, b)) / 255.0


def is_plate_white(c: tuple) -> bool:
    if c[3] < 16:
        return True
    return luma(c) > 0.86 and chroma(c) < 0.11


def key_white(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    width, height = img.size
    px = img.load()
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        idx = y * width + x
        if seen[idx]:
            continue
        seen[idx] = 1
        color = px[x, y]
        if color[3] < 16 or is_plate_white(color):
            px[x, y] = (0, 0, 0, 0)
            queue.append((x + 1, y))
            queue.append((x - 1, y))
            queue.append((x, y + 1))
            queue.append((x, y - 1))
    for _ in range(3):
        kill: list[tuple[int, int]] = []
        for y in range(height):
            for x in range(width):
                color = px[x, y]
                if color[3] < 20:
                    continue
                near_clear = False
                for oy in (-1, 0, 1):
                    for ox in (-1, 0, 1):
                        nx, ny = x + ox, y + oy
                        if nx < 0 or ny < 0 or nx >= width or ny >= height or px[nx, ny][3] < 20:
                            near_clear = True
                            break
                    if near_clear:
                        break
                if not near_clear:
                    continue
                light, sat = luma(color), chroma(color)
                if (light > 0.58 and sat < 0.24) or (color[3] < 160 and light > 0.48):
                    kill.append((x, y))
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    return img


def opaque_bbox(img: Image.Image):
    return img.split()[-1].getbbox()


def fit_frame(cell: Image.Image) -> Image.Image:
    box = opaque_bbox(cell)
    if not box:
        return Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    cropped = cell.crop(box)
    cw, ch = cropped.size
    # Lock stature to canvas height so walk/attack match idle. Wide staff
    # poses may clip at the sides; feet stay on the bottom edge.
    scale = FRAME_H / float(ch)
    tw = max(1, int(round(cw * scale)))
    th = FRAME_H
    scaled = cropped.resize((tw, th), Image.Resampling.LANCZOS)
    if tw > FRAME_W:
        left = (tw - FRAME_W) // 2
        scaled = scaled.crop((left, 0, left + FRAME_W, th))
        tw = FRAME_W
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    ox = (FRAME_W - tw) // 2
    canvas.paste(scaled, (ox, 0), scaled)
    return canvas


def process(src: Path, strip_name: str, frame_prefix: str) -> None:
    keyed = key_white(Image.open(src))
    width, height = keyed.size
    cell_w, cell_h = width // COLS, height // ROWS
    frames: list[Image.Image] = []
    frame_dir = DEST_DIR / frame_prefix
    frame_dir.mkdir(parents=True, exist_ok=True)
    index = 0
    for row in range(ROWS):
        for col in range(COLS):
            index += 1
            cell = keyed.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            frame = fit_frame(cell)
            frames.append(frame)
            outp = frame_dir / f"{frame_prefix}_{index:02d}.png"
            frame.save(outp)
            print(f"  {outp.name} bbox={opaque_bbox(frame)}")
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * FRAME_W, 0), frame)
    dest = DEST_DIR / strip_name
    strip.save(dest)
    print(f"wrote {dest} {strip.size} corner={strip.getpixel((0, 0))}")


if __name__ == "__main__":
    print("WALK")
    process(WALK_SRC, "slang_walk_cycle.png", "slang_walk")
    print("ATTACK")
    process(ATK_SRC, "slang_attack_swing.png", "slang_attack")
