# -*- coding: utf-8 -*-
"""对比：ref 原图 / 旧 AI 版（2.17.1 备份） / 新白色版。"""
import os
from PIL import Image, ImageDraw

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BAK = r"D:\DSH\_mod_backups\Bromeme-2.17.1\files\resources"
REF = r"D:\DSH\Bromeme\aiart_src\ref"

ROWS = [
    ("1763088849", "zhongzhi"),
    ("1760709365", "zhou"),
    ("1763096950", "beishang"),
    ("1760863546", "LJF"),
    ("1761130691", "FHL"),
    ("1784872500", "naiwa"),
    ("1765220738", "LWY"),
]
COLS = [
    ("ref/orig", lambda s: os.path.join(REF, s + ".png")),
    ("old AI", lambda s: os.path.join(BAK, "edited", s + ".png") if os.path.isfile(os.path.join(BAK, "edited", s + ".png")) else os.path.join(BAK, "icons", s + ".png")),
    ("new", lambda s: os.path.join(MOD, "edited", s + ".png") if os.path.isfile(os.path.join(MOD, "edited", s + ".png")) else os.path.join(MOD, "icons", s + ".png")),
]
CELL = 200
sheet = Image.new("RGB", (CELL * len(COLS), CELL * len(ROWS) + 16), (120, 60, 40))
d = ImageDraw.Draw(sheet)
for r, (stem, label) in enumerate(ROWS):
    for c, (name, fn) in enumerate(COLS):
        p = fn(stem)
        box = (c * CELL, r * CELL + 16, c * CELL + CELL, r * CELL + CELL + 16)
        if os.path.isfile(p):
            im = Image.open(p).convert("RGBA")
            im.thumbnail((CELL - 8, CELL - 8), Image.LANCZOS)
            sheet.paste(im, (box[0] + (CELL - im.size[0]) // 2, box[1] + (CELL - im.size[1]) // 2), im)
        else:
            d.text((box[0] + 6, box[1] + 6), "MISSING", fill=(255, 255, 0))
        d.text((box[0] + 5, r * CELL + 3), "%s %s" % (label, name), fill=(255, 255, 255))
sheet.save(r"D:\DSH\_aitato_work\sheet_after.png")
print("ok", sheet.size)
