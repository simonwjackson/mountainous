#!/usr/bin/env python3
"""Measure the Control Strip's tiles in platinum-strip.sh's captures.

usage: platinum-strip.py <work dir> <out dir>

<work>/geometry.json is strip-plan.js's answer at scale 1.5 (tileGeometry,
the slots of the strip-icons fixture and the strip's constants); the
captures are <work>/{light,dark,black}-full.png, the whole 2880 x 1800
output. Each tile is found where the plan puts it, and its pixels must hold:

  padding  nothing but the face between the inside of the bevel and the
           icon's box, and between the box and the ▴ (the box moves one px
           down and right when pressed in)
  gap      at least MIN_POP_GAP clear device px between any icon pixel and
           any ▴ pixel (Chebyshev: a diagonal neighbour touches)
  1:1      theme art, a build-time token and a run-time token match their
           PNGs exactly over the face, unscaled, in the same box
  stipple  an icon on another page: every other device px is the surface

Writes <out>/measurements.json and an 8x zoom of each scheme's tiles with
the box and the ▴ outlined.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

work, out = Path(sys.argv[1]), Path(sys.argv[2])
plan = json.loads((work / "geometry.json").read_text())
g = plan["tile"]
dpr = g["dpr"]
H = 1800
# The strip's window is anchored to the bottom; its body sits BOTTOM above
# the edge; the tiles (HEIGHT - TILE_H) / 2 below the body's top, snapped.
snap = lambda v: int(np.floor(v * dpr + 0.5))  # JS Math.round, for v >= 0
body_top = H - snap(plan["BOTTOM"] + plan["HEIGHT"])
tile_top = body_top + snap((plan["HEIGHT"] - plan["TILE_H"]) / 2)
track_x = snap(plan["CAP"])
# The strip-icons fixture, in the strip's order (by page, then position).
TILES = [
    ("chromium", "art", 1, True),
    ("syncthing", "built", 1, False),
    ("ghostty", "art", 1, False),
    ("letter", "letter", 1, False),
    ("jellyfin", "token", 1, False),
    ("teams", "token", 2, False),
    ("syncthing", "built", 2, False),
    ("signal", "art", 2, False),
]
ART = {
    "chromium": "32x32/apps/chromium.png",
    "ghostty": "32x32/apps/com.mitchellh.ghostty.png",
    "signal": "32x32/apps/signal.png",
}
desktop_art = Path(plan["desktopArt"]) / "share/icons/Mountainous-platinum"
built = work / "data/icons/Mountainous-platinum-apps/32x32/apps"
cache = work / "cache/mountainous/icons"
failures = []


def check(ok, message):
    print(("PASS " if ok else "FAIL ") + message)
    if not ok:
        failures.append(message)


def reference(name, kind, scheme):
    """The PNG the box must show, unscaled, or None."""
    if kind == "art":
        return Image.open(desktop_art / ART[name]).convert("RGBA")
    if kind == "built":
        return Image.open(built / f"{name}.png").convert("RGBA")
    if kind == "token":
        # The helper's cached 36 px token, without its 2 px margin.
        theme = "platinum-light" if scheme == "light" else "platinum-dark"
        files = sorted(cache.glob(f"*-{g['canvas']['size']}-{theme}.png"))
        tokens = [Image.open(f).convert("RGBA") for f in files]
        m = g["margin"]
        s = g["canvas"]["size"]
        return [t.crop((m, m, s - m, s - m)) for t in tokens]
    return None


def gap(a, b):
    """Clear px between two pixel sets: Chebyshev distance less one."""
    if not len(a) or not len(b):
        return None
    d = np.maximum(
        np.abs(a[:, None, 0] - b[None, :, 0]), np.abs(a[:, None, 1] - b[None, :, 1])
    )
    return int(d.min()) - 1


results = {}
for scheme in ("light", "dark", "black"):
    full = np.array(Image.open(work / f"{scheme}-full.png").convert("RGB")).astype(int)
    surface = tuple(full[body_top + snap(plan["HEIGHT"]) // 2, snap(plan["CAP"]) + 1])
    zoom_tiles = []
    for (name, kind, page, focused), slot in zip(TILES, plan["slots"]):
        x0 = track_x + snap(slot)
        y0 = tile_top
        tile = full[y0 : y0 + g["h"], x0 : x0 + g["w"]]
        inner = g["inner"]
        press = g["sunk"] if focused else 0
        bx, by, bs = g["box"]["x"] + press, g["box"]["y"] + press, g["box"]["size"]
        p = g["pop"]
        region = tile[inner["y"] : inner["y"] + inner["h"], inner["x"] : inner["x"] + inner["w"]]
        # The face: the commonest colour inside the bevel.
        colours, counts = np.unique(region.reshape(-1, 3), axis=0, return_counts=True)
        face = tuple(colours[counts.argmax()])
        differs = np.abs(tile - np.array(face)).sum(axis=2) > 0
        in_box = np.zeros_like(differs)
        in_box[by : by + bs, bx : bx + bs] = True
        in_pop = np.zeros_like(differs)
        in_pop[p["y"] : p["y"] + p["h"], p["x"] : p["x"] + p["w"]] = True
        in_inner = np.zeros_like(differs)
        in_inner[inner["y"] : inner["y"] + inner["h"], inner["x"] : inner["x"] + inner["w"]] = True
        label = f"{scheme} {name} (page {page}{', pressed in' if focused else ''})"
        stray = differs & in_inner & ~in_box & ~in_pop
        check(not stray.any(), f"{label}: nothing in the padding or the gap ({int(stray.sum())} px)")
        icon = np.argwhere(differs & in_box)
        mark = np.argwhere(differs & in_pop)
        check(len(icon) > 0, f"{label}: the icon draws")
        check(len(mark) > 0, f"{label}: the ▴ draws")
        clear = gap(icon, mark)
        check(clear is not None and clear >= plan["MIN_POP_GAP"], f"{label}: {clear} px between the icon and the ▴")
        entry = {"face": [int(c) for c in face], "gap": clear}
        if len(icon):
            top, left = icon.min(axis=0)
            bottom, right = icon.max(axis=0)
            entry["iconBox"] = [int(left), int(top), int(right) + 1, int(bottom) + 1]
            entry["padding"] = {
                "left": int(left - inner["x"]),
                "top": int(top - inner["y"]),
                "bottom": int(inner["y"] + inner["h"] - 1 - bottom),
                "toPop": int(mark[:, 1].min() - right - 1) if len(mark) else None,
            }
            check(
                min(entry["padding"]["left"], entry["padding"]["top"], entry["padding"]["bottom"]) >= g["pad"] - (1 if focused else 0),
                f"{label}: padding {entry['padding']} >= {g['pad']} px",
            )
        ref = reference(name, kind, scheme)
        shown = tile[by : by + bs, bx : bx + bs]
        if ref is not None and page == 1:
            refs = ref if isinstance(ref, list) else [ref]
            best = None
            for r in refs:
                if r.size != (bs, bs):
                    continue
                over = Image.new("RGBA", r.size, face + (255,))
                over.alpha_composite(r)
                want = np.array(over.convert("RGB")).astype(int)
                worst = int(np.abs(want - shown).max())
                best = worst if best is None else min(best, worst)
            check(best is not None and best <= 1, f"{label}: the {kind} is drawn 1:1 in the {bs} px box (max channel error {best})")
            entry["oneToOne"] = best
        if page != 1 and len(icon):
            # The disabled stipple: on a flat tile the face is the surface, so
            # the icon's visible pixels sit on one checker parity; the other
            # parity is the surface. (The token's soft shadow is outside the
            # stipple's mask and shows on both.)
            parity = (icon[:, 0] + icon[:, 1] + x0 + y0) % 2
            share = float(max(np.mean(parity == 0), np.mean(parity == 1)))
            entry["stipple"] = share
            check(face == surface, f"{label}: a flat tile on the surface")
            check(share >= 0.85, f"{label}: the stipple covers every other px ({share:.2f} of the icon on one parity)")
        results.setdefault(scheme, {})[f"{name}-p{page}"] = entry
        # 8x inspection copy with the box (green) and the ▴ rect (red).
        crop = Image.fromarray(tile.astype(np.uint8)).resize((g["w"] * 8, g["h"] * 8), Image.NEAREST)
        draw = ImageDraw.Draw(crop)
        draw.rectangle((bx * 8, by * 8, (bx + bs) * 8 - 1, (by + bs) * 8 - 1), outline=(0, 200, 0))
        draw.rectangle((p["x"] * 8, p["y"] * 8, (p["x"] + p["w"]) * 8 - 1, (p["y"] + p["h"]) * 8 - 1), outline=(220, 0, 0))
        zoom_tiles.append(crop)
    sheet = Image.new("RGB", (sum(t.width for t in zoom_tiles) + 8 * (len(zoom_tiles) - 1), zoom_tiles[0].height), (255, 0, 255))
    x = 0
    for t in zoom_tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 8
    sheet.save(out / f"tiles-{scheme}-8x.png")

# Many windows at 600 logical px: the strip still ends RIGHT_EDGE short of
# the screen's right edge (the rest scrolls; strip-plan.test.js proves every
# tile reachable), and it is longer than the screen would hold otherwise.
narrow = work / "many-narrow-full.png"
if narrow.exists():
    full = np.array(Image.open(narrow).convert("RGB")).astype(int)
    row = full[body_top + snap(plan["HEIGHT"]) // 2]
    desktop = row[-1]
    drawn = np.nonzero(np.abs(row - desktop).sum(axis=1) > 0)[0]
    end = int(drawn.max()) + 1 if len(drawn) else 0
    limit = full.shape[1] - snap(plan["RIGHT_EDGE"])
    check(0 < end <= limit, f"narrow: the strip ends at {end} px, within {limit}")
    results["narrow"] = {"end": end, "limit": limit}

(out / "measurements.json").write_text(json.dumps({"geometry": g, "tiles": results}, indent=1) + "\n")
print(("FAIL" if failures else "PASS") + f": {len(failures)} failures")
sys.exit(1 if failures else 0)
