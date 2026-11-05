#!/usr/bin/env python3
"""Build-time Platinum tokens for installed apps.

usage: platinum-app-tokens.py SHARE OUT [--covered THEME_DIR]...

SHARE is a profile's share directory (a NixOS system path's, in
environment.extraSetup). Writes the Mountainous-platinum-apps icon theme to
OUT, which Mountainous-platinum inherits first, with two kinds of token, both
drawn by the pure renderer in platinum_icons.py:

  32x32/apps/<name>.png
      For every desktop entry whose Icon= is a theme name that no --covered
      theme has as 32 px art: the app's own icon (hicolor or pixmaps in
      SHARE) as a 32 px token, so Platinum surfaces that ask the theme for
      the name find Platinum art.

  <C>x<C>/apps/mountainous.strip.<name>.png
      The Control Strip's icons (strip-plan.js tileGeometry). For every name
      the strip can ask for (each desktop entry's icon, each app the covering
      theme draws, and the strip's fallbacks chromium and
      application-x-executable), a token whose opaque bounds are the strip's
      optical size (render_extent): 26 px on a 30 px canvas at scale 1.5.
      The source is the app's own icon, else the covering theme's own art.
      The strip draws them 1:1, so every strip icon has the same size and
      none is resampled at run time.

Deterministic: the same SHARE gives the same bytes. No network, cache or
browser state; this is not the favicon CLI.
"""

import argparse
import configparser
import io
import math
import os
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image
from platinum_icons import boxed, canvas_for, render_extent

# Platinum's pixel-art size: the art other surfaces ask the theme for.
BOX = 32
THEME_NAME = "Mountainous-platinum-apps"
SIZE_DIR = re.compile(r"^(\d+)x\1$")
# The strip's icons: a name prefix with no dash before the app's name, so
# Qt's dash fallback never turns a missing strip name into another icon.
STRIP_PREFIX = "mountainous.strip."
# The scales the strip's tokens are made for (one directory each). Qt asks
# an icon theme for a size at the window's scale rounded up (20 logical px at
# 1.5 is looked up as 40) and takes the nearest directory, only ever scaling
# it down: a 40 px directory for scale 2 would win 1.5's lookup and be
# scaled to 30. So no directory is larger than 1.5's 30; at 2 the strip
# draws the 30 px tokens nearest-neighbour at 40.
STRIP_SCALES = (1, 1.5)
# app-icon.js BROWSER and GENERIC: what the strip shows for a name it has no
# token for.
FALLBACKS = ("chromium", "application-x-executable")


def js_round(value: float) -> int:
    """JavaScript's Math.round: halves go up."""
    return math.floor(value + 0.5)


def strip_extent(scale: float) -> int:
    """The strip's optical size in device px at a scale: strip-plan.js
    tileGeometry's box (TILE_H 32 logical, a one-hair bevel, ICON_PAD 6 on
    each side). 26 at 1.5."""
    return js_round(32 * scale) - 2 * max(1, js_round(scale)) - 2 * js_round(6 * scale)


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


def covered_apps(themes: list[Path]) -> set[str]:
    """The app names a covering theme draws at 32 px."""
    out = set()
    for theme in themes:
        for file in (theme / f"{BOX}x{BOX}/apps").glob("*.png"):
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


def frames_for(share: Path, name: str, size: int) -> list[Image.Image]:
    """The source frames for a size px token, chosen as the favicon path
    chooses: bitmaps that cover the size, else the SVG drawn at that size,
    else the largest bitmap."""
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


def theme_art(covering: list[Path], name: str) -> list[Image.Image]:
    """A covering theme's own app art for name, its largest size: the
    strip token's source when the app ships no icon of its own."""
    for theme in covering:
        files = []
        for directory in theme.iterdir() if theme.is_dir() else []:
            match = SIZE_DIR.match(directory.name)
            file = directory / "apps" / f"{name}.png"
            if match and file.is_file():
                files.append((int(match.group(1)), file))
        if files:
            with Image.open(max(files)[1]) as image:
                return [image.convert("RGBA")]
    return []


def strip_names(share: Path, covering: list[Path]) -> list[str]:
    """Every name the Control Strip can ask for: each desktop entry's icon,
    each app the covering themes draw, and the strip's fallbacks."""
    return sorted(
        set(icon_names(share / "applications")) | covered_apps(covering) | set(FALLBACKS)
    )


def generate_strip(
    share: Path, out: Path, covering: list[Path], scales=STRIP_SCALES
) -> list[tuple[str, int]]:
    """The strip's tokens at each scale; returns (directory, size) pairs."""
    directories = []
    names = strip_names(share, covering)
    # Read each name's source once; many names share one (theme aliases).
    frames = {}
    for name in names:
        frames[name] = frames_for(share, name, canvas_for(strip_extent(max(scales))))
        frames[name] = frames[name] or theme_art(covering, name)
    for scale in scales:
        extent = strip_extent(scale)
        canvas = canvas_for(extent)
        directory = f"{canvas}x{canvas}/apps"
        target = out / directory
        drawn = {}
        for name in names:
            if not frames[name]:
                continue
            key = tuple((image.size, image.tobytes()) for image in frames[name])
            if key not in drawn:
                drawn[key] = render_extent(frames[name], extent, canvas, "platinum-light")
            if drawn[key] is None:
                continue
            target.mkdir(parents=True, exist_ok=True)
            drawn[key].save(target / f"{STRIP_PREFIX}{name}.png", format="PNG", optimize=False)
        if target.is_dir():
            directories.append((directory, canvas))
    return directories


def generate(
    share: Path, out: Path, covering: list[Path], scales=STRIP_SCALES
) -> list[str]:
    """Write the theme; returns the names that got 32 px art."""
    have = covered(covering)
    made = []
    apps = out / f"{BOX}x{BOX}/apps"
    for name in icon_names(share / "applications"):
        if name in have:
            continue
        frames = frames_for(share, name, canvas_for(BOX))
        if not frames:
            continue
        token = boxed(frames, BOX, "platinum-light")
        if token is None:
            continue
        apps.mkdir(parents=True, exist_ok=True)
        token.save(apps / f"{name}.png", format="PNG", optimize=False)
        made.append(name)
    out.mkdir(parents=True, exist_ok=True)
    directories = [(f"{BOX}x{BOX}/apps", BOX)]
    directories += [d for d in generate_strip(share, out, covering, scales) if d[1] != BOX]
    (out / "index.theme").write_text(
        "[Icon Theme]\n"
        "Name=Mountainous Platinum app tokens\n"
        "Comment=Platinum tokens made at build time: 32 px art for apps without it, and the Control Strip's icons\n"
        "Hidden=true\n"
        f"Directories={','.join(d for d, _ in directories)}\n"
        + "".join(
            f"\n[{d}]\nSize={size}\nContext=Applications\nType=Fixed\n"
            for d, size in directories
        )
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
