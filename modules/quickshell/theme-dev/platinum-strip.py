#!/usr/bin/env python3
"""Measure the Control Strip's tiles in platinum-strip.sh's captures.

usage: platinum-strip.py <work dir> <out dir>

<work>/geometry.json is strip-plan.js's answer at scale 1.5 (tileGeometry,
the slots of the strip-icons fixture and the strip's constants); the
captures are <work>/{light,dark,black}-full.png, the whole 2880 x 1800
output. Each tile is found where the plan puts it, and its pixels must hold:

  optical  every icon's opaque bounds (outline, depth and shadow: every px
           that is not the face) are the plan's extent on their longest
           side, centred in the box, so every tile shows one size with the
           same padding to the bevel: a run-time site token, a build-time
           app token, a theme-art app's token and Chromium's theme cube token for
           a window with no page icon. Across all of them the size and the
           padding agree to 1 px (the box moves one px down and right when
           pressed in)
  padding  nothing but the face between the inside of the bevel and the
           box, and between the box and the ▴
  gap      at least MIN_POP_GAP clear device px between any icon pixel and
           any ▴ pixel (Chebyshev: a diagonal neighbour touches)
  1:1      every token matches its PNG exactly over the face, unscaled, on
           its canvas
  stipple  an icon on another page: every other device px is the surface

Writes <out>/measurements.json and an 8x zoom of each scheme's tiles with
the box (green), the canvas (blue) and the ▴ (red) outlined.
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
# The strip-icons fixture, in the strip's order (by page, then position):
# (label, kind, page, pressed in). Kinds: "browser" the theme's cube token
# for a window with no page icon; "built" a build-time token from the app's
# own icon (no theme art); "theme" a build-time token from the theme's art;
# "site" a run-time token of a PWA's icon; "letter" no app id yet.
TILES = [
    ("chromium", "browser", 1, True),
    ("syncthing", "built", 1, False),
    ("com.mitchellh.ghostty", "theme", 1, False),
    ("letter", "letter", 1, False),
    ("jellyfin", "site", 1, False),
    ("teams", "site", 1, False),
    ("assistant", "site", 1, False),
    ("syncthing", "built", 2, False),
    ("signal", "theme", 2, False),
    ("teams", "site", 2, False),
]
SITE = {
    "jellyfin": "pwa-jellyfin.png",
    "teams": "pwa-teams.png",
    "assistant": "pwa-assistant.png",
}
canvas = g["canvas"]["size"]
extent = g["extent"]
strip = work / f"data/icons/Mountainous-platinum-apps/{canvas}x{canvas}/apps"
cache = work / "cache/mountainous/icons"
failures = []


def check(ok, message):
    print(("PASS " if ok else "FAIL ") + message)
    if not ok:
        failures.append(message)


def reference(name, kind, scheme):
    """The canvas px PNGs the tile may show, unscaled, or None."""
    if kind in ("browser", "built", "theme"):
        return [Image.open(strip / f"mountainous.strip.{name}.png").convert("RGBA")]
    if kind == "site":
        # The helper's cached tokens at the strip's canvas and extent.
        theme = "platinum-light" if scheme == "light" else "platinum-dark"
        files = sorted(cache.glob(f"*-{canvas}e{extent}-{theme}.png"))
        return [Image.open(f).convert("RGBA") for f in files]
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
optical = []
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
        cx, cy = g["canvas"]["x"] + press, g["canvas"]["y"] + press
        p = g["pop"]
        region = tile[inner["y"] : inner["y"] + inner["h"], inner["x"] : inner["x"] + inner["w"]]
        # The face: the commonest colour inside the bevel.
        colours, counts = np.unique(region.reshape(-1, 3), axis=0, return_counts=True)
        face = tuple(int(c) for c in colours[counts.argmax()])
        differs = np.abs(tile - np.array(face)).sum(axis=2) > 0
        in_box = np.zeros_like(differs)
        in_box[by : by + bs, bx : bx + bs] = True
        in_pop = np.zeros_like(differs)
        in_pop[p["y"] : p["y"] + p["h"], p["x"] : p["x"] + p["w"]] = True
        in_inner = np.zeros_like(differs)
        in_inner[inner["y"] : inner["y"] + inner["h"], inner["x"] : inner["x"] + inner["w"]] = True
        label = f"{scheme} {name} ({kind}, page {page}{', pressed in' if focused else ''})"
        stray = differs & in_inner & ~in_box & ~in_pop
        check(not stray.any(), f"{label}: nothing in the padding or the gap ({int(stray.sum())} px)")
        icon = np.argwhere(differs & in_box)
        mark = np.argwhere(differs & in_pop)
        check(len(icon) > 0, f"{label}: the icon draws")
        check(len(mark) > 0, f"{label}: the ▴ draws")
        clear = gap(icon, mark)
        check(clear is not None and clear >= plan["MIN_POP_GAP"], f"{label}: {clear} px between the icon and the ▴")
        entry = {"kind": kind, "face": list(face), "gap": clear}
        # 1:1: the canvas shows a token PNG composited on the face, unscaled.
        refs = reference(name, kind, scheme)
        shown = tile[cy : cy + canvas, cx : cx + canvas]
        matched = None
        if refs is not None and page == 1:
            best = None
            for r in refs:
                if r.size != (canvas, canvas):
                    continue
                over = Image.new("RGBA", r.size, face + (255,))
                over.alpha_composite(r)
                want = np.array(over.convert("RGB")).astype(int)
                worst = int(np.abs(want - shown).max())
                if best is None or worst < best:
                    best, matched = worst, r
            check(best is not None and best <= 1, f"{label}: the token is drawn 1:1 on its {canvas} px canvas (max channel error {best})")
            entry["oneToOne"] = best
            if best is None or best > 1:
                matched = None
        if len(icon):
            top, left = icon.min(axis=0)
            bottom, right = icon.max(axis=0)
            # What differs from the face. A black outline on a black face
            # (the black scheme) does not show, so this can be smaller.
            entry["visible"] = [int(right - left + 1), int(bottom - top + 1)]
            if matched is not None:
                # The token's opaque bounds, where the 1:1 match put them.
                l, t, r, b = matched.getchannel("A").getbbox()
                left, top, right, bottom = cx + l, cy + t, cx + r - 1, cy + b - 1
            entry["iconBox"] = [int(left), int(top), int(right) + 1, int(bottom) + 1]
            entry["size"] = [int(right - left + 1), int(bottom - top + 1)]
            # Padding at rest: a pressed-in icon is one px further from the
            # top and left, one nearer the bottom.
            entry["padding"] = {
                "left": int(left - inner["x"]) - press,
                "top": int(top - inner["y"]) - press,
                "bottom": int(inner["y"] + inner["h"] - 1 - bottom) + press,
                "toPop": int(mark[:, 1].min() - right - 1) + press if len(mark) else None,
            }
            if kind != "letter":
                longest = max(entry["size"])
                check(extent - 1 <= longest <= extent, f"{label}: opaque bounds {entry['size'][0]} x {entry['size'][1]}, {extent} px on the longest side (±1); visible {entry['visible'][0]} x {entry['visible'][1]}")
                pads = entry["padding"]
                for side in ("left", "top", "bottom"):
                    want = g["pad"] + (bs - entry["size"][0 if side == "left" else 1]) // 2
                    check(abs(pads[side] - want) <= 1, f"{label}: {pads[side]} px from the bevel on the {side}, want {want} (±1)")
                optical.append((label, entry["size"], pads))
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
        # 8x inspection copy: the box (green), the canvas (blue), the ▴ (red).
        crop = Image.fromarray(tile.astype(np.uint8)).resize((g["w"] * 8, g["h"] * 8), Image.NEAREST)
        draw = ImageDraw.Draw(crop)
        draw.rectangle((cx * 8, cy * 8, (cx + canvas) * 8 - 1, (cy + canvas) * 8 - 1), outline=(0, 90, 255))
        draw.rectangle((bx * 8, by * 8, (bx + bs) * 8 - 1, (by + bs) * 8 - 1), outline=(0, 200, 0))
        draw.rectangle((p["x"] * 8, p["y"] * 8, (p["x"] + p["w"]) * 8 - 1, (p["y"] + p["h"]) * 8 - 1), outline=(220, 0, 0))
        zoom_tiles.append(crop)
    sheet = Image.new("RGB", (sum(t.width for t in zoom_tiles) + 8 * (len(zoom_tiles) - 1), zoom_tiles[0].height), (255, 0, 255))
    x = 0
    for t in zoom_tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 8
    sheet.save(out / f"tiles-{scheme}-8x.png")

# One optical size: across every tile with an icon, in every scheme, the
# opaque size and the padding to the bevel agree to 1 px.
if optical:
    longest = [max(size) for _, size, _ in optical]
    check(max(longest) - min(longest) <= 1, f"one optical size: longest side {min(longest)}..{max(longest)} px over {len(optical)} tiles")
    for side in ("left", "top", "bottom"):
        values = [pads[side] for _, _, pads in optical]
        check(max(values) - min(values) <= 1, f"one padding: {side} {min(values)}..{max(values)} px over {len(optical)} tiles")
    gaps = [pads["toPop"] for _, _, pads in optical if pads["toPop"] is not None]
    results["optical"] = {
        "extent": extent,
        "longest": [min(longest), max(longest)],
        "padding": {side: [min(p[side] for _, _, p in optical), max(p[side] for _, _, p in optical)] for side in ("left", "top", "bottom")},
        "toPop": [min(gaps), max(gaps)] if gaps else None,
    }

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
