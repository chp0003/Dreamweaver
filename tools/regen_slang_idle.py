"""Rebuild S'lang idle frames from the source sheets.

The old cut left a dark pink edge because those pixels are far from the
bright plate, so a distance key kept them. This peels that edge.

Previous idles stay in slang_8dir/_backup_before_regen/.
Walk and attack sheets are not touched.
"""
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/images/characters/slang_8dir_src"
OUT = ROOT / "assets/images/characters/slang_8dir"
BACKUP = OUT / "_backup_before_regen"
FACES = ("down", "down_right", "right", "up_right", "up")
FRAME_W, FRAME_H = 256, 192


def is_fringe(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # Plate mix. Dress red stays out because its blue stays near green.
    magenta = (g < 90) & (r > g + 25) & (b > g + 8) & (r > 50) & (b > 20)
    hot = (r > 160) & (g < 70) & (b > 30) & (r > g + 60)
    return (alpha > 0) & (magenta | hot)


def dilate(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:] |= mask[:-1]
    out[:-1] |= mask[1:]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def key_plate(src: Image.Image) -> np.ndarray:
    arr = np.array(src.convert("RGBA"))
    rgb = arr[:, :, :3].astype(np.float32)
    h = rgb.shape[0]
    edge = np.concatenate([rgb[:, :4, :], rgb[:, -4:, :]], axis=1)
    local = np.median(edge, axis=1).astype(np.float32)
    dist = np.abs(rgb - local[:, None, :]).sum(axis=2) / 3.0
    alpha = np.clip((dist - 14.0) / 28.0, 0.0, 1.0)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # Flat studio color, pink or pale, including pockets inside the pose.
    flat = (np.abs(rgb - local[:, None, :]).sum(axis=2) < 36) & (g > 80)
    hot = (r > 170) & (b > 70) & (g < 100) & (r > g + 40)
    alpha[flat | hot] = 0.0
    fg = np.zeros_like(rgb)
    soft = (alpha > 0.05) & (alpha < 0.9)
    inv = (1.0 - alpha)[:, :, None]
    recovered = (rgb - local[:, None, :] * inv) / np.maximum(alpha, 0.05)[:, :, None]
    fg[soft] = np.clip(recovered[soft], 0, 255)
    hard = alpha >= 0.9
    fg[hard] = rgb[hard]
    out = np.zeros_like(arr)
    out[:, :, :3] = np.clip(fg, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return out


def peel_fringe(arr: np.ndarray) -> np.ndarray:
    arr = arr.copy()
    h, w = arr.shape[:2]
    for _ in range(6):
        rgb = arr[:, :, :3].astype(np.int16)
        alpha = arr[:, :, 3]
        fringe = is_fringe(rgb, alpha)
        if not fringe.any():
            break
        clear = alpha < 40
        hit = fringe & dilate(dilate(clear))
        if not hit.any():
            break
        replaced = np.zeros(hit.shape, dtype=bool)
        for rad in range(1, 6):
            need = hit & ~replaced
            if not need.any():
                break
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    if max(abs(dy), abs(dx)) != rad:
                        continue
                    ys = slice(max(0, dy), h + min(0, dy))
                    yt = slice(max(0, -dy), h + min(0, -dy))
                    xs = slice(max(0, dx), w + min(0, dx))
                    xt = slice(max(0, -dx), w + min(0, -dx))
                    good = (alpha[ys, xs] > 180) & ~fringe[ys, xs]
                    take = np.zeros(hit.shape, dtype=bool)
                    take[yt, xt] = need[yt, xt] & good
                    if not take.any():
                        continue
                    color = np.zeros_like(arr)
                    color[yt, xt] = arr[ys, xs]
                    arr[take, :3] = color[take, :3]
                    replaced |= take
        leftover = hit & ~replaced & (alpha < 210)
        arr[leftover] = (0, 0, 0, 0)
    return arr


def content_spans(mask_1d: np.ndarray, min_len: int) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    start = None
    for i, on in enumerate(mask_1d):
        if on and start is None:
            start = i
        elif not on and start is not None:
            if i - start >= min_len:
                spans.append((start, i))
            start = None
    if start is not None and len(mask_1d) - start >= min_len:
        spans.append((start, len(mask_1d)))
    return spans


def first_cell(sheet: np.ndarray) -> np.ndarray:
    opaque = sheet[:, :, 3] > 24
    # A staff pixel bridges the gutter, so require a real gap, not a zero row.
    row_gap = opaque.mean(axis=1) < 0.03
    rows = content_spans(~row_gap, 80)
    if not rows:
        return sheet
    y0, y1 = rows[0]
    col_gap = opaque[y0:y1].mean(axis=0) < 0.04
    cols = content_spans(~col_gap, 40)
    if not cols:
        return sheet[y0:y1]
    x0, x1 = cols[0]
    pad = 2
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(sheet.shape[0], y1 + pad), min(sheet.shape[1], x1 + pad)
    return sheet[y0:y1, x0:x1]


def opaque_box(arr: np.ndarray, thresh: int = 24):
    ys, xs = np.where(arr[:, :, 3] > thresh)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def drop_specks(arr: np.ndarray, min_area: int = 40) -> np.ndarray:
    alpha = arr[:, :, 3]
    seen = np.zeros(alpha.shape, dtype=bool)
    h, w = alpha.shape
    kill = np.zeros(alpha.shape, dtype=bool)
    for y in range(h):
        xs = np.where((alpha[y] > 20) & ~seen[y])[0]
        for x in xs:
            if seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            pixels: list[tuple[int, int]] = []
            while stack:
                cy, cx = stack.pop()
                pixels.append((cy, cx))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if ny < 0 or nx < 0 or ny >= h or nx >= w:
                        continue
                    if seen[ny, nx] or alpha[ny, nx] <= 20:
                        continue
                    seen[ny, nx] = True
                    stack.append((ny, nx))
            if len(pixels) < min_area:
                for py, px in pixels:
                    kill[py, px] = True
    arr = arr.copy()
    arr[kill] = (0, 0, 0, 0)
    return arr


def scrub_plate(arr: np.ndarray) -> np.ndarray:
    arr = arr.copy()
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    hot = (a > 0) & (r > 170) & (b > 90) & (g < 100)
    pale = (a > 0) & (a < 200) & (r > 170) & (g > 165) & (b > 165)
    rows = np.arange(arr.shape[0])[:, None]
    cool = (a > 0) & (b > 145) & (b > r + 8) & (g + 5 > r) & ((a < 220) | (rows >= arr.shape[0] - 24))
    arr[hot | pale | cool] = (0, 0, 0, 0)
    return arr


def bleed_clear(arr: np.ndarray) -> np.ndarray:
    arr = arr.copy()
    h, w = arr.shape[:2]
    src = arr.copy()
    solid = src[:, :, 3] > 160
    filled = np.zeros(solid.shape, dtype=bool)
    for rad in range(1, 3):
        target = (arr[:, :, 3] == 0) & ~filled
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                if max(abs(dy), abs(dx)) != rad:
                    continue
                shifted = np.zeros_like(solid)
                color = np.zeros_like(src)
                y0s, y0d = max(0, dy), max(0, -dy)
                x0s, x0d = max(0, dx), max(0, -dx)
                hh = h - max(0, dy) - max(0, -dy)
                ww = w - max(0, dx) - max(0, -dx)
                shifted[y0d : y0d + hh, x0d : x0d + ww] = solid[y0s : y0s + hh, x0s : x0s + ww]
                color[y0d : y0d + hh, x0d : x0d + ww] = src[y0s : y0s + hh, x0s : x0s + ww]
                take = target & shifted
                arr[take, :3] = color[take, :3]
                filled |= take
    return arr


def fit_like(arr: np.ndarray, target_h: int, target_bottom: int) -> np.ndarray:
    box = opaque_box(arr)
    canvas = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
    if box is None:
        return canvas
    x0, y0, x1, y1 = box
    crop = arr[y0:y1, x0:x1]
    ch = max(1, y1 - y0)
    scale = target_h / float(ch)
    tw = max(1, int(round(crop.shape[1] * scale)))
    th = max(1, int(round(ch * scale)))
    if tw > FRAME_W - 4:
        scale *= (FRAME_W - 4) / float(tw)
        tw = max(1, int(round(crop.shape[1] * scale)))
        th = max(1, int(round(ch * scale)))
    premul = crop.astype(np.float32)
    premul[:, :, :3] *= (premul[:, :, 3:4] / 255.0)
    scaled = np.array(
        Image.fromarray(premul.astype(np.uint8), "RGBA").resize((tw, th), Image.Resampling.LANCZOS)
    ).astype(np.float32)
    alpha = scaled[:, :, 3:4]
    rgb = np.zeros_like(scaled[:, :, :3])
    keep = alpha[:, :, 0] > 8
    rgb[keep] = np.clip(scaled[:, :, :3][keep] / np.maximum(alpha[keep], 1.0) * 255.0, 0, 255)
    resized = np.zeros_like(scaled, dtype=np.uint8)
    resized[:, :, :3] = rgb.astype(np.uint8)
    resized[:, :, 3] = np.clip(alpha[:, :, 0], 0, 255).astype(np.uint8)
    resized = scrub_plate(resized)
    resized = peel_fringe(resized)
    resized = drop_specks(resized)
    ox = (FRAME_W - tw) // 2
    oy = target_bottom - resized.shape[0]
    if oy < 0:
        resized = resized[-oy:, :, :]
        oy = 0
    y_end = min(FRAME_H, oy + resized.shape[0])
    x_end = min(FRAME_W, ox + resized.shape[1])
    canvas[oy:y_end, ox:x_end] = resized[: y_end - oy, : x_end - ox]
    return bleed_clear(canvas)


def backup_current() -> None:
    BACKUP.mkdir(exist_ok=True)
    for face in FACES:
        name = f"idle_{face}.png"
        dest = BACKUP / name
        if not dest.exists():
            shutil.copy2(OUT / name, dest)


def target_metrics(face: str):
    previous = np.array(Image.open(BACKUP / f"idle_{face}.png").convert("RGBA"))
    box = opaque_box(previous)
    if box is None:
        return 165, 177
    _x0, _y0, _x1, y1 = box
    return y1 - _y0, y1


def edge_sample(arr: np.ndarray) -> list[list[int]]:
    samples = []
    alpha = arr[:, :, 3]
    for y in (30, 70, 110, 150):
        xs = np.where(alpha[y] > 40)[0]
        if len(xs) == 0:
            continue
        samples.append([int(xs[0]), y, *arr[y, int(xs[0])].tolist()])
    return samples


def main() -> None:
    backup_current()
    for face in FACES:
        sheet = key_plate(Image.open(SRC / f"slang_idle_{face}_8f.png"))
        height, bottom = target_metrics(face)
        fitted = fit_like(first_cell(sheet), height, bottom)
        dest = OUT / f"idle_{face}.png"
        tmp = OUT / f"idle_{face}.writing.png"
        Image.fromarray(fitted, "RGBA").save(tmp)
        tmp.replace(dest)
        print(
            f"idle_{face}.png box={opaque_box(fitted)} edge={edge_sample(fitted)}",
            flush=True,
        )


if __name__ == "__main__":
    main()
