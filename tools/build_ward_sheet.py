"""Body-sized woven ward. The cloth covers S'lang; the weave stays open so she shows through."""
import math
from pathlib import Path

from PIL import Image

OUT = Path(r"D:\Users\TEMP\Desktop\sideproj\Dreamweaver\assets\images\vfx\slang_ward.png")
FRAMES = 8
SRC_W = 96
SRC_H = 168
SCALE = 2
CX = SRC_W * 0.5
CY = SRC_H * 0.5


def shield_mask(x: int, y: int) -> float:
	nx = (x + 0.5 - CX) / 40.0
	ny = (y + 0.5 - CY) / 76.0
	return nx * nx + ny * ny


def paint(phase: float) -> Image.Image:
	image = Image.new("RGBA", (SRC_W, SRC_H), (0, 0, 0, 0))
	px = image.load()
	sheen = phase * math.tau
	for y in range(SRC_H):
		for x in range(SRC_W):
			d = shield_mask(x, y)
			if d > 1.0:
				continue
			ang = math.atan2((y + 0.5 - CY) / 76.0, (x + 0.5 - CX) / 40.0)
			if d > 0.9:
				color = (244, 214, 120, 245) if math.cos(ang - sheen) > 0.55 else (110, 32, 40, 245)
				px[x, y] = color
				continue
			if d > 0.82:
				px[x, y] = (214, 168, 64, 235)
				continue
			gx = int(x / 8)
			gy = int(y / 8)
			cell_x = x % 8
			cell_y = y % 8
			diamond = abs(cell_x - 3.5) + abs(cell_y - 3.5)
			if diamond < 2.1:
				color = (176, 46, 52, 175) if (gx + gy) % 2 == 0 else (232, 196, 92, 175)
			elif diamond < 3.0:
				color = (236, 214, 150, 150)
			else:
				# Open cloth. She has to read through the middle.
				color = (18, 12, 16, 70)
			band = abs((y / float(SRC_H)) - ((phase * 0.85 + 0.08) % 1.0))
			if band < 0.012 and d < 0.8:
				color = (
					min(255, color[0] + 70),
					min(255, color[1] + 55),
					min(255, color[2] + 24),
					min(220, color[3] + 40),
				)
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
