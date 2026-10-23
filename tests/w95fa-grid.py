"""Check the installed W95FA Grid font; optionally compare the mock reference."""

import argparse

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont


def check_font(font: TTFont) -> None:
    assert font["name"].getDebugName(1) == "W95FA Grid"
    assert font["name"].getDebugName(6) == "W95FAGrid-Regular"
    cmap = font.getBestCmap()
    required = {0x2026, 0x00B7, 0x2013, 0x2014, *range(0x2190, 0x2194), 0x00D7}
    assert required <= cmap.keys(), f"missing glyphs: {required - cmap.keys()}"
    for codepoint in required:
        glyph = font["glyf"][cmap[codepoint]]
        assert glyph.numberOfContours > 0, f"empty glyph U+{codepoint:04X}"
    for name in font.getGlyphOrder():
        points, _, _ = font["glyf"][name].getCoordinates(font["glyf"])
        assert all(x % 80 == 0 and y % 80 == 0 for x, y in points), name
        assert font["hmtx"][name][0] % 80 == 0, f"off-grid advance: {name}"
    assert font["head"].unitsPerEm == 1000
    assert (font["hhea"].ascent, font["hhea"].descent, font["hhea"].lineGap) == (
        800,
        -240,
        0,
    )
    os2 = font["OS/2"]
    assert (os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap) == (800, -240, 0)
    assert (os2.usWinAscent, os2.usWinDescent) == (800, 240)
    assert font["hmtx"]["space"] == (240, 0)


def compare_reference(font: TTFont, reference: TTFont) -> None:
    assert font.getBestCmap() == reference.getBestCmap(), "cmap differs"
    assert font.getGlyphOrder() == reference.getGlyphOrder(), "glyph order differs"
    assert font["hmtx"].metrics == reference["hmtx"].metrics, "metrics differ"
    glyphs = font.getGlyphSet()
    expected = reference.getGlyphSet()
    for name in font.getGlyphOrder():
        actual_pen, expected_pen = RecordingPen(), RecordingPen()
        glyphs[name].draw(actual_pen)
        expected[name].draw(expected_pen)
        assert actual_pen.value == expected_pen.value, f"outline differs: {name}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("font")
    parser.add_argument("--reference")
    args = parser.parse_args()
    with TTFont(args.font) as font:
        check_font(font)
        if args.reference:
            with TTFont(args.reference) as reference:
                check_font(reference)
                compare_reference(font, reference)
        print(f"checked {len(font.getGlyphOrder())} glyphs: {args.font}")


if __name__ == "__main__":
    main()
