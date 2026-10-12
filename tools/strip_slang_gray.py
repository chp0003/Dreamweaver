"""Remove flat gray leftover blocks from the S'lang 8-dir sheets.

Save as:  tools/strip_slang_gray.py
Run from the project root:

    py -3 tools/strip_slang_gray.py --probe     (optional: list the gray colours it finds)
    py -3 tools/strip_slang_gray.py --dry-run   (optional: report only, write nothing)
    py -3 tools/strip_slang_gray.py             (do it)

What it fixes: a flat dark-gray shape (about RGB 69,66,64 and 40,38,36) left
over from the studio background. It shows between the legs and next to the arm
and staff, mostly in the "up" (back) sheets.

How it stays safe:
  * Only near-neutral grays are matched (the black cloth, brown boots, skin and
    the maroon staff cloth are not).
  * A gray blob is removed only if it is big enough AND touches transparent
    background, so grays inside the costume are never touched.
  * Originals are copied once to slang_8dir/_backup_gray/ before anything is written.
  * Files with nothing to remove are not rewritten. *_loop.png is not touched.

Needs Pillow and numpy.
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

DIR = Path(r"assets/images/characters/slang_8dir")
BACKUP = DIR / "_backup_gray"
FACES = ("down", "down_right", "right", "up_right", "up")
KINDS = ("idle", "walk", "attack")

# Leftover grays measured from in-game screenshots. If --probe shows different
# values on your PNGs, edit this list.
GRAYS = [(69, 66, 64), (40, 38, 36)]
TOL = 9            # per-channel distance to a listed gray
MAX_CHROMA = 10    # max(r,g,b) - min(r,g,b): keeps it neutral
MIN_AREA = 60      # smaller specks are left alone
EDGE_TOL = 20      # looser match for the 1-2 px anti-aliased rim of a removed block
EDGE_CHROMA = 14


def shift(a, dy, dx):
    """out[y, x] = a[y + dy, x + dx], zero outside. Works for 2D and 3D arrays."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys = slice(max(0, dy), h + min(0, dy))
    yd = slice(max(0, -dy), h + min(0, -dy))
    xs = slice(max(0, dx), w + min(0, dx))
    xd = slice(max(0, -dx), w + min(0, -dx))
    out[yd, xd] = a[ys, xs]
    return out


def dilate(m):
    d = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                d |= shift(m, dy, dx)
    return d


def gray_like(arr, tol, max_chroma):
    rgb = arr[:, :, :3].astype(np.int16)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    near = np.zeros(chroma.shape, dtype=bool)
    for g in GRAYS:
        near |= np.abs(rgb - np.array(g, dtype=np.int16)).max(axis=2) <= tol
    return near & (chroma <= max_chroma) & (arr[:, :, 3] > 40)


def components(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        pts = []
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append(pts)
    return out


def find_gray(arr):
    """Boolean mask of the leftover gray block pixels."""
    h, w = arr.shape[:2]
    clear = arr[:, :, 3] <= 15
    mask = gray_like(arr, TOL, MAX_CHROMA)
    removed = np.zeros((h, w), dtype=bool)
    for pts in components(mask):
        if len(pts) < MIN_AREA:
            continue
        touches = False
        for y, x in pts:
            if y == 0 or x == 0 or y == h - 1 or x == w - 1:
                touches = True
                break
            if clear[y - 1:y + 2, x - 1:x + 2].any():
                touches = True
                break
        if touches:
            for y, x in pts:
                removed[y, x] = True
    # Take the thin anti-aliased rim of each removed block too.
    for _ in range(2):
        ring = dilate(removed) & ~removed & (arr[:, :, 3] > 0)
        kill = ring & gray_like(arr, EDGE_TOL, EDGE_CHROMA)
        if not kill.any():
            break
        removed |= kill
    return removed


def apply_removal(arr, removed):
    """Make removed pixels transparent, but keep nearby solid RGB in them so
    linear/mipmap filtering does not pull a dark or gray rim into the edge."""
    out = arr.copy()
    solid = (arr[:, :, 3] > 80) & ~removed
    todo = removed.copy()
    for _ in range(4):
        got = np.zeros_like(todo)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                take = todo & ~got & shift(solid, dy, dx)
                if take.any():
                    out[take, :3] = shift(out, dy, dx)[take, :3]
                    got |= take
        solid |= got
        todo &= ~got
        if not todo.any():
            break
    out[removed, 3] = 0
    return out


def probe(arr):
    """Most common near-neutral colours next to transparency (candidates for GRAYS)."""
    clear = dilate(dilate(arr[:, :, 3] <= 15))
    rgb = arr[:, :, :3].astype(np.int16)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    luma = (rgb[:, :, 0] + rgb[:, :, 1] + rgb[:, :, 2]) // 3
    m = (arr[:, :, 3] > 200) & clear & (chroma <= 12) & (luma > 25) & (luma < 130)
    counts = {}
    for c in map(tuple, rgb[m].tolist()):
        counts[c] = counts.get(c, 0) + 1
    return sorted(counts.items(), key=lambda kv: -kv[1])[:5]


def main():
    args = set(sys.argv[1:])
    do_probe = "--probe" in args
    dry = "--dry-run" in args or do_probe
    if not DIR.exists():
        sys.exit(f"Folder not found: {DIR}  (run from the project root)")
    changed = 0
    for kind in KINDS:
        for face in FACES:
            name = f"{kind}_{face}.png"
            path = DIR / name
            if not path.exists():
                print(f"{name:24} missing, skipped")
                continue
            with Image.open(path) as im:
                src = np.array(im.convert("RGBA"))
            if do_probe:
                print(f"{name:24} {probe(src)}")
                continue
            removed = find_gray(src)
            n = int(removed.sum())
            print(f"{name:24} gray pixels removed: {n}", flush=True)
            if n == 0 or dry:
                continue
            BACKUP.mkdir(exist_ok=True)
            if not (BACKUP / name).exists():
                shutil.copy2(path, BACKUP / name)
            fixed = apply_removal(src, removed)
            tmp = DIR / (name + ".writing.png")
            Image.fromarray(fixed, "RGBA").save(tmp)
            tmp.replace(path)
            changed += 1
    if not do_probe:
        print(f"\nDone. {changed} file(s) rewritten." if not dry else "\nDry run: nothing written.")
        if changed:
            print(f"Originals saved in {BACKUP}. Restart the game to see it.")


if __name__ == "__main__":
    main()
