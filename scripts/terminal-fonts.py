"""Build terminal faces without changing the desktop's proportional UI fonts.

ProFontIIx's 9ppem Macintosh bitmap strike becomes scalable square outlines.
Fixedsys already has square outlines; repair its invalid BMP cmap entries.
Both derivatives keep upstream licences and get explicit fixed-pitch metadata.
"""

import argparse

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable


def profont(source, target):
    original = TTFont(source)
    # Apple bloc/bdat use the EBLC/EBDT wire format.
    for apple, opentype in (("bloc", "EBLC"), ("bdat", "EBDT")):
        original[opentype] = newTable(opentype)
        original[opentype].decompile(original[apple].data, original)
    index = next(
        i
        for i, strike in enumerate(original["EBLC"].strikes)
        if strike.bitmapSizeTable.ppemY == 9
    )
    strike = original["EBLC"].strikes[index]
    bitmaps = original["EBDT"].strikeData[index]
    glyphs, metrics = {}, {}
    for name in original.getGlyphOrder():
        pen = TTGlyphPen(None)
        if name in bitmaps:
            bitmap = bitmaps[name]
            subtable = next(t for t in strike.indexSubTables if name in t.names)
            metric = subtable.metrics if bitmap.getFormat() == 5 else bitmap.metrics
            left = getattr(metric, "BearingX", getattr(metric, "horiBearingX", 0))
            top = getattr(metric, "BearingY", getattr(metric, "horiBearingY", 0))
            for y in range(metric.height):
                row = bitmap.getRow(y, bitDepth=1, metrics=metric)
                for x in range(metric.width):
                    if row[x // 8] & (0x80 >> (x % 8)):
                        x0, y0 = (left + x) * 300, (top - y - 1) * 300
                        pen.moveTo((x0, y0))
                        pen.lineTo((x0 + 300, y0))
                        pen.lineTo((x0 + 300, y0 + 300))
                        pen.lineTo((x0, y0 + 300))
                        pen.closePath()
        glyphs[name] = pen.glyph()
        metrics[name] = (
            1800,
            min((x for x, _ in getattr(glyphs[name], "coordinates", [])), default=0),
        )
    builder = FontBuilder(2700, isTTF=True)
    builder.setupGlyphOrder(original.getGlyphOrder())
    builder.setupCharacterMap(original.getBestCmap())
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=2700, descent=-600, lineGap=0)
    builder.setupNameTable(
        {
            "familyName": "ProFontIIx Grid",
            "styleName": "Regular",
            "uniqueFontIdentifier": "Mountainous ProFontIIx Grid 1",
            "fullName": "ProFontIIx Grid",
            "psName": "ProFontIIxGrid",
            "version": "Version 1.0",
            "copyright": "Copyright (c) 2014 Tobias Jung, Carl Osterwald, Stephen C. Gilardi, Andrew Welch. MIT License. Bitmap-outline derivative by Mountainous.",
        }
    )
    builder.setupOS2(
        sTypoAscender=2700,
        sTypoDescender=-600,
        sTypoLineGap=0,
        usWinAscent=2700,
        usWinDescent=600,
    )
    builder.setupPost(isFixedPitch=1)
    builder.save(target)


def fixedsys(source, target):
    font = TTFont()
    font.importXML(source)
    for table in font["cmap"].tables:
        if table.format == 4:
            # Format 4 cannot encode the non-BMP ligature PUA entries.
            # Their valid format 12 mappings remain intact.
            table.cmap = {k: v for k, v in table.cmap.items() if k <= 0xFFFF}
    font["post"].isFixedPitch = 1
    font.save(target)


def bold(source, target, pixel):
    """A one-device-pixel strike at the chosen size; keep counters and advance."""
    font = TTFont(source)
    glyph_set = font.getGlyphSet()
    outlines = {}
    for name in font.getGlyphOrder():
        record = DecomposingRecordingPen(glyph_set)
        glyph_set[name].draw(record)
        pen = TTGlyphPen(None)
        record.replay(pen)
        advance = font["hmtx"][name][0]
        for operation, points in record.value:
            shifted = tuple(
                None if point is None else (min(point[0] + pixel, advance), point[1])
                for point in points
            )
            getattr(pen, operation)(*shifted)
        outlines[name] = pen.glyph()
    for name, glyph in outlines.items():
        font["glyf"][name] = glyph
    family = font["name"].getDebugName(1)
    for record in font["name"].names:
        value = {
            2: "Bold",
            4: family + " Bold",
            6: family.replace(" ", "") + "-Bold",
            17: "Bold",
        }.get(record.nameID)
        if value:
            record.string = value.encode(record.getEncoding())
    font["OS/2"].usWeightClass = 700
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~64) | 32
    font["head"].macStyle |= 1
    font.save(target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("face", choices=("profont", "fixedsys"))
    parser.add_argument("source")
    parser.add_argument("target")
    args = parser.parse_args()
    {"profont": profont, "fixedsys": fixedsys}[args.face](args.source, args.target)
    bold(
        args.target,
        args.target.replace(".ttf", "-Bold.ttf"),
        100 if args.face == "profont" else 5,
    )
