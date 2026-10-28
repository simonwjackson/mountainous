"""Check actual installed glyphs, metrics and the scale-1.5 terminal grid."""

import sys
from pathlib import Path

from fontTools.ttLib import TTFont

for file, family, physical_size, pixel in (
    ("Fixedsys.ttf", "Fixedsys Excelsior", 32, 10),
    ("ProFontIIxGrid.ttf", "ProFontIIx Grid", 27, 300),
):
    font = TTFont(Path(sys.argv[1]) / file)
    assert font["name"].getDebugName(1) == family
    cmap = font.getBestCmap()
    advances = {font["hmtx"][cmap[c]][0] for c in range(32, 127)}
    assert len(advances) == 1, advances
    (advance,) = advances
    upm = font["head"].unitsPerEm
    assert advance * physical_size % upm == 0
    assert pixel * physical_size % upm == 0
    for c in range(33, 127):
        glyph = font["glyf"][cmap[c]]
        assert glyph.numberOfContours > 0
        points, _, _ = glyph.getCoordinates(font["glyf"])
        assert all(x % pixel == 0 and y % pixel == 0 for x, y in points)
        assert glyph.xMax <= advance, (family, chr(c), glyph.xMax, advance)
    assert font["post"].isFixedPitch == 1
    bold = TTFont(Path(sys.argv[1]) / file.replace(".ttf", "-Bold.ttf"))
    assert bold["OS/2"].usWeightClass == 700
    assert bold["name"].getDebugName(2) == "Bold"
    # A whole source-pixel strike closes the small M/W counters. Bold adds
    # exactly one device pixel at this size, not two or three.
    stem = cmap[ord("i")]
    assert (bold["glyf"][stem].xMax - font["glyf"][stem].xMax) * physical_size == upm
    for c in range(33, 127):
        name = cmap[c]
        assert bold["hmtx"][name] == font["hmtx"][name]
        points, _, _ = bold["glyf"][name].getCoordinates(bold["glyf"])
        assert all(
            x * physical_size % upm == 0 and y * physical_size % upm == 0
            for x, y in points
        )
        assert bold["glyf"][name].xMax <= advance
    print(
        f"{family}: {len(cmap)} codepoints; {advance * physical_size // upm}px cell = advance; ASCII on grid"
    )
# Ghostty draws U+2500..259F (box/block) itself; no font fallback seams.
# The native-config check validates the installed DejaVu/Symbols fallback chain.

# Installed fallbacks, not names assumed from a package description.
unicode_font, icons = (TTFont(path) for path in sys.argv[2:])
assert {ord(c) for c in "λ→éЖ"} <= unicode_font.getBestCmap().keys()
assert {0xE0B0, 0xE0A0, 0xF120, 0xF018D} <= icons.getBestCmap().keys()
print("DejaVu Unicode and Nerd prompt/tool icon coverage: PASS")
