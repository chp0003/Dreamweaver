"""Turn generated / hand drawn walk pictures into the strips the game loads.

Drop the pictures in:  assets/images/characters/npc_generated/
Name them:             <id>_<dir>_walk.png   and   <id>_<dir>_idle.png
  <id>   chief, fun, queen (any lowercase name)
  <dir>  down, down_right, right, up_right, up      (the 5 drawn directions)
         left, up_left and down_left are mirrored by the game, do not draw them.
Each picture is ONE row of frames (or two rows) on a flat colour or transparent
background. Walk: 8 frames is ideal (6 to 10 works). Idle: 4 frames (2 to 6 works).
The idle picture is optional; without it one is made from the walk.

Run:    python tools/import_generated_walks.py
Writes: assets/images/characters/npc_cycle/<id>_<dir>.png        (8 walk frames)
        assets/images/characters/npc_cycle/<id>_<dir>_idle.png   (4 idle frames)
        tools/preview/gen_<id>_<dir>.png                         (check these by eye)
and prints the STRIDE_OVERRIDE line for npc_frames.gd.

If feet skate: the stride is wrong. Change STRIDE_SRC_PX below for that character
(bigger = slower feet, smaller = faster feet) and run again.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets/images/characters/npc_generated"
OUT_DIR = ROOT / "assets/images/characters/npc_cycle"
PREVIEW_DIR = ROOT / "tools/preview"

FRAME_W, FRAME_H = 256, 192
FOOT_PAD = 12
TARGET_H = 158  # height of the figure on the 192 px canvas
WALK_FRAMES = 8
IDLE_FRAMES = 4

# Source px of ground covered by one full walk cycle (two steps). Keys: "<id>_<dir>",
# then "<id>", then "default". A person is about 0.8 to 1.0 of their own height per cycle.
STRIDE_SRC_PX = {"default": 110.0}

NAME_RE = re.compile(r"^(?P<id>[a-z0-9]+)_(?P<dir>down_right|up_right|down|right|up)_(?P<kind>walk|idle)\.png$")


# ----------------------------------------------------------------------------- keying


def key_out_flat_background(rgb: np.ndarray) -> np.ndarray:
    """RGB on a flat colour -> RGBA with no coloured halo (edges take the nearest solid colour)."""
    a = rgb.astype(np.float32)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    d = np.linalg.norm(a - bg, axis=2)
    alpha = np.clip((d - 40.0) / (95.0 - 40.0), 0.0, 1.0)
    lab, n = ndi.label(alpha > 0.5)
    if n:
        sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes > 120
        alpha[~keep[lab]] = 0.0
    solid = ndi.binary_erosion(alpha > 0.97, iterations=1)
    _dist, idx = ndi.distance_transform_edt(~solid, return_indices=True)
    out = a[idx[0], idx[1]]
    return np.dstack([out, alpha * 255.0]).astype(np.uint8)


def load_rgba(path: Path) -> np.ndarray:
    arr = np.array(Image.open(path).convert("RGBA"))
    border = np.concatenate([arr[0, :, 3], arr[-1, :, 3], arr[:, 0, 3], arr[:, -1, 3]])
    if np.median(border) < 128:
        return arr
    return key_out_flat_background(arr[:, :, :3])


# ----------------------------------------------------------------------------- splitting


def runs(occupied: np.ndarray) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    start = None
    for i, v in enumerate(occupied.tolist()):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(occupied)))
    return out


def merge_to_count(spans: list[tuple[int, int]], count: int) -> list[tuple[int, int]]:
    spans = list(spans)
    while len(spans) > count:
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        k = int(np.argmin(gaps))
        spans[k : k + 2] = [(spans[k][0], spans[k + 1][1])]
    return spans


def split_row(band: np.ndarray, count: int) -> list[np.ndarray]:
    """Cut one row of frames into `count` pieces. Uses the gaps between figures if they
    are there, otherwise cuts the occupied width into equal pieces."""
    occ = (band[:, :, 3] > 25).any(axis=0)
    spans = merge_to_count(runs(occ), count)
    if len(spans) < 2:
        xs = np.where(occ)[0]
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        edges = np.linspace(x0, x1, count + 1).round().astype(int)
        spans = [(int(edges[i]), int(edges[i + 1])) for i in range(count)]
        print(f"    frames touch, cut {count} equal pieces", flush=True)
    return [band[:, a:b] for a, b in spans]


def split_frames(rgba: np.ndarray, count: int) -> list[np.ndarray]:
    mask = rgba[:, :, 3] > 25
    row_spans = runs(mask.any(axis=1))
    if row_spans:
        tallest = max(b - a for a, b in row_spans)
        row_spans = [(a, b) for a, b in row_spans if (b - a) >= tallest * 0.25]
    if len(row_spans) <= 1:
        return split_row(rgba, count)
    per_row = [count // len(row_spans)] * len(row_spans)
    for i in range(count - sum(per_row)):
        per_row[i] += 1
    frames: list[np.ndarray] = []
    for (a, b), n in zip(row_spans, per_row):
        frames += split_row(rgba[a:b], n)
    return frames


def resample_count(frames: list[np.ndarray], count: int) -> list[np.ndarray]:
    n = len(frames)
    if n == count:
        return frames
    return [frames[min(n - 1, int(i * n / count))] for i in range(count)]


# ----------------------------------------------------------------------------- placing


def trim(arr: np.ndarray) -> np.ndarray:
    ys, xs = np.where(arr[:, :, 3] > 25)
    return arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def resize_premult(arr: np.ndarray, scale: float) -> np.ndarray:
    h, w = arr.shape[:2]
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    f = arr.astype(np.float32)
    f[..., :3] *= f[..., 3:4] / 255.0
    img = Image.fromarray(np.clip(f, 0, 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.LANCZOS)
    p = np.array(img, dtype=np.float32)
    al = p[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        p[..., :3] = np.where(al > 0.5, p[..., :3] / (al / 255.0), 0.0)
    return np.clip(p, 0, 255).astype(np.uint8)


def torso_center_x(arr: np.ndarray) -> float:
    """Centre of the upper 70 % of the figure, so moving legs do not drag the body sideways."""
    h = arr.shape[0]
    ys, xs = np.where(arr[: int(h * 0.7), :, 3] > 25)
    return float(xs.mean()) if xs.size else arr.shape[1] / 2.0


def place(arr: np.ndarray) -> np.ndarray:
    canvas = np.zeros((FRAME_H, FRAME_W, 4), np.uint8)
    h, w = arr.shape[:2]
    x0 = int(round(FRAME_W / 2 - torso_center_x(arr)))
    y0 = (FRAME_H - FOOT_PAD) - h
    if y0 < 0:
        arr = arr[-y0:]
        h = arr.shape[0]
        y0 = 0
    sx0 = max(0, -x0)
    dx0 = max(0, x0)
    cw = min(w - sx0, FRAME_W - dx0)
    if cw < w:
        print("    WARNING: a frame is wider than the 256 px cell and was clipped", flush=True)
    canvas[y0 : y0 + h, dx0 : dx0 + cw] = arr[:, sx0 : sx0 + cw]
    return canvas


def normalise(frames: list[np.ndarray]) -> list[np.ndarray]:
    """One scale for the whole set (from the median figure height), feet on one line."""
    trimmed = [trim(f) for f in frames]
    median_h = float(np.median([t.shape[0] for t in trimmed]))
    scale = TARGET_H / median_h
    return [place(resize_premult(t, scale)) for t in trimmed]


def breath(base: np.ndarray, lift: float) -> np.ndarray:
    """Idle breathing: the upper body rises by `lift` px, the feet stay."""
    ys, _ = np.where(base[:, :, 3] > 25)
    top, bottom = float(ys.min()), float(ys.max()) + 1.0
    yy, xx = np.mgrid[0 : base.shape[0], 0 : base.shape[1]].astype(np.float32)
    t = np.clip((bottom - yy) / max(bottom - top, 1.0), 0.0, 1.0)
    w = t * t * (3.0 - 2.0 * t)
    src_y = np.clip(yy + lift * w, 0, base.shape[0] - 1)
    return base[src_y.round().astype(int), xx.astype(int)]


def idle_from_walk(walk: list[np.ndarray]) -> list[np.ndarray]:
    """Pick the walk frame with the feet closest together, then make it breathe."""

    def feet_width(f: np.ndarray) -> int:
        ys, xs = np.where(f[:, :, 3] > 25)
        low = ys.max()
        sel = ys > low - 14
        return int(xs[sel].max() - xs[sel].min()) if sel.any() else 9999

    base = min(walk, key=feet_width)
    return [breath(base, lift) for lift in (0.0, 0.8, 1.6, 0.8)]


# ----------------------------------------------------------------------------- output


def save_strip(frames: list[np.ndarray], path: Path) -> None:
    strip = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), (0, 0, 0, 0))
    for i, arr in enumerate(frames):
        strip.paste(Image.fromarray(arr, "RGBA"), (i * FRAME_W, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(path)


def save_contact(sheet_id: str, dir_name: str, walk: list[np.ndarray], idle: list[np.ndarray]) -> None:
    cells = walk + idle
    bg = Image.new("RGBA", (FRAME_W * len(cells), FRAME_H), (58, 66, 54, 255))
    for i, arr in enumerate(cells):
        bg.alpha_composite(Image.fromarray(arr, "RGBA"), (i * FRAME_W, 0))
    draw = ImageDraw.Draw(bg)
    draw.line([(0, FRAME_H - FOOT_PAD), (bg.width - 1, FRAME_H - FOOT_PAD)], fill=(255, 60, 60, 255))
    for i in range(len(cells)):
        draw.line([(i * FRAME_W + 128, 0), (i * FRAME_W + 128, FRAME_H - 1)], fill=(60, 230, 100, 150))
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    bg.save(PREVIEW_DIR / f"gen_{sheet_id}_{dir_name}.png")


def stride_for(sheet_id: str, dir_name: str) -> float:
    for key in (f"{sheet_id}_{dir_name}", sheet_id, "default"):
        if key in STRIDE_SRC_PX:
            return float(STRIDE_SRC_PX[key])
    return 110.0


def merge_strides(new: dict[str, float]) -> str:
    path = ROOT / "tools/npc_strides.json"
    cur = json.loads(path.read_text()) if path.exists() else {}
    cur.update(new)
    path.write_text(json.dumps(cur, indent=2, sort_keys=True))
    items = ", ".join(f'"{k}": {v:.1f}' for k, v in sorted(cur.items()))
    return "const STRIDE_OVERRIDE := {" + items + "}"


def main() -> None:
    if not SRC_DIR.exists():
        print(f"Make the folder {SRC_DIR} and put <id>_<dir>_walk.png files in it.")
        return
    jobs: dict[tuple[str, str], dict[str, Path]] = {}
    for path in sorted(SRC_DIR.glob("*.png")):
        m = NAME_RE.match(path.name)
        if not m:
            print(f"skip {path.name}: name must look like chief_down_right_walk.png")
            continue
        jobs.setdefault((m["id"], m["dir"]), {})[m["kind"]] = path
    strides: dict[str, float] = {}
    for (sheet_id, dir_name), files in sorted(jobs.items()):
        if "walk" not in files:
            print(f"skip {sheet_id}_{dir_name}: no walk picture")
            continue
        print(f"{sheet_id}_{dir_name}", flush=True)
        walk_raw = split_frames(load_rgba(files["walk"]), WALK_FRAMES)
        print(f"  walk: {len(walk_raw)} frames", flush=True)
        walk = normalise(resample_count(walk_raw, WALK_FRAMES))
        if "idle" in files:
            idle_raw = split_frames(load_rgba(files["idle"]), IDLE_FRAMES)
            print(f"  idle: {len(idle_raw)} frames", flush=True)
            idle = normalise(resample_count(idle_raw, IDLE_FRAMES))
        else:
            print("  idle: none supplied, made from the walk", flush=True)
            idle = idle_from_walk(walk)
        save_strip(walk, OUT_DIR / f"{sheet_id}_{dir_name}.png")
        save_strip(idle, OUT_DIR / f"{sheet_id}_{dir_name}_idle.png")
        save_contact(sheet_id, dir_name, walk, idle)
        strides[f"{sheet_id}_{dir_name}"] = stride_for(sheet_id, dir_name)
    if strides:
        print("\nPaste into npc_frames.gd (replaces the old STRIDE_OVERRIDE line):")
        print(merge_strides(strides))
    have: dict[str, set[str]] = {}
    for key in list(strides) + [p.stem for p in OUT_DIR.glob("*_*.png") if not p.stem.endswith("_idle")]:
        m = re.match(r"^(?P<id>[a-z0-9]+)_(?P<dir>down_right|up_right|down|right|up)$", key)
        if m:
            have.setdefault(m["id"], set()).add(m["dir"])
    for sheet_id, dirs in sorted(have.items()):
        missing = [d for d in ("down", "down_right", "right", "up_right", "up") if d not in dirs]
        print(f"{sheet_id}: " + ("all 8 directions covered" if not missing else "still missing " + ", ".join(missing)))


if __name__ == "__main__":
    main()
