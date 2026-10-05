# -*- coding: utf-8 -*-
"""生成“游戏里实际生效”的贴图总览（直接读构建后的 art/ 目录）。

用法: python make_current_sheet.py <输出png> char|item [stem,stem,...]
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
ART = os.path.join(MOD, "art")
FONT = r"C:\Windows\Fonts\msyh.ttc"
BG = (246, 243, 235)
CARD = (255, 255, 255)
INK = (48, 42, 36)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


def checker(size, c=14):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, size, c):
        for x in range(0, size, c):
            if ((x // c) + (y // c)) % 2:
                d.rectangle([x, y, x + c - 1, y + c - 1], fill=(228, 228, 228, 255))
    return im


def main():
    out, kind = sys.argv[1], sys.argv[2]
    only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else None

    names, chars, items = {}, [], []
    for f in sorted(os.listdir(RES)):
        if not f.endswith(".json") or f.startswith("_"):
            continue
        d = json.load(open(os.path.join(RES, f), encoding="utf-8"))
        stem = f[:-5]
        names[stem] = d.get("name", stem)
        (chars if int(d.get("item_type", 1)) == 0 else items).append(stem)

    pool = chars if kind == "char" else items
    if only:
        pool = [s for s in pool if s in only]

    CELL = 128
    LABEL = 26
    PAD = 12
    COLS = 7 if kind == "char" else 8
    rows = (len(pool) + COLS - 1) // COLS
    W = PAD + (CELL + PAD) * COLS
    H = PAD + (CELL + LABEL + PAD) * rows
    canvas = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    f = font(16)
    fs = font(13)

    for i, stem in enumerate(pool):
        r, c = divmod(i, COLS)
        x = PAD + c * (CELL + PAD)
        y = PAD + r * (CELL + LABEL + PAD)
        d.rectangle([x - 4, y - 4, x + CELL + 4, y + CELL + LABEL], fill=CARD)
        p = os.path.join(ART, "char" if kind == "char" else "item", stem + ".png")
        base = checker(CELL)
        if os.path.isfile(p):
            im = Image.open(p).convert("RGBA").resize((CELL, CELL), Image.NEAREST)
            base.alpha_composite(im)
        canvas.alpha_composite(base, (x, y))
        label = names.get(stem, stem)
        d.text((x + 2, y + CELL + 3), label, font=f, fill=INK)
        d.text((x + CELL - 44, y + CELL + 5), stem, font=fs, fill=(160, 150, 140))

    canvas.convert("RGB").save(out, "PNG")
    print("输出:", out, canvas.size, "%d 张" % len(pool))


if __name__ == "__main__":
    main()
