#!/usr/bin/env python3
"""Original startup art using the existing light desktop frame/palette.

Copyright 2026 mountainous contributors. SPDX-License-Identifier: CC0-1.0
No Apple or Microsoft art. The small peaks reuse the original lock pattern.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def generate(output: Path, platinum_font: str, win98_font: str) -> None:
    for theme, font_path in (("platinum", platinum_font), ("win98", win98_font)):
        mac = theme == "platinum"
        face, desktop = ("#dddddd", "#aaaaaa") if mac else ("#c0c0c0", "#008080")
        directory = output / f"mountainous-{theme}"
        directory.mkdir(parents=True, exist_ok=True)
        font = ImageFont.truetype(font_path, 16)
        for mode, text in (("boot", "Starting up…"), ("shutdown", "Shutting down…")):
            image = Image.new("RGB", (400, 200), desktop)
            draw = ImageDraw.Draw(image)
            draw.rectangle((8, 8, 391, 191), fill=face, outline="black", width=1)
            draw.line((9, 9, 390, 9), fill="white")
            draw.line((9, 9, 9, 190), fill="white")
            draw.line((10, 190, 390, 190), fill="#999999")
            draw.line((390, 10, 390, 190), fill="#999999")
            if mac:
                for y in range(14, 30, 3):
                    draw.line((16, y, 383, y), fill="#999999")
                    draw.line((16, y+1, 383, y+1), fill="white")
            else:
                draw.rectangle((12, 12, 387, 33), fill="#000080")
                draw.text((16, 12), "Mountainous", font=font, fill="white")
            # The same two-face peak motif as lockplan.PATTERNS["peaks"].
            draw.polygon(((174, 92), (194, 52), (194, 92)), fill="white", outline="black")
            draw.polygon(((194, 52), (218, 92), (194, 92)), fill="#999999", outline="black")
            draw.text((200, 112), "Mountainous", font=font, fill="black", anchor="mt")
            draw.text((200, 145), text, font=font, fill="black", anchor="mt")
            image.save(directory / f"{mode}.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("platinum_font")
    parser.add_argument("win98_font")
    args = parser.parse_args()
    generate(args.output, args.platinum_font, args.win98_font)
