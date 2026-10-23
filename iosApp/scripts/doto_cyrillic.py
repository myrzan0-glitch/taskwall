#!/usr/bin/env python3
"""Adds Cyrillic to the Matrix font (DotoRounded-Black.ttf).

Doto has no Cyrillic, so a task written in Russian, Uzbek, Kazakh or Ukrainian
fell back to a system font in the middle of the dot-matrix list. Doto is a
5x7 dot matrix (dots 100 units apart, capitals on rows 0-6, lowercase on 0-4,
descenders on -1 and -2), so the Cyrillic letters below are drawn on the same
grid with Doto's own dot. Letters that look like Latin ones reuse Doto's dots.

Run from the repository root with fontTools installed:

    python3 iosApp/scripts/doto_cyrillic.py

It rewrites the font in place and is safe to run again.
"""

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

FONT = "iosApp/TaskWall/Resources/Fonts/DotoRounded-Black.ttf"

# Letters drawn the same as a Latin letter in Doto.
SAME_AS = {
    "А": "A", "В": "B", "Е": "E", "Ё": "Ë", "К": "K", "М": "M", "Н": "H", "О": "O",
    "Р": "P", "С": "C", "Т": "T", "Х": "X", "Ү": "Y", "І": "I", "Ј": "J", "Ѕ": "S",
    "а": "a", "е": "e", "ё": "ë", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x",
    "һ": "h", "і": "i", "ї": "ï", "ј": "j", "ѕ": "s",
}

