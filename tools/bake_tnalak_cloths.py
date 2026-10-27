"""Bake deterministic pixel cloth samples for Dreamweaver.

Requires Pillow: ``python -m pip install pillow``.
The motif names are descriptive placeholders; verify them with T'boli
cultural sources before using them as traditional names in the game.
"""

from pathlib import Path
import random

from PIL import Image, ImageDraw


PALETTE = {
    0: (215, 184, 137, 255),
    1: (113, 51, 38, 255),
    2: (33, 25, 26, 255),
}


def pattern(width: int, height: int, seed: int, tier: int) -> list[list[int]]:
    rng = random.Random(seed)
    grid = [[0 for _ in range(width)] for _ in range(height)]
    border = min(2 + tier, width // 3)
    for y in range(height):
        for x in range(width):
            edge = x < border or x >= width - border or y < border or y >= height - border
            if edge and (x + y) % 5 < 2:
                grid[y][x] = 2
    center = width // 2
    for y in range(border, height - border):
        for x in range(center):
            dx = center - 1 - x
            dy = abs(y - height // 2)
            if abs(dx - dy // 2) <= tier or (dx < width // 5 and dy % (tier + 2) == 0):
                color = 1 if (x + y + rng.randrange(2)) % 3 else 2
                grid[y][x] = color
                grid[y][width - 1 - x] = color
    return grid


def bake(output: Path, tier: int) -> None:
    width, height, scale = 32, 48, 4
    image = Image.new("RGBA", (width * scale, height * scale), PALETTE[0])
    draw = ImageDraw.Draw(image)
    grid = pattern(width, height, 7000 + tier, tier)
    for y, row in enumerate(grid):
        for x, value in enumerate(row):
            rect = (x * scale, y * scale, (x + 1) * scale - 1, (y + 1) * scale - 1)
            draw.rectangle(rect, fill=PALETTE[value])
            if (x + y) % 2 == 0:
                draw.line((rect[0], rect[1], rect[2], rect[1]), fill=(240, 215, 167, 255))
    image.save(output / f"tnalak_sample_tier_{tier}.png")


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "assets" / "images" / "weaving_samples"
    destination.mkdir(parents=True, exist_ok=True)
    for difficulty in range(1, 6):
        bake(destination, difficulty)
