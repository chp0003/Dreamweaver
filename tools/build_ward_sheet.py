"""Body-sized woven shield. A t'nalak kite: brass rim, kleng bands, a center diamond.

The field stays open so S'lang reads through the cloth. Eight frames sweep a
weft highlight down the warp and a sheen around the rim.
"""
import math
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "assets" / "images" / "vfx" / "slang_ward.png"
FRAMES = 8
SRC_W = 96
SRC_H = 168
SCALE = 2
CX = SRC_W * 0.5
CY = 78.0

PITCH = (10, 8, 7, 255)
SOOT = (24, 19, 18, 78)
BRASS = (176, 138, 46, 245)
BRASS_DEEP = (122, 92, 28, 245)
GOLD = (237, 209, 114, 245)
SUN = (248, 233, 168, 250)
RED = (158, 40, 35, 230)
RED_DEEP = (89, 20, 15, 235)
CREAM = (244, 234, 214, 210)
CREAM_DIM = (180, 168, 142, 150)


def shield_limit(ny: float) -> float:
	"""Half-width of the kite. ny -1 is the crown, 1 is the point. Widest at the shoulder."""
	if ny < -0.22:
		t = (ny + 0.22) / (-1.0 + 0.22)
		t = max(0.0, min(1.0, t))
		return math.sqrt(max(0.0, 1.0 - t * t))
	t = (ny + 0.22) / 1.22
	return max(0.0, 1.0 - t)


def sample(x: int, y: int) -> tuple[float, float, float]:
	"""nx across the shield, ny down it, and how close to the edge (0 center, 1 rim)."""
	nx = (x + 0.5 - CX) / 40.0
	ny = (y + 0.5 - CY) / 74.0
	limit = shield_limit(ny)
	if limit <= 0.001:
		return nx, ny, 99.0
	return nx, ny, abs(nx) / limit


def paint(phase: float) -> Image.Image:
	image = Image.new("RGBA", (SRC_W, SRC_H), (0, 0, 0, 0))
	px = image.load()
	sheen = phase * math.tau
	weft = (phase * 0.92 + 0.06) % 1.0
	for y in range(SRC_H):
		for x in range(SRC_W):
			nx, ny, edge = sample(x, y)
			if edge > 1.04:
				continue
			ang = math.atan2(ny, nx if abs(nx) > 0.001 else 0.001)
			lit = math.cos(ang - sheen) > 0.45
			if edge > 0.90:
				px[x, y] = SUN if lit else BRASS
				continue
			if edge > 0.80:
				px[x, y] = GOLD if lit else BRASS_DEEP
				continue
			if edge > 0.74:
				px[x, y] = BRASS_DEEP
				continue

			color = SOOT
			# Sparse warp. She shows through the gaps.
			if x % 10 == 4 and edge < 0.72:
				color = CREAM if abs((y / SRC_H) - weft) < 0.045 else CREAM_DIM

			# Kleng bands: a 45° zigzag, four pixels tall, walking with the frame.
			for band_top in (32, 114):
				if not (band_top <= y <= band_top + 7) or edge >= 0.73:
					continue
				local = (x + int(phase * 8)) % 8
				tooth = local if local < 4 else 8 - local
				if abs((y - band_top) - tooth) <= 1:
					color = GOLD
				else:
					color = RED

			# Center diamond, the ikat mark.
			dx = abs(x + 0.5 - CX) / 16.0
			dy = abs(y + 0.5 - (CY + 6.0)) / 22.0
			diamond = dx + dy
			if diamond < 1.0 and edge < 0.7:
				if diamond > 0.82:
					color = CREAM
				elif diamond > 0.62:
					color = RED
				elif diamond > 0.38:
					color = RED_DEEP
				else:
					color = BRASS if lit else BRASS_DEEP
				if diamond < 0.16:
					color = SUN if lit else GOLD

			px[x, y] = color
	return image.resize((SRC_W * SCALE, SRC_H * SCALE), Image.Resampling.NEAREST)


def main() -> None:
	cell_w = SRC_W * SCALE
	cell_h = SRC_H * SCALE
	sheet = Image.new("RGBA", (cell_w * FRAMES, cell_h), (0, 0, 0, 0))
	for i in range(FRAMES):
		sheet.alpha_composite(paint(i / FRAMES), (i * cell_w, 0))
	OUT.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(OUT)
	print(OUT, sheet.size)


if __name__ == "__main__":
	main()
