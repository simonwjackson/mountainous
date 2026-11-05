#!/usr/bin/env python3
"""Assert each tb-web window's rendered icon, never a whole-strip colour sum."""

import json
import math
import os
import sys
from pathlib import Path

from PIL import Image

work, out, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
art = Path(os.environ["DESKTOP_ART"]) / "share/icons"
plan = json.loads((work / "strip.json").read_text())
places = json.loads((work / "places.json").read_text())
failures = []


def snap(value):
    # JS Math.round, not bankers' rounding.
    return math.floor(value * 1.5 + 0.5)


def check(ok, label):
    print(("PASS " if ok else "FAIL ") + mode + " " + label)
    if not ok:
        failures.append(label)


names = ["browser", "tab", "reddit", "Jellyfin", "Microsoft Teams", "unknown"]
classes = [
    "chromium",
    "chromium",
    "webapp-reddit",
    "chrome-lneafpomhdmfgkblnkjeglpppndalpik-Default",
    "chrome-ompifgpmddkgmclendfeacglnodjjndh-Default",
    "chromium",
]
# The harness positions windows in three columns; the production strip
# orders by position, not app name or the original catalogue order.
order = [0, 3, 6, 1, 4, 2, 5]


def matches(shown, ref):
    """Composite over the tile face; permit only 1 channel value of Qt rounding."""
    face = shown.getpixel((0, 0))
    expected = Image.new("RGBA", ref.size, face + (255,))
    expected.alpha_composite(ref)
    return (
        max(
            abs(a - b)
            for p, q in zip(
                shown.get_flattened_data(), expected.convert("RGB").get_flattened_data()
            )
            for a, b in zip(p, q)
        )
        <= 1
    )


for theme in ["win98", "platinum"]:
    full = Image.open(out / f"{theme}-full.png").convert("RGB")
    strip = full.crop(
        (0, full.height - 120, full.width if theme == "win98" else 1500, full.height)
    )
    strip.save(out / f"{theme}-strip.png")
    # Even a single upstream-logo pixel is not allowed on these surfaces.
    for label, colour in [
        ("red", (219, 68, 55)),
        ("green", (15, 157, 88)),
        ("yellow", (244, 180, 0)),
        ("blue", (26, 115, 232)),
    ]:
        count = sum(
            n
            for n, p in strip.getcolors(1 << 24)
            if max(abs(a - b) for a, b in zip(p, colour)) <= 6
        )
        check(count == 0, f"{theme}: no upstream Chromium {label} ({count} px)")
    for i, (name, icon) in enumerate(zip(names, classes)):
        site = mode == "site" and i < 5
        if site:
            ref = Image.open(
                work / ("web" if theme == "win98" else "references") / f"{name}.png"
            ).convert("RGBA")
        elif theme == "platinum":
            canvas = plan["tile"]["canvas"]["size"]
            ref = Image.open(
                work
                / f"data/icons/Mountainous-platinum-apps/{canvas}x{canvas}/apps"
                / f"mountainous.strip.{icon}.png"
            ).convert("RGBA")
        else:
            path = art / "Mountainous-win98/apps/32" / f"{icon}.png"
            if not path.exists():
                path = art / "Chicago95/apps/32" / f"{icon}.png"
            # Unboxed WindowIcon asks the provider for 32 logical px; Qt
            # requests 48 at DPR 1.5, then draws the result at 32 device px.
            # Lettermarks only have 16/32 sources; Chicago95 has a 48 source.
            larger = art / "Chicago95/apps/48" / f"{icon}.png"
            ref = Image.open(larger if larger.exists() else path).convert("RGBA")
            ref = ref.resize((32, 32), Image.Resampling.NEAREST)
        if theme == "platinum":
            g = plan["tile"]
            slot = plan["slots"][order.index(i)]
            press = g["sunk"] if i == 0 else 0
            x = snap(plan["CAP"] + slot) + g["canvas"]["x"] + press
            y = full.height - snap(plan["BOTTOM"] + plan["HEIGHT"])
            y += snap((plan["HEIGHT"] - plan["TILE_H"]) / 2) + g["canvas"]["y"] + press
            canvas = g["canvas"]["size"]
            check(
                ref.size == (canvas, canvas),
                f"{theme} {name}: {canvas} px reference canvas",
            )
            shown = full.crop((x, y, x + canvas, y + canvas))
            ok = matches(shown, ref)
        else:
            # The button's actual place comes from the live QML. Only search
            # its icon cell, not a neighbour or its title. Win98's focused
            # button has a checker behind the transparent theme art.
            x = snap(places[f"win{i}"]["x"]) + (8 if i == 0 else 6)
            cell = full.crop((x, full.height - 84, x + 32, full.height))
            solid = [
                (p % 32, p // 32, c[:3])
                for p, c in enumerate(ref.get_flattened_data())
                if c[3] == 255
            ]
            ok = len(solid) >= 20 and any(
                all(
                    max(abs(a - b) for a, b in zip(cell.getpixel((rx, y + ry)), c)) <= 1
                    for rx, ry, c in solid
                )
                for y in range(cell.height - 31)
            )
            shown = cell
        shown.save(out / f"{theme}-{i}-{name}.png")
        check(
            ok,
            f"{theme} window {i} ({name}): "
            + (
                "installed icon"
                if theme == "win98" and site and i in [3, 4]
                else "sharp site icon"
                if theme == "win98" and site
                else f"generated {canvas} px {'site/installed' if site else 'theme art fallback'} token drawn 1:1"
                if theme == "platinum"
                else "theme art fallback"
            ),
        )

sys.exit(1 if failures else 0)
