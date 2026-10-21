"""Build NPC walk + idle strips from ONE painted character picture each.

Put the source pictures here (any size, transparent or flat magenta background):
    assets/images/characters/npc_source/chief.png
    assets/images/characters/npc_source/fun.png
    assets/images/characters/npc_source/queen.png

Run from anywhere:
    python tools/build_npc_walk_sheets.py

Writes (front-facing "down" view, which is the only view the pictures show):
    assets/images/characters/npc_cycle/<id>_down.png        8 walk frames
    assets/images/characters/npc_cycle/<id>_down_idle.png   4 idle frames
    tools/preview/<id>_down.png                             contact sheet to eyeball
and prints the STRIDE_OVERRIDE line to paste into npc_frames.gd.

How the walk is made: nothing is cut out and pasted back, so there are no holes.
The whole picture is bent by a smooth displacement field:
  * the feet/hem zone follows two "feet" (left, right) that step and lift in turn,
  * the body above rides a bob, a side-to-side weight shift and a lean,
  * the stretch between hips and feet is spread over a ramp, not a hard seam,
  * held props (the chief's staff) are masked out of the leg motion.
One cycle covers exactly 4 * FOOT_AMP px of ground, per character. That number is
the stride the game uses, so the planted foot does not skate.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets/images/characters/npc_source"
OUT_DIR = ROOT / "assets/images/characters/npc_cycle"
PREVIEW_DIR = ROOT / "tools/preview"

FRAME_W, FRAME_H = 256, 192
FOOT_PAD = 12  # sole line sits at y = FRAME_H - FOOT_PAD = 180
WORK_H = 330  # tall scratch canvas so nothing clips while we bend the picture
WORK_BASE = 250  # y of the resting sole line on the scratch canvas
WALK_FRAMES = 8
IDLE_FRAMES = 4

# Per character rig. All y/x numbers are fractions of the trimmed picture.
#   y0..y1  ramp where the body hands over to the feet (above y0: body, below y1: feet)
#   cx, bw  where the two feet split (x) and how wide the soft seam is
#   amp     foot travel front/back in canvas px. Stride = 4 * amp px per cycle.
#   lift    how high the stepping foot rises
#   bob     body rise at the passing pose
#   sway    side-to-side weight shift of the upper body
#   lean    constant shove of the upper body so he leans into the walk (x px)
#   arm     hand swing for a free arm (None = both arms are carrying something)
#   keep_x  pixels right of this fraction ignore the legs (held staff)
RIGS = {
    "chief": dict(height=158, y0=0.56, y1=0.875, cx=0.355, bw=0.075, amp=14.0,
                  lift=8.0, bob=4.0, sway=2.6, arm=dict(x=(0.0, 0.24), y=(0.36, 0.67), swing=5.0),
                  keep_x=(0.64, 0.70), clean=None),
    "queen": dict(height=158, y0=0.58, y1=0.925, cx=0.655, bw=0.13, amp=12.0,
                lift=6.0, bob=3.2, sway=2.2, arm=None, keep_x=None, clean=None),
    "fun": dict(height=158, y0=0.56, y1=0.90, cx=0.485, bw=0.15, amp=12.0,
                  lift=6.0, bob=3.2, sway=2.2, arm=None, keep_x=None,
                  # her picture has a dirt oval painted under the feet and a white matte halo
                  clean=dict(shadow=(105, 90, 62), shadow_tol=34.0, shadow_from=0.82, white_matte=True)),
}


# ----------------------------------------------------------------------------- loading


def key_out_flat_background(rgb: np.ndarray) -> np.ndarray:
    """RGB picture on a flat colour -> RGBA with no coloured halo.

    Alpha comes from the distance to the background colour. Edge pixels then take
    the colour of the nearest solid pixel, so no background tint is left behind.
    """
    a = rgb.astype(np.float32)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    d = np.linalg.norm(a - bg, axis=2)
    alpha = np.clip((d - 40.0) / (95.0 - 40.0), 0.0, 1.0)
    lab, n = ndi.label(alpha > 0.5)
    if n:
        sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes > 400
        alpha[~keep[lab]] = 0.0
    solid = ndi.binary_erosion(alpha > 0.97, iterations=1)
    _dist, idx = ndi.distance_transform_edt(~solid, return_indices=True)
    out = a[idx[0], idx[1]]
    rgba = np.dstack([out, alpha * 255.0]).astype(np.uint8)
    return rgba


def clean_source(rgba: np.ndarray, clean: dict | None) -> np.ndarray:
    """Remove things painted into a picture that must not walk: ground shadow, white matte, specks."""
    a = rgba.copy()
    if clean:
        h, w = a.shape[:2]
        if clean.get("shadow"):
            col = np.array(clean["shadow"], np.float32)
            dist = np.linalg.norm(a[:, :, :3].astype(np.float32) - col, axis=2)
            rows = np.broadcast_to((np.arange(h) >= int(h * clean["shadow_from"]))[:, None], (h, w))
            a[(dist < clean["shadow_tol"]) & rows, 3] = 0
            a[(a[:, :, 3] < 235) & rows, 3] = 0
        if clean.get("white_matte"):
            rgb = a[:, :, :3].astype(np.int32)
            pale = (rgb.min(axis=2) > 165) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 45) & (a[:, :, 3] >= 30)
            outside = a[:, :, 3] < 30
            reach = ndi.binary_propagation(outside, mask=outside | pale)
            a[reach & pale, 3] = 0
            # matte specks sealed inside the outline (the white wedge behind the ear)
            strict = (rgb.min(axis=2) > 195) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 40)
            head_rows = np.broadcast_to((np.arange(h) < int(h * 0.35))[:, None], (h, w))
            a[strict & head_rows, 3] = 0
        lab, n = ndi.label(a[:, :, 3] > 30)
        if n:
            sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
            keep = np.zeros(n + 1, bool)
            keep[1:] = sizes > 200
            a[~keep[lab], 3] = 0
    return a


def load_character(sheet_id: str) -> Image.Image:
    path = SRC_DIR / f"{sheet_id}.png"
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    border_alpha = np.concatenate([arr[0, :, 3], arr[-1, :, 3], arr[:, 0, 3], arr[:, -1, 3]])
    if np.median(border_alpha) < 128:
        rgba = arr  # already cut out
    else:
        rgba = key_out_flat_background(arr[:, :, :3])  # flat background colour
    rgba = clean_source(rgba, RIGS[sheet_id]["clean"])
    ys, xs = np.where(rgba[:, :, 3] > 40)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return Image.fromarray(rgba).crop(box)


def fit_to_height(img: Image.Image, height: int) -> Image.Image:
    scale = height / img.height
    w = max(1, int(round(img.width * scale)))
    # premultiplied resize so transparent edges do not get a dark halo
    arr = np.array(img, dtype=np.float32)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    pm = Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, height), Image.LANCZOS)
    p = np.array(pm, dtype=np.float32)
    a = p[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        p[..., :3] = np.where(a > 0.5, p[..., :3] / (a / 255.0), 0.0)
    return Image.fromarray(np.clip(p, 0, 255).astype(np.uint8), "RGBA")


def feet_anchor_x(arr: np.ndarray) -> float:
    ys, xs = np.where(arr[:, :, 3] > 25)
    bottom = ys.max()
    band = max(4, int((bottom - ys.min()) * 0.06))
    sel = ys > bottom - band
    return float(np.median(xs[sel]))


def place_on_scratch(img: Image.Image) -> np.ndarray:
    canvas = np.zeros((WORK_H, FRAME_W, 4), np.uint8)
    arr = np.array(img)
    ax = feet_anchor_x(arr)
    x0 = int(round(FRAME_W * 0.5 - ax))
    y0 = WORK_BASE - arr.shape[0]
    h, w = arr.shape[:2]
    sx0, sy0 = max(0, -x0), 0
    dx0 = max(0, x0)
    cw = min(w - sx0, FRAME_W - dx0)
    canvas[y0 : y0 + h, dx0 : dx0 + cw] = arr[sy0:h, sx0 : sx0 + cw]
    return canvas


# ----------------------------------------------------------------------------- warping


def smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def remap(arr: np.ndarray, src_x: np.ndarray, src_y: np.ndarray) -> np.ndarray:
    h, w = arr.shape[:2]
    x0 = np.clip(np.floor(src_x).astype(int), 0, w - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    y0 = np.clip(np.floor(src_y).astype(int), 0, h - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fx = (src_x - np.floor(src_x))[..., None]
    fy = (src_y - np.floor(src_y))[..., None]
    a = arr.astype(np.float32)
    a[..., :3] *= a[..., 3:4] / 255.0
    top = a[y0, x0] * (1 - fx) + a[y0, x1] * fx
    bot = a[y1, x0] * (1 - fx) + a[y1, x1] * fx
    out = top * (1 - fy) + bot * fy
    al = out[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        out[..., :3] = np.where(al > 1e-3, out[..., :3] / (al / 255.0), 0)
    # inside-the-picture samples only, so edges do not smear from the clamped border
    inside = (src_x >= 0) & (src_x <= w - 1) & (src_y >= 0) & (src_y <= h - 1)
    out[~inside] = 0
    return np.clip(out, 0, 255).astype(np.uint8)


def foot_curve(phase: float) -> tuple[float, float]:
    """(along -1..1, lift 0..1). Stance is linear so the planted foot keeps a constant ground speed."""
    p = phase % 1.0
    if p < 0.5:
        return 1.0 - 4.0 * p, 0.0
    u = (p - 0.5) * 2.0
    return -math.cos(u * math.pi), math.sin(u * math.pi)


class Rig:
    def __init__(self, sheet_id: str, scratch: np.ndarray):
        self.id = sheet_id
        self.cfg = RIGS[sheet_id]
        ys, xs = np.where(scratch[:, :, 3] > 25)
        self.top = float(ys.min())
        self.bottom = float(ys.max()) + 1.0
        self.left = float(xs.min())
        self.right = float(xs.max()) + 1.0
        self.h = self.bottom - self.top
        self.w = self.right - self.left
        yy, xx = np.mgrid[0:scratch.shape[0], 0:scratch.shape[1]].astype(np.float32)
        c = self.cfg
        y0 = self.top + c["y0"] * self.h
        y1 = self.top + c["y1"] * self.h
        self.w_feet = smoothstep((yy - y0) / (y1 - y0))
        cx = self.left + c["cx"] * self.w
        bw = c["bw"] * self.w
        self.side_left = 1.0 - smoothstep((xx - (cx - bw)) / (2.0 * bw))
        keep = np.ones_like(xx)
        if c["keep_x"] is not None:
            a, b = c["keep_x"]
            keep = 1.0 - smoothstep((xx - (self.left + a * self.w)) / ((b - a) * self.w))
        self.w_leg = self.w_feet * keep
        # 0 at the hips, 1 at the head: the upper body leans more than the waist
        self.height_w = np.clip((y0 - yy) / max(y0 - self.top, 1.0), 0.0, 1.0)
        self.xx, self.yy = xx, yy
        self.arm_w = None
        if c["arm"] is not None:
            ar = c["arm"]
            ax0, ax1 = self.left + ar["x"][0] * self.w, self.left + ar["x"][1] * self.w
            ay0 = self.top + ar["y"][0] * self.h
            ay1 = self.top + ar["y"][1] * self.h
            fade = 1.0 - smoothstep((xx - ax0) / max(ax1 - ax0, 1.0))
            drop = smoothstep((yy - ay0) / (ay1 - ay0))
            lowcut = 1.0 - smoothstep((yy - ay1) / (0.10 * self.h))
            self.arm_w = fade * drop * lowcut * (1.0 - self.w_leg)

    def displacement(self, phase: float, walking: bool, idle_breath: float = 0.0):
        c = self.cfg
        if walking:
            along_l, lift_l = foot_curve(phase)
            along_r, lift_r = foot_curve(phase + 0.5)
            foot_l = c["amp"] * along_l - c["lift"] * lift_l
            foot_r = c["amp"] * along_r - c["lift"] * lift_r
            bob = -c["bob"] * 0.5 * (1.0 - math.cos(4.0 * math.pi * phase))
            sway = -c["sway"] * math.sin(2.0 * math.pi * phase)
            lean = c.get("lean", 0.0)
        else:
            foot_l = foot_r = 0.0
            bob = -idle_breath
            sway = 0.0
            lean = 0.0
        feet_dy = self.side_left * foot_l + (1.0 - self.side_left) * foot_r
        body_w = 1.0 - self.w_leg
        dy = self.w_leg * feet_dy + body_w * bob
        torso = body_w * (0.30 + 0.70 * self.height_w)
        dx = torso * (sway + lean)
        if walking and self.arm_w is not None:
            dy = dy + self.arm_w * (-c["arm"]["swing"] * math.cos(2.0 * math.pi * phase))
        return dx, dy

    def render(self, scratch: np.ndarray, phase: float, walking: bool, idle_breath: float = 0.0) -> np.ndarray:
        dx, dy = self.displacement(phase, walking, idle_breath)
        return remap(scratch, self.xx - dx, self.yy - dy)


# ----------------------------------------------------------------------------- output


def settle(frames: list[np.ndarray]) -> list[np.ndarray]:
    """One shift for every frame: lowest sole of the whole set -> y = FRAME_H - FOOT_PAD."""
    low = 0
    for f in frames:
        ys, _ = np.where(f[:, :, 3] > 25)
        low = max(low, int(ys.max()) + 1)
    shift = low - (FRAME_H - FOOT_PAD)
    out = []
    for f in frames:
        g = np.zeros((FRAME_H, FRAME_W, 4), np.uint8)
        # row r on the output comes from row r + shift on the scratch canvas
        for r in range(FRAME_H):
            s = r + shift
            if 0 <= s < f.shape[0]:
                g[r] = f[s]
        out.append(g)
    tops = [int(np.where(g[:, :, 3] > 25)[0].min()) for g in out]
    if min(tops) < 1:
        print(f"  WARNING: head touches the top edge ({min(tops)}). Lower RIGS height or amp.")
    return out


def save_strip(frames: list[np.ndarray], path: Path) -> None:
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, arr in enumerate(frames):
        strip.paste(Image.fromarray(arr, "RGBA"), (i * FRAME_W, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(path)


def save_contact(sheet_id: str, walk: list[np.ndarray], idle: list[np.ndarray]) -> None:
    cells = walk + idle
    bg = Image.new("RGBA", (FRAME_W * len(cells), FRAME_H), (58, 66, 54, 255))
    for i, arr in enumerate(cells):
        bg.alpha_composite(Image.fromarray(arr, "RGBA"), (i * FRAME_W, 0))
    draw = ImageDraw.Draw(bg)
    draw.line([(0, FRAME_H - FOOT_PAD), (bg.width - 1, FRAME_H - FOOT_PAD)], fill=(255, 60, 60, 255), width=1)
    for i in range(len(cells)):
        x = i * FRAME_W + FRAME_W // 2
        draw.line([(x, 0), (x, FRAME_H - 1)], fill=(60, 230, 100, 160), width=1)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    bg.save(PREVIEW_DIR / f"{sheet_id}_down.png")


def build(sheet_id: str) -> float:
    cfg = RIGS[sheet_id]
    picture = fit_to_height(load_character(sheet_id), cfg["height"])
    scratch = place_on_scratch(picture)
    rig = Rig(sheet_id, scratch)
    walk = [rig.render(scratch, i / WALK_FRAMES, True) for i in range(WALK_FRAMES)]
    breath = [0.0, 0.8, 1.6, 0.8]
    idle = [rig.render(scratch, 0.0, False, breath[i]) for i in range(IDLE_FRAMES)]
    settled = settle(walk + idle)
    walk, idle = settled[:WALK_FRAMES], settled[WALK_FRAMES:]
    save_strip(walk, OUT_DIR / f"{sheet_id}_down.png")
    save_strip(idle, OUT_DIR / f"{sheet_id}_down_idle.png")
    save_contact(sheet_id, walk, idle)
    print(f"wrote {sheet_id}_down walk x{WALK_FRAMES} + idle x{IDLE_FRAMES}", flush=True)
    return 4.0 * cfg["amp"]


def merge_strides(new: dict[str, float]) -> str:
    """Remember every stride in tools/npc_strides.json and return the full line for npc_frames.gd."""
    path = ROOT / "tools/npc_strides.json"
    cur = json.loads(path.read_text()) if path.exists() else {}
    cur.update(new)
    path.write_text(json.dumps(cur, indent=2, sort_keys=True))
    items = ", ".join(f'"{k}": {v:.1f}' for k, v in sorted(cur.items()))
    return "const STRIDE_OVERRIDE := {" + items + "}"


def main() -> None:
    strides: dict[str, float] = {}
    for sheet_id in RIGS:
        if not (SRC_DIR / f"{sheet_id}.png").exists():
            print(f"skip {sheet_id}: {SRC_DIR / (sheet_id + '.png')} not found")
            continue
        strides[f"{sheet_id}_down"] = build(sheet_id)
    print("\nPaste into npc_frames.gd (replaces the old STRIDE_OVERRIDE line):\n" + merge_strides(strides))


if __name__ == "__main__":
    main()
