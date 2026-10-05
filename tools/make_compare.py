# -*- coding: utf-8 -*-
"""生成“改前 / 改后 / AI 原画”对比图，方便直观检查效果。"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = r"C:\Windows\Fonts\msyh.ttc"
BG = (247, 244, 236, 255)      # 土豆兄弟商店那种米黄底
CARD = (255, 255, 255, 255)
INK = (58, 48, 40)

ROWS = [
    ("冰红茶（道具 item_brolab_item_icetea_419）",
     r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\art\item\1760763202.png",
     r"D:\DSH\_aitato_work\aiart\icon_icetea.png",
     r"D:\DSH\_aitato_work\aiart\raw_icetea.png"),
    ("奶蛙（角色 character_brolab_nw_115）",
     r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\art\char\1784872500.png",
     r"D:\DSH\_aitato_work\aiart\icon_naowa.png",
     r"D:\DSH\_aitato_work\aiart\raw_naowa.png"),
]

ICON_PX = 288      # 96x96 图标放大到的显示尺寸（NEAREST，保留真实像素）
RAW_PX = 288       # AI 原画显示尺寸
PAD = 20
TITLE_H = 40
LABEL_H = 26
CELL_W = ICON_PX
BIG_W = RAW_PX


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


def checker(size, cell=16):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, size, cell):
        for x in range(0, size, cell):
            if ((x // cell) + (y // cell)) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(226, 226, 226, 255))
    return im


def load(path, box, nearest=False):
    im = Image.open(path).convert("RGBA")
    if im.size != (box, box):
        im = im.resize((box, box), Image.NEAREST if nearest else Image.LANCZOS)
    bg = checker(box)
    bg.alpha_composite(im)
    return bg


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else r"D:\DSH\_aitato_work\aiart\compare.png"

    row_h = TITLE_H + ICON_PX + LABEL_H + PAD
    W = PAD * 3 + CELL_W * 2 + BIG_W + PAD
    H = PAD + row_h * len(ROWS) + PAD

    canvas = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    f_title = font(20)
    f_label = font(17)

    y = PAD
    for title, before, after, raw in ROWS:
        d.rectangle([PAD // 2, y, W - PAD // 2, y + row_h - PAD // 2], fill=CARD)
        d.text((PAD, y + 8), title, font=f_title, fill=INK)

        ty = y + TITLE_H
        x = PAD
        for path, label, box, nearest in (
            (before, "改前 · 96×96（现用）", CELL_W, True),
            (after, "改后 · 96×96（AI 重绘）", CELL_W, True),
            (raw, "AI 原画", BIG_W, False),
        ):
            img = load(path, box, nearest)
            canvas.alpha_composite(img, (x, ty))
            d.text((x + 2, ty + box + 4), label, font=f_label, fill=INK)
            x += box + PAD
        y += row_h

    canvas.convert("RGB").save(out, "PNG")
    print("输出:", out, canvas.size)


if __name__ == "__main__":
    main()
