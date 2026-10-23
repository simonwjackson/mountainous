"""Build "W95FA Grid": W95FA 1.002 (SIL OFL 1.1) moved onto its own pixel grid.

W95FA draws MS Sans Serif's pixels as 80-unit squares (upm 1000), but every
outline starts 50 units in and every advance is 20 units longer than a whole
pixel, and the ascent/descent are not whole pixels. So no font size puts its
pixels on the screen's pixels. This script:
  - snaps every point to the 80-unit grid with the left edge at 0;
  - trims each advance by 20 units, so advances are whole pixels;
  - sets ascent 800 (10 px) and descent 240 (3 px): a 13-px line with the
    baseline 10 px down, MS Sans Serif's 8 pt cell;
  - adds the glyphs the bar needs that W95FA lacks, drawn as pixels:
    U+2026 (three dots), U+00B7, U+2013, U+2014, U+2190..U+2193, U+00D7.
At font-size 12.5 u one font pixel is exactly 1 u = 2 physical px.
The OFL allows modified versions; the name changes so it cannot be mistaken
for the original. W95FA declares no Reserved Font Name.
"""

import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

SRC, OUT = sys.argv[1], sys.argv[2]
P = 80
src = TTFont(SRC)
cs = src["CFF "].cff.topDictIndex[0].CharStrings
hm = src["hmtx"]
cmap = src.getBestCmap()
order = src.getGlyphOrder()


def snap(v, off=0):
    return round((v - off) / P) * P


glyphs, metrics, bad = {}, {}, []
for g in order:
    rec = RecordingPen()
    cs[g].draw(rec)
    pen = TTGlyphPen(None)
    for op, pts in rec.value:
        if op == "moveTo":
            pen.moveTo(next((snap(x, 50), snap(y)) for x, y in pts))
        elif op == "lineTo":
            pen.lineTo(next((snap(x, 50), snap(y)) for x, y in pts))
        elif op == "closePath":
            pen.closePath()
        elif op == "endPath":
            pen.endPath()
        else:
            # The supplied reference omits cubic segments. Keep its outlines,
            # including that limitation, rather than changing the coming theme.
            bad.append((g, op))
    glyphs[g] = pen.glyph()
    adv = hm[g][0]
    a2 = adv - 20 if adv >= 20 else adv
    if a2 % P:
        a2 = snap(a2)
    metrics[g] = (a2, 0)

if bad:
    print("non-line segments omitted to match reference:", bad[:5])


def pixels(rows, name):
    """rows: strings of '#' and '.', top row first; baseline under the last row unless a row is '-'."""
    pen = TTGlyphPen(None)
    base = len(rows)
    for i, r in enumerate(rows):
        if r.startswith("-"):
            base = i
            break
    rows = [r for r in rows if not r.startswith("-")]
    width = max(len(r) for r in rows)
    for i, r in enumerate(rows):
        y = (base - 1 - i) * P
        for j, c in enumerate(r):
            if c == "#":
                x = j * P
                pen.moveTo((x, y))
                pen.lineTo((x, y + P))
                pen.lineTo((x + P, y + P))
                pen.lineTo((x + P, y))
                pen.closePath()
    glyphs[name] = pen.glyph()
    metrics[name] = ((width + 1) * P, 0)


# Keep the final pixel rows from the mock reference, without its superseded drafts.
extra = {
    0x2026: ("ellipsis", ["#.#.#"]),
    0x00B7: ("periodcentered", ["#", ".", "."]),
    0x2013: ("endash", ["#####", ".", ".", "."]),
    0x2014: ("emdash", ["##########", ".", ".", "."]),
    0x2190: ("arrowleft", ["..#....", ".##....", "#######", ".##....", "..#....", "."]),
    0x2192: (
        "arrowright",
        ["....#..", "....##.", "#######", "....##.", "....#..", "."],
    ),
    0x2191: (
        "arrowup",
        ["..#..", ".###.", "#####", "..#..", "..#..", "..#..", "..#.."],
    ),
    0x2193: (
        "arrowdown",
        ["..#..", "..#..", "..#..", "..#..", "#####", ".###.", "..#.."],
    ),
    0x00D7: ("multiply", ["#...#", ".#.#.", "..#..", ".#.#.", "#...#", "."]),
}
newmap = dict(cmap)
for cp, (name, rows) in extra.items():
    if cp in cmap:
        continue
    pixels(rows, name)
    newmap[cp] = name
    order.append(name)

metrics["space"] = (
    3 * P,
    0,
)  # MS Sans Serif 8 pt: a 3-px space (inferred from the Win95 strip)
fb = FontBuilder(1000, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap(newmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=800, descent=-240, lineGap=0)
fb.setupNameTable(
    {
        "familyName": "W95FA Grid",
        "styleName": "Regular",
        "uniqueFontIdentifier": "W95FA Grid 1.002-grid1",
        "fullName": "W95FA Grid",
        "psName": "W95FAGrid-Regular",
        "version": "Version 1.002-grid1",
        "copyright": "W95FA by Alina Sava / FontsArena (SIL OFL 1.1). Grid fix and added glyphs: win98-mock, 2026.",
        "licenseDescription": "This Font Software is licensed under the SIL Open Font License, Version 1.1.",
        "licenseInfoURL": "https://openfontlicense.org",
    }
)
fb.setupOS2(
    sTypoAscender=800,
    sTypoDescender=-240,
    sTypoLineGap=0,
    usWinAscent=800,
    usWinDescent=240,
    sxHeight=480,
    sCapHeight=720,
    fsSelection=0x40 | 0x80,
    achVendID="NONE",
)
fb.setupPost()
fb.setupHead(unitsPerEm=1000)
fb.save(OUT)
print("wrote", OUT, len(order), "glyphs")
