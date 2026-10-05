# -*- coding: utf-8 -*-
"""把所有“改前 / 改后”图标拼成一张总览图（含中文名），方便一次性检查。

用法: python make_sheet.py <输出png> [char|item]
"""
import os, sys, importlib.util
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, r"D:\DSH\_aitato_work")
spec = importlib.util.spec_from_file_location("bm", r"D:\DSH\_aitato_work\bromeme_aiart.py")
bm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bm)

FONT = r"C:\Windows\Fonts\msyh.ttc"
INK = (48, 42, 36)
CARD = (255, 255, 255)
BG = (246, 243, 235)

CELL = 116          # 每个图标显示尺寸
PAIR_W = CELL * 2 + 14
LABEL_H = 24
PAD = 14
COLS = 6


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


def checker(size, c=12):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, size, c):
        for x in range(0, size, c):
            if ((x // c) + (y // c)) % 2:
                d.rectangle([x, y, x + c - 1, y + c - 1], fill=(228, 228, 228, 255))
    return im


def tile(path, box, nearest=True):
    im = Image.open(path).convert("RGBA")
    if im.size != (box, box):
        im = im.resize((box, box), Image.NEAREST if nearest else Image.LANCZOS)
    bg = checker(box)
    bg.alpha_composite(im)
    return bg


def main():
    out = sys.argv[1]
    kind_filter = sys.argv[2] if len(sys.argv) > 2 else ""
    rows = [t for t in bm.TARGETS if not kind_filter or t[1] == kind_filter]

    items = []
    for stem, kind, mode, name in rows:
        before = os.path.join(bm.REF, stem + ".png")
        after = os.path.join(bm.EDITED, stem + ".png")
        if os.path.isfile(before) and os.path.isfile(after):
            items.append((name, kind, mode, before, after))

    cols = COLS
    nrows = (len(items) + cols - 1) // cols
    cw = PAIR_W + PAD
    ch = CELL + LABEL_H + PAD
    W = PAD + cw * cols
    H = PAD + ch * nrows
    canvas = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    f = font(15)
    fs = font(12)

    for i, (name, kind, mode, before, after) in enumerate(items):
        r, c = divmod(i, cols)
        x = PAD + c * cw
        y = PAD + r * ch
        d.rectangle([x - 4, y - 4, x + PAIR_W + 6, y + CELL + LABEL_H + 2], fill=CARD)
        canvas.alpha_composite(tile(before, CELL), (x, y))
        canvas.alpha_composite(tile(after, CELL), (x + CELL + 14, y))
        d.text((x + 2, y + CELL + 3), "改前", font=fs, fill=(150, 140, 130))
        d.text((x + CELL + 16, y + CELL + 3), "改后", font=fs, fill=(150, 140, 130))
        tag = {"head": "真人·头", "normal": "常规"}[mode]
        d.text((x + CELL * 2 - 78, y + CELL + 3), tag, font=fs, fill=(170, 120, 90))
        d.text((x + CELL + 14 + CELL - 74, y + 2), "AI重绘", font=fs, fill=(120, 170, 120))
        d.text((x + 2, y + 2), "%s %s" % ("角色" if kind == "char" else "道具", name), font=f, fill=INK)

    canvas.convert("RGB").save(out, "PNG")
    print("输出:", out, canvas.size, "共 %d 组" % len(items))


if __name__ == "__main__":
    main()
