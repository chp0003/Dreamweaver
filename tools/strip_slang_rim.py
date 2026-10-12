"""Remove the dark red keying rim left on S'lang's outline. Keeps the staff cloth."""
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

DIR = Path(r"assets/images/characters/slang_8dir")
BACKUP = DIR / "_backup_rim"
FACES = ("down", "down_right", "right", "up_right", "up")
KINDS = ("idle", "walk", "attack")


def is_rim(rgb, alpha):
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    return (alpha > 20) & (r > g + 20) & (b > g + 8) & (g < 90) & (r > 50) & (b > 18)


def dilate(m):
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d


def clean(arr):
    arr = arr.copy()
    h, w = arr.shape[:2]
    for _ in range(6):
        rgb = arr[:, :, :3].astype(np.int16)
        alpha = arr[:, :, 3].astype(np.int16)
        fr = is_rim(rgb, alpha)
        if not fr.any():
            break
        acc = fr.astype(np.float32)
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx == 0 and dy == 0:
                    continue
                ys = slice(max(0, dy), h + min(0, dy))
                yt = slice(max(0, -dy), h + min(0, -dy))
                xs = slice(max(0, dx), w + min(0, dx))
                xt = slice(max(0, -dx), w + min(0, -dx))
                acc[yt, xt] += fr[ys, xs]
        acc /= 25.0
        clear = alpha < 25
        hit = (fr & (acc < 0.4)) | (fr & dilate(clear))
        if not hit.any():
            break
        ys, xs = np.where(hit)
        for y, x in zip(ys.tolist(), xs.tolist()):
            repl = None
            for rad in range(1, 8):
                y0, y1 = max(0, y - rad), min(h, y + rad + 1)
                x0, x1 = max(0, x - rad), min(w, x + rad + 1)
                win = arr[y0:y1, x0:x1]
                wr, wg, wb, wa = [win[:, :, i].astype(np.int16) for i in range(4)]
                good = (wa > 180) & ~((wr > wg + 20) & (wb > wg + 8) & (wg < 90) & (wr > 50) & (wb > 18))
                if good.any():
                    cy, cx = np.argwhere(good)[0]
                    repl = win[cy, cx]
                    break
            if arr[y, x, 3] < 100 or repl is None:
                if arr[y, x, 3] < 220:
                    arr[y, x] = (0, 0, 0, 0)
                continue
            arr[y, x, 0] = repl[0]
            arr[y, x, 1] = repl[1]
            arr[y, x, 2] = repl[2]
    src = arr.copy()
    solid = src[:, :, 3] > 80
    filled = np.zeros(solid.shape, dtype=bool)
    for rad in range(1, 4):
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
                shifted[y0d:y0d + hh, x0d:x0d + ww] = solid[y0s:y0s + hh, x0s:x0s + ww]
                color[y0d:y0d + hh, x0d:x0d + ww] = src[y0s:y0s + hh, x0s:x0s + ww]
                take = target & shifted
                arr[take, :3] = color[take, :3]
                filled |= take
                target &= ~take
    still = (src[:, :, 3] == 0) & ~filled
    arr[still] = (0, 0, 0, 0)
    return arr


def main():
    BACKUP.mkdir(exist_ok=True)
    for kind in KINDS:
        for face in FACES:
            name = f"{kind}_{face}.png"
            path = DIR / name
            with Image.open(path) as im:
                src = np.array(im.convert("RGBA"))
            before = int(is_rim(src[:, :, :3].astype(np.int16), src[:, :, 3].astype(np.int16)).sum())
            fixed = clean(src)
            after = int(is_rim(fixed[:, :, :3].astype(np.int16), fixed[:, :, 3].astype(np.int16)).sum())
            if not (BACKUP / name).exists():
                shutil.copy2(path, BACKUP / name)
            tmp = DIR / (name + ".writing.png")
            Image.fromarray(fixed, "RGBA").save(tmp)
            tmp.replace(path)
            print(f"{name:24} rim {before} -> {after}", flush=True)


if __name__ == "__main__":
    main()
