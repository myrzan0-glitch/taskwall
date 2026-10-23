#!/usr/bin/env python3
"""Builds Grace's font (CormorantGaramond-MediumItalic.ttf) from Cormorant Garamond.

Grace is Cormorant Garamond Medium Italic. The full font also carries Greek and
Vietnamese; the wallpaper keeps Latin, Cyrillic (with the Kazakh and Uzbek
letters, which Cormorant already has), punctuation and the symbols tasks use.

Run from the repository root with fontTools installed, passing the static
Medium Italic (weight 500) from Google Fonts:

    python3 iosApp/scripts/cormorant_subset.py CormorantGaramond-MediumItalic-full.ttf
"""

import sys

from fontTools import subset
from fontTools.ttLib import TTFont

OUT = "iosApp/TaskWall/Resources/Fonts/CormorantGaramond-MediumItalic.ttf"

UNICODES = (
    list(range(0x20, 0x250))        # Basic Latin to Latin Extended-B
    + list(range(0x300, 0x370))     # combining accents
    + list(range(0x400, 0x530))     # Cyrillic and Cyrillic Supplement
    + list(range(0x1E00, 0x1F00))   # Latin Extended Additional
    + list(range(0x2000, 0x2070))   # punctuation: dashes, quotes, ellipsis
    + list(range(0x20A0, 0x20D0))   # currency
    + [0x2116, 0x2122, 0x2190, 0x2192, 0x2212]
)


def main(source):
    font = TTFont(source)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(font)
    font.save(OUT)


if __name__ == "__main__":
    main(sys.argv[1])
