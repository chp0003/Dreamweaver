"""Build 8-frame NPC walk strips from the original painted idle pixels.

Whole legs swing from the hips (not just the feet). Each side is a connected
limb, opposite phase. Writes npc_stride strips + frames.
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
CHARACTERS = ["chief", "fun", "queen"]
DIRS = ["down", "down_right", "right", "up_right", "up"]

# Hip socket. Below this the whole limb moves; torso stays painted.
JOINT_T = {
    "chief": 0.50,
    "fun": 0.54,
    "queen": 0.54,
}
FORWARD = {
    "right": (1.0, 0.0),
    "down_right": (0.78, 0.40),
    "down": (0.0, 1.0),
    "up_right": (0.78, -0.40),
    "up": (0.0, -1.0),
}
STRIDE = {
    "right": 15.0,
    "down_right": 12.0,
    "down": 9.0,
    "up_right": 12.0,
    "up": 9.0,
}
LIFT = {
    "chief": 5.0,
    "fun": 4.0,
    "queen": 4.0,
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
    dy = fy * stride * along * 0.22 - air * lift
    if fy > 0.0:
        dy = min(dy, 1.2)
    return dx, dy


def _hip_column(arr: np.ndarray, joint: int, x0: int, x1: int) -> tuple[float, int, int]:
    y1 = min(arr.shape[0], joint + 10)
    band = arr[joint:y1, x0:x1, 3] > 40
    ys, xs = np.where(band)
    if xs.size == 0:
        return 0.5 * (x0 + x1), x0, x1
    xs = xs + x0
    return float(np.median(xs)), int(xs.min()), int(xs.max()) + 1


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
    # Legs live under the hip. Staff / props outside this column stay still.
    pad = 6
    fx, fy = FORWARD[dir_name]
    stride = STRIDE[dir_name]
    lift = LIFT[sheet_id]
    t = float(frame_i) / float(total)
    ldx, ldy = _offset_for(t, fx, fy, stride, lift)
    rdx, rdy = _offset_for(t + 0.5, fx, fy, stride, lift)

    yy, xx = np.mgrid[0:h, 0:w]
    below = (yy >= joint) & (xx >= hx0 - pad) & (xx <= hx1 + pad)
    # Linear from hip → foot so thighs swing, not only the soles.
    fall = np.clip((yy.astype(np.float32) - joint) / max(1.0, y1 - 1 - joint), 0.0, 1.0)
    # Narrow crotch blend: 2px at the feet, a bit more at the hip (where motion is 0).
    blend = 2.0 + 6.0 * (1.0 - fall)
    u = np.clip((xx.astype(np.float32) - (mid - blend)) / np.maximum(2.0 * blend, 1.0), 0.0, 1.0)
    dx = (ldx * (1.0 - u) + rdx * u) * fall
    dy = (ldy * (1.0 - u) + rdy * u) * fall
    src_x = xx - dx
    src_y = yy - dy
    dest = arr.copy()
    valid = below & (src_x >= 0) & (src_x < w) & (src_y >= 0) & (src_y < h)
    sx = np.clip(np.rint(src_x).astype(np.int32), 0, w - 1)
    sy = np.clip(np.rint(src_y).astype(np.int32), 0, h - 1)
    dest[valid] = arr[sy[valid], sx[valid]]
    dest[below & ~valid] = 0
    return Image.fromarray(dest, "RGBA")


def build_dir(sheet_id: str, dir_name: str) -> None:
    src = SRC_DIR / f"{sheet_id}_{dir_name}.png"
    if not src.exists():
        print(f"skip missing {src.name}")
        return
    plant = slice_strip(src)[0]
    frames: list[Image.Image] = []
    for i in range(8):
        posed = step_legs(plant, sheet_id, dir_name, i)
        frames.append(posed)
        posed.save(FRAME_DIR / f"{sheet_id}_{dir_name}_{i + 1:02d}.png")
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * FRAME_W, 0), frame)
    out = OUT_DIR / f"{sheet_id}_{dir_name}.png"
    strip.save(out)
    print(f"wrote {out.relative_to(ROOT)}  {strip.size}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for sheet_id in CHARACTERS:
        for dir_name in DIRS:
            build_dir(sheet_id, dir_name)


if __name__ == "__main__":
    main()
