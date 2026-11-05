#!/usr/bin/env python3
"""Build-time Platinum tokens for the apps the Platinum icon theme has no art for.

usage: platinum-app-tokens.py SHARE OUT [--covered THEME_DIR]...

SHARE is a profile's share directory (a NixOS system path's, in
environment.extraSetup). For every desktop entry in SHARE/applications whose
Icon= is a theme name that no --covered theme has as 32 px art, this draws the
app's own icon (hicolor or pixmaps in SHARE) as a direction A token with the
pure renderer in platinum_icons.py, at the Control Strip's 32 px content box,
and writes OUT/32x32/apps/<name>.png and OUT/index.theme: the
Mountainous-platinum-apps icon theme, which Mountainous-platinum inherits
first. The strip then draws every icon 1:1 and nothing is resampled at run
time. Deterministic: the same SHARE gives the same bytes. No network, cache
or browser state; this is not the favicon CLI.
"""

import argparse
import configparser
import io
import os
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image
from platinum_icons import boxed, canvas_for

# The strip's content box at scale 1.5 (strip-plan.js tileGeometry), and the
# size of the Platinum theme's pixel art.
BOX = 32
THEME_NAME = "Mountainous-platinum-apps"
SIZE_DIR = re.compile(r"^(\d+)x\1$")


def icon_names(applications: Path) -> list[str]:
    """Each theme-name Icon= of the profile's desktop entries, sorted."""
    names = set()
    if not applications.is_dir():
        return []
    for file in sorted(applications.glob("*.desktop")):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            parser.read_string(file.read_text(errors="replace"))
        except configparser.Error:
            continue
        if not parser.has_section("Desktop Entry"):
            continue
        name = parser["Desktop Entry"].get("Icon", "").strip()
        # A path or URL is the app's own file, not a theme name; a symbolic
        # name is a monochrome glyph, not an app icon.
        if not name or "/" in name or name.endswith("-symbolic"):
            continue
        names.add(name)
    return sorted(names)


def covered(themes: list[Path]) -> set[str]:
    """Names that already have 32 px art in a covering theme."""
    out = set()
    for theme in themes:
        for context in sorted((theme / f"{BOX}x{BOX}").glob("*")):
            for file in context.glob("*.png"):
                if file.exists():
                    out.add(file.stem)
    return out


def sources(share: Path, name: str) -> tuple[list[Path], Path | None]:
    """The app's own PNGs (every size) and its SVG, from hicolor or pixmaps."""
    pngs, svg = [], None
    hicolor = share / "icons/hicolor"
    if hicolor.is_dir():
        for directory in sorted(hicolor.iterdir()):
            if SIZE_DIR.match(directory.name):
                file = directory / "apps" / f"{name}.png"
                if file.is_file():
                    pngs.append(file)
        file = hicolor / "scalable/apps" / f"{name}.svg"
        if file.is_file():
            svg = file
    pixmaps = share / "pixmaps"
    for extension in ("png", "xpm"):
        file = pixmaps / f"{name}.{extension}"
        if file.is_file():
            pngs.append(file)
    if svg is None and (pixmaps / f"{name}.svg").is_file():
        svg = pixmaps / f"{name}.svg"
    return pngs, svg


def frames_for(share: Path, name: str) -> list[Image.Image]:
    """The source frames, chosen as the favicon path chooses: bitmaps that
    cover the token's size, else the SVG drawn at that size, else the
    largest bitmap."""
    size = canvas_for(BOX)
    pngs, svg = sources(share, name)
    bitmaps = []
    for file in pngs:
        with Image.open(file) as image:
            bitmaps.append(image.convert("RGBA"))
    if any(min(image.size) >= size for image in bitmaps):
        return bitmaps
    if svg is not None:
        result = subprocess.run(
            [
                os.environ.get("RSVG_CONVERT", "rsvg-convert"),
                "--format=png",
                f"--width={size}",
                f"--height={size}",
                "--keep-aspect-ratio",
                str(svg),
            ],
            capture_output=True,
            timeout=30,
            check=True,
        )
        with Image.open(io.BytesIO(result.stdout)) as image:
            return [image.convert("RGBA")]
    return bitmaps


def generate(share: Path, out: Path, covering: list[Path]) -> list[str]:
    have = covered(covering)
    made = []
    apps = out / f"{BOX}x{BOX}/apps"
    for name in icon_names(share / "applications"):
        if name in have:
            continue
        frames = frames_for(share, name)
        if not frames:
            continue
        token = boxed(frames, BOX, "platinum-light")
        if token is None:
            continue
        apps.mkdir(parents=True, exist_ok=True)
        token.save(apps / f"{name}.png", format="PNG", optimize=False)
        made.append(name)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.theme").write_text(
        "[Icon Theme]\n"
        "Name=Mountainous Platinum app tokens\n"
        "Comment=Platinum tokens for apps without 32 px Platinum art, made at build time\n"
        "Hidden=true\n"
        f"Directories={BOX}x{BOX}/apps\n"
        "\n"
        f"[{BOX}x{BOX}/apps]\n"
        f"Size={BOX}\n"
        "Context=Applications\n"
        "Type=Fixed\n"
    )
    return made


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("share", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--covered", type=Path, action="append", default=[])
    args = parser.parse_args()
    covering = args.covered or [args.share / "icons/Mountainous-platinum"]
    for name in generate(args.share, args.out, covering):
        print(f"{THEME_NAME}: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
