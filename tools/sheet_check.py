# -*- coding: utf-8 -*-
"""Contact sheet: for each stem, [aiart_src/ref | resources/icons | resources/edited]."""
import os
from PIL import Image, ImageDraw

BASE = r"D:\DSH\Bromeme\aiart_src"
MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
OUT = r"D:\DSH\_aitato_work\sheet_check.png"

STEMS = [
    ("1760863546", "LJF/longjuanfeng"),
    ("1761130691", "FHL/fenghuolun"),
    ("1784872500", "NW/naiwa"),
    ("1765220738", "LWY/liwenya"),
    ("1763088849", "zhongzhi"),
    ("1760709365", "zhou"),
    ("1763096950", "beishang"),
]
CELL = 220


def load(p):
    if not os.path.isfile(p):
        return None
    im = Image.open(p).convert("RGBA")
    im.thumbnail((CELL - 24, CELL - 24), Image.LANCZOS)
    return im


rows = []
for stem, label in STEMS:
    rows.append((stem, label, [
        ("ref", os.path.join(BASE, "ref", stem + ".png")),
        ("icons", os.path.join(MOD, "icons", stem + ".png")),
        ("edited", os.path.join(MOD, "edited", stem + ".png")),
        ("edited.body", os.path.join(MOD, "edited", stem + ".body.png")),
    ]))

cols = ["ref", "icons", "edited", "edited.body"]
W = CELL * len(cols)
H = CELL * len(rows)
sheet = Image.new("RGBA", (W, H), (235, 235, 235, 255))
d = ImageDraw.Draw(sheet)
for r, (stem, label, cells) in enumerate(rows):
    for c, (name, path) in enumerate(cells):
        im = load(path)
        if im is None:
            d.text((c * CELL + 8, r * CELL + 8), "MISSING", fill=(200, 0, 0, 255))
        else:
            sheet.paste(im, (c * CELL + (CELL - im.size[0]) // 2,
                             r * CELL + (CELL - im.size[1]) // 2 + 10), im)
        d.text((c * CELL + 6, r * CELL + 6), "%s %s" % (stem, name), fill=(20, 20, 20, 255))
        d.text((c * CELL + 6, r * CELL + CELL - 16), label, fill=(90, 90, 90, 255))
sheet.convert("RGB").save(OUT, quality=92)
print(OUT, sheet.size)
