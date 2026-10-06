"""Build 8-frame NPC walk strips from the original painted idle pixels.

Whole legs swing from the hips. The crotch/skirt spine stays painted so no
seam line, and frames are settled so soles are not cropped. Writes npc_stride.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets/images/characters/npc_walk"
OUT_DIR = ROOT / "assets/images/characters/npc_stride"
FRAME_DIR = OUT_DIR / "frames"
FRAME_W, FRAME_H = 256, 192
FOOT_PAD = 12
SPINE = 5.0
CHARACTERS = ["chief", "fun", "queen"]
DIRS = ["down", "down_right", "right", "up_right", "up"]

JOINT_T = {
    "chief": 0.52,
    "fun": 0.70,
    "queen": 0.70,
}
FORWARD = {
    "right": (1.0, 0.0),
    "down_right": (0.78, 0.32),
    "down": (0.0, 1.0),
    "up_right": (0.78, -0.32),
    "up": (0.0, -1.0),
}
STRIDE = {
    "right": 10.0,
    "down_right": 9.0,
    "down": 7.0,
    "up_right": 9.0,
    "up": 7.0,
}
LIFT = {
    "chief": 3.0,
    "fun": 2.0,
    "queen": 2.0,
}


def opaque_bbox(arr: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(arr[:, :, 3] > 40)
    if xs.size == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def slice_strip(path: Path) -> list[Image.Image]:
    img = Image.open(path).convert("RGBA")
    count = max(1, img.width // FRAME_W) if img.width >= FRAME_W else 1
    if img.width % FRAME_W == 0:
        count = img.width // FRAME_W
    cell_w = img.width // count
    return [img.crop((i * cell_w, 0, (i + 1) * cell_w, img.height)) for i in range(count)]


def _offset_for(phase: float, fx: float, fy: float, stride: float, lift: float) -> tuple[float, float]:
    along = math.cos(phase * math.tau)
    air = max(0.0, -math.sin(phase * math.tau))
    dx = fx * stride * along
    # Lift only — never push soles off the canvas.
    dy = -air * lift
    if fy < 0.0:
        dy += fy * stride * along * 0.18
    dy = min(dy, 0.0)
    return dx, dy


def _hip_column(arr: np.ndarray, joint: int, x0: int, x1: int) -> tuple[float, int, int]:
    y1 = min(arr.shape[0], joint + 10)
    band = arr[joint:y1, x0:x1, 3] > 40
    ys, xs = np.where(band)
    if xs.size == 0:
        return 0.5 * (x0 + x1), x0, x1
    xs = xs + x0
    return float(np.median(xs)), int(xs.min()), int(xs.max()) + 1


def _drop_orphans(arr: np.ndarray, joint: int, min_size: int = 22) -> np.ndarray:
    """Wipe stray hem scraps and the 1px crotch stitch left by the split."""
    h, w = arr.shape[:2]
    seen = np.zeros((h, w), dtype=bool)
    alpha = arr[:, :, 3] > 40
    out = arr.copy()
    for y in range(joint, h):
        for x in range(w):
            if seen[y, x] or not alpha[y, x]:
                continue
            stack = [(x, y)]
            blob: list[tuple[int, int]] = []
            seen[y, x] = True
            while stack:
                cx, cy = stack.pop()
                blob.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < joint or nx >= w or ny >= h:
                        continue
                    if seen[ny, nx] or not alpha[ny, nx]:
                        continue
                    seen[ny, nx] = True
                    stack.append((nx, ny))
            attached = any(py <= joint + 1 for _px, py in blob)
            if (not attached) or 0 < len(blob) < min_size:
                for px, py in blob:
                    out[py, px] = 0
    return out


def settle_feet(img: Image.Image, pad: int = FOOT_PAD) -> Image.Image:
    arr = np.array(img, dtype=np.uint8)
    box = opaque_bbox(arr)
    if box is None:
        return img
    y1 = box[3]
    target = arr.shape[0] - pad
    shift = y1 - target
    if shift == 0:
        return img
    out = np.zeros_like(arr)
    if shift > 0 and shift < arr.shape[0]:
        out[:-shift] = arr[shift:]
    elif shift < 0 and -shift < arr.shape[0]:
        out[-shift:] = arr[:shift]
    return Image.fromarray(out, "RGBA")


def step_legs(src: Image.Image, sheet_id: str, dir_name: str, frame_i: int, total: int = 8) -> Image.Image:
    arr = np.array(src, dtype=np.uint8)
    box = opaque_bbox(arr)
    if box is None:
        return src
    x0, y0, x1, y1 = box
    h, w = arr.shape[:2]
    char_h = max(1, y1 - y0)
    joint = y0 + int(char_h * JOINT_T[sheet_id])
    mid, hx0, hx1 = _hip_column(arr, joint, x0, x1)
    pad = 6
    fx, fy = FORWARD[dir_name]
    stride = STRIDE[dir_name]
    lift = LIFT[sheet_id]
    t = float(frame_i) / float(total)
    ldx, ldy = _offset_for(t, fx, fy, stride, lift)
    rdx, rdy = _offset_for(t + 0.5, fx, fy, stride, lift)

    yy, xx = np.mgrid[0:h, 0:w]
    below = (yy >= joint) & (xx >= hx0 - pad) & (xx <= hx1 + pad)
    # Keep a painted spine so the crotch / skirt does not tear into a line.
    spine = np.abs(xx.astype(np.float32) - mid) < SPINE
    # Shin eases out from the hip. The shoe uses one offset for every row,
    # so the toe keeps the angle it was painted with instead of twisting.
    boot = joint + int((y1 - 1 - joint) * 0.58)
    span = max(1.0, float(boot - joint))
    fall = np.where(
        yy >= boot,
        1.0,
        np.clip((yy.astype(np.float32) - joint) / span, 0.0, 1.0),
    )
    is_left = xx < mid
    dx = np.where(is_left, ldx, rdx) * fall
    dy = np.where(is_left, ldy, rdy) * fall
    src_x = xx - dx
    src_y = yy - dy
    dest = arr.copy()
    valid = below & ~spine & (src_x >= 0) & (src_x < w) & (src_y >= 0) & (src_y < h)
    sx = np.clip(np.rint(src_x).astype(np.int32), 0, w - 1)
    sy = np.clip(np.rint(src_y).astype(np.int32), 0, h - 1)
    dest[valid] = arr[sy[valid], sx[valid]]
    dest = _drop_orphans(dest, joint)
    return settle_feet(Image.fromarray(dest, "RGBA"))


def build_dir(sheet_id: str, dir_name: str) -> None:
    src = SRC_DIR / f"{sheet_id}_{dir_name}.png"
    if not src.exists():
        print(f"skip missing {src.name}")
        return
    plant = settle_feet(slice_strip(src)[0])
    frames: list[Image.Image] = []
    for i in range(8):
        posed = step_legs(plant, sheet_id, dir_name, i)
        frames.append(posed)
        frame_path = FRAME_DIR / f"{sheet_id}_{dir_name}_{i + 1:02d}.png"
        try:
            posed.save(frame_path)
        except OSError:
            pass
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * FRAME_W, 0), frame)
    out = OUT_DIR / f"{sheet_id}_{dir_name}.png"
    tmp = out.with_name(out.stem + ".tmp.png")
    strip.save(tmp)
    for _attempt in range(6):
        try:
            tmp.replace(out)
            break
        except OSError:
            pass
    else:
        try:
            strip.save(out)
        except OSError:
            print(f"locked {out.name}, left {tmp.name}")
            return
        if tmp.exists():
            tmp.unlink()
    print(f"wrote {out.relative_to(ROOT)}  {strip.size}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for sheet_id in CHARACTERS:
        for dir_name in DIRS:
            build_dir(sheet_id, dir_name)


if __name__ == "__main__":
    main()