# The rest, top row first. Each entry is (top row, rows); "#" is a dot.
CAP, LOW = 6, 4
DRAWN = {
    "Б": (CAP, ["#####", "#....", "#....", "####.", "#...#", "#...#", "####."]),
    "Г": (CAP, ["#####", "#....", "#....", "#....", "#....", "#....", "#...."]),
    "Ґ": (7, ["....#", "#####", "#....", "#....", "#....", "#....", "#....", "#...."]),
    "Ғ": (CAP, ["#####", "#....", "#....", "###..", "#....", "#....", "#...."]),
    "Д": (CAP, [".###.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"]),
    "Є": (CAP, [".###.", "#...#", "#....", "####.", "#....", "#...#", ".###."]),
    "Ж": (CAP, ["#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "#.#.#"]),
    "З": (CAP, [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."]),
    "И": (CAP, ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"]),
    "Й": (8, ["#...#", ".###.", "#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"]),
    "Ї": (7, [".#.#.", ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."]),
    "Қ": (CAP, ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#", "....#"]),
    "Л": (CAP, [".####", ".#..#", ".#..#", ".#..#", ".#..#", ".#..#", "#...#"]),
    "Ң": (CAP, ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#", "....#"]),
    "Ө": (CAP, [".###.", "#...#", "#...#", "#####", "#...#", "#...#", ".###."]),
    "П": (CAP, ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"]),
    "У": (CAP, ["#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."]),
    "Ў": (8, ["#...#", ".###.", "#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."]),
    "Ұ": (CAP, ["#...#", "#...#", ".#.#.", "..#..", "#####", "..#..", "..#.."]),
    "Ф": (CAP, ["..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#.."]),
    "Ҳ": (CAP, ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#", "....#"]),
    "Ц": (CAP, ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#####", "....#"]),
    "Ч": (CAP, ["#...#", "#...#", "#...#", ".####", "....#", "....#", "....#"]),
    "Ш": (CAP, ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"]),
    "Щ": (CAP, ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####", "....#"]),
    "Ъ": (CAP, ["##...", ".#...", ".#...", ".###.", ".#..#", ".#..#", ".###."]),
    "Ы": (CAP, ["#...#", "#...#", "#...#", "##..#", "#.#.#", "#.#.#", "##..#"]),
    "Ь": (CAP, ["#....", "#....", "#....", "####.", "#...#", "#...#", "####."]),
    "Э": (CAP, [".###.", "#...#", "....#", "..###", "....#", "#...#", ".###."]),
    "Ю": (CAP, ["#..#.", "#.#.#", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."]),
    "Я": (CAP, [".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"]),
    "Ә": (CAP, [".###.", "#...#", "....#", "#####", "#...#", "#...#", ".###."]),
    "б": (CAP, ["..###", ".#...", "#....", "####.", "#...#", "#...#", ".###."]),
    "в": (LOW, ["####.", "#...#", "####.", "#...#", "####."]),
    "г": (LOW, ["#####", "#....", "#....", "#....", "#...."]),
    "ґ": (5, ["....#", "#####", "#....", "#....", "#....", "#...."]),
    "ғ": (LOW, ["#####", "#....", "###..", "#....", "#...."]),
    "д": (LOW, [".###.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"]),
    "є": (LOW, [".###.", "#....", "####.", "#....", ".###."]),
    "ж": (LOW, ["#.#.#", ".###.", "..#..", ".###.", "#.#.#"]),
    "з": (LOW, ["####.", "....#", ".###.", "....#", "####."]),
    "и": (LOW, ["#...#", "#..##", "#.#.#", "##..#", "#...#"]),
    "й": (7, ["#...#", ".###.", ".....", "#...#", "#..##", "#.#.#", "##..#", "#...#"]),
    "к": (LOW, ["#...#", "#..#.", "###..", "#..#.", "#...#"]),
    "қ": (LOW, ["#...#", "#..#.", "###..", "#..#.", "#...#", "....#"]),
    "л": (LOW, [".####", ".#..#", ".#..#", ".#..#", "#...#"]),
    "м": (LOW, ["#...#", "##.##", "#.#.#", "#...#", "#...#"]),
    "н": (LOW, ["#...#", "#...#", "#####", "#...#", "#...#"]),
    "ң": (LOW, ["#...#", "#...#", "#####", "#...#", "#...#", "....#"]),
    "ө": (LOW, [".###.", "#...#", "#####", "#...#", ".###."]),
    "п": (LOW, ["#####", "#...#", "#...#", "#...#", "#...#"]),
    "т": (LOW, ["#####", "..#..", "..#..", "..#..", "..#.."]),
    "ў": (7, ["#...#", ".###.", ".....", "#...#", "#...#", "#..##", ".##.#", "....#", "#...#", ".###."]),
    "ү": (LOW, ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#.."]),
    "ұ": (LOW, ["#...#", ".#.#.", "..#..", "#####", "..#..", "..#.."]),
    "ф": (5, ["..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#.."]),
    "ҳ": (LOW, ["#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....#"]),
    "ц": (LOW, ["#...#", "#...#", "#...#", "#...#", "#####", "....#"]),
    "ч": (LOW, ["#...#", "#...#", ".####", "....#", "....#"]),
    "ш": (LOW, ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"]),
    "щ": (LOW, ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####", "....#"]),
    "ъ": (LOW, ["##...", ".#...", ".###.", ".#..#", ".###."]),
    "ы": (LOW, ["#...#", "#...#", "##..#", "#.#.#", "##..#"]),
    "ь": (LOW, ["#....", "#....", "####.", "#...#", "####."]),
    "э": (LOW, [".###.", "#...#", "..###", "#...#", ".###."]),
    "ю": (LOW, ["#..#.", "#.#.#", "###.#", "#.#.#", "#..#."]),
    "я": (LOW, [".####", "#...#", ".####", ".#..#", "#...#"]),
    "ә": (LOW, [".###.", "....#", "#####", "#...#", ".###."]),
}

# Uzbek Latin writes oʻ and gʻ with modifier letters; Doto draws them as quotes.
ALIASES = {0x02BB: 0x2018, 0x02BC: 0x2019}

ADVANCE, PITCH = 600, 100


def dot_contour(font):
    """Doto's dot, centred on the origin, from the period."""
    glyphs = font.getGlyphSet()
    pen = DecomposingRecordingPen(glyphs)
    glyphs[font.getBestCmap()[ord(".")]].draw(pen)
    first = []
    for op, args in pen.value:
        first.append((op, args))
        if op in ("closePath", "endPath"):
            break
    points = [p for _, args in first for p in args if p]
    cx = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
    cy = (min(p[1] for p in points) + max(p[1] for p in points)) / 2
    return first, cx, cy


def cells_of(font, char):
    """The grid cells a Latin glyph's dots sit on."""
    glyphs = font.getGlyphSet()
    pen = DecomposingRecordingPen(glyphs)
    glyphs[font.getBestCmap()[ord(char)]].draw(pen)
    cells, points = [], []
    for op, args in pen.value:
        if op == "moveTo":
            points = [args[0]]
        elif op in ("lineTo", "qCurveTo", "curveTo"):
            points += [a for a in args if a]
        elif op in ("closePath", "endPath"):
            cx = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
            cy = (min(p[1] for p in points) + max(p[1] for p in points)) / 2
            cells.append((round((cx - 50) / PITCH), round((cy - 50) / PITCH)))
    return cells


def cells_from_rows(top, rows):
    return [(col, top - i) for i, row in enumerate(rows) for col, cell in enumerate(row) if cell == "#"]


def glyph_from_cells(cells, dot):
    contour, cx, cy = dot
    pen = TTGlyphPen(None)
    for col, row in sorted(cells):
        shifted = TransformPen(pen, (1, 0, 0, 1, 50 + col * PITCH - cx, 50 + row * PITCH - cy))
        for op, args in contour:
            getattr(shifted, op)(*args)
    return pen.glyph()


def main():
    font = TTFont(FONT)
    dot = dot_contour(font)
    order = font.getGlyphOrder()
    cmap_tables = [t for t in font["cmap"].tables if t.isUnicode()]
    cmap = font.getBestCmap()

    letters = {ch: cells_of(font, latin) for ch, latin in SAME_AS.items()}
    letters.update({ch: cells_from_rows(top, rows) for ch, (top, rows) in DRAWN.items()})

    for ch, cells in letters.items():
        name = f"uni{ord(ch):04X}"
        glyph = glyph_from_cells(cells, dot)
        glyph.recalcBounds(font["glyf"])
        if name not in font["glyf"].glyphs:
            order.append(name)
        font["glyf"][name] = glyph
        font["hmtx"][name] = (ADVANCE, glyph.xMin if glyph.numberOfContours else 0)
        for table in cmap_tables:
            table.cmap[ord(ch)] = name

    for alias, source in ALIASES.items():
        for table in cmap_tables:
            table.cmap[alias] = cmap[source]

    font.setGlyphOrder(order)
    for unused in ("hdmx", "LTSH", "VDMX"):
        if unused in font:
            del font[unused]
    font.save(FONT)
    print(f"Added {len(letters)} Cyrillic letters to {FONT}")


if __name__ == "__main__":
    main()
