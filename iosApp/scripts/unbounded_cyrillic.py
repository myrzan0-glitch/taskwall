#!/usr/bin/env python3
"""Builds Orbit's Cyrillic font (Unbounded-Light.ttf) from Unbounded Light.

Orbit's own font, Michroma, has no Cyrillic, so the wallpaper falls back to
Unbounded Light for it. Unbounded covers Russian and Ukrainian but not the
Uzbek letters Ғ Қ Ҳ or Kazakh Ң, so those are built here from Unbounded's own
Г К Х Н with a stem-width descender or crossbar, and Kazakh letters that share
a shape with a Latin one point at that glyph. Only Cyrillic ships.

Run from the repository root with fontTools installed, passing Unbounded Light
from Google Fonts (static, weight 300):

    python3 iosApp/scripts/unbounded_cyrillic.py Unbounded-Light-full.ttf
"""

import sys

from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

OUT = "iosApp/TaskWall/Resources/Fonts/Unbounded-Light.ttf"

STEM = 94           # Unbounded Light's vertical stem, from І
DESCENDER = {True: 155, False: 146}  # Ц and ц go this far below the baseline

# New letter: (base letter, what to add, capital?)
BUILT = {
    "Қ": ("К", "descender", True), "қ": ("к", "descender", False),
    "Ҳ": ("Х", "descender", True), "ҳ": ("х", "descender", False),
    "Ң": ("Н", "descender", True), "ң": ("н", "descender", False),
    "Ғ": ("Г", "crossbar", True), "ғ": ("г", "crossbar", False),
}

# Kazakh letters drawn the same as a glyph Unbounded already has.
SAME_AS = {"Ә": "Ə", "ә": "ə", "Ө": "Ɵ", "ө": "ɵ", "Ү": "Y", "Һ": "h", "һ": "h"}

CYRILLIC = "U+0400-052F,U+02BB-02BC"


def rectangle(pen, x0, y0, x1, y1):
    # Clockwise, as TrueType draws outer contours.
    pen.moveTo((x0, y0))
    pen.lineTo((x0, y1))
    pen.lineTo((x1, y1))
    pen.lineTo((x1, y0))
    pen.closePath()


def main(source):
    font = TTFont(source)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    glyf, hmtx = font["glyf"], font["hmtx"]
    order = font.getGlyphOrder()
    tables = [t for t in font["cmap"].tables if t.isUnicode()]
    cap, x_height = font["OS/2"].sCapHeight, font["OS/2"].sxHeight

    for char, (base, addition, capital) in BUILT.items():
        base_name = cmap[ord(base)]
        base_glyph = glyf[base_name]
        base_glyph.recalcBounds(glyf)
        pen = TTGlyphPen(glyphs)
        glyphs[base_name].draw(pen)
        if addition == "descender":
            right = base_glyph.xMax
            rectangle(pen, right - STEM, -DESCENDER[capital], right, STEM // 2)
        else:
            height = cap if capital else x_height
            middle = round(height * 0.45)
            left = base_glyph.xMin
            rectangle(pen, max(left - 70, 0), middle - STEM // 2, left + round(height * 0.42), middle + STEM // 2)
        name = f"uni{ord(char):04X}"
        glyf[name] = pen.glyph()
        glyf[name].recalcBounds(glyf)
        hmtx[name] = (hmtx[base_name][0], glyf[name].xMin)
        if name not in order:
            order.append(name)
        for table in tables:
            table.cmap[ord(char)] = name

    for char, latin in SAME_AS.items():
        for table in tables:
            table.cmap[ord(char)] = cmap[ord(latin)]

    font.setGlyphOrder(order)
    options = subset.Options()
    options.layout_features = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=subset.parse_unicodes(CYRILLIC))
    subsetter.subset(font)
    font.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main(sys.argv[1])
