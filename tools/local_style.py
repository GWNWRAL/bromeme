# -*- coding: utf-8 -*-
"""
本地（不调用任何在线服务）的“土豆兄弟化”预览滤镜。

用途：在 Seedream 额度/开通问题解决前，先用纯 PIL 处理出一版风格预览，
      也可以作为 API 不可用时的兜底方案。

做法：
    抠白底 -> 提饱和/对比 -> 减少色阶（posterize）-> 缩到 96 -> 加粗黑描边

用法:
    python local_style.py <输入图> <输出png> [--size 96] [--margin 3]
                          [--sat 1.6] [--con 1.25] [--bits 4] [--outline 2] [--tol 26]
"""
import argparse, os, sys
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402


def add_outline(img: Image.Image, px: int, color=(24, 20, 26, 255)) -> Image.Image:
    if px <= 0:
        return img
    alpha = img.split()[3]
    dil = alpha.filter(ImageFilter.MaxFilter(px * 2 + 1))
    ring = Image.new("RGBA", img.size, color)
    ring.putalpha(dil)
    return Image.alpha_composite(ring, img)


def stylize(src: str, dst: str, size=96, margin=3, sat=1.6, con=1.25, bits=4,
            outline=2, tol=26):
    img = Image.open(src).convert("RGBA")
    cut = dewhite_edge(flood_alpha(img, tol), tol)

    # 颜色风格化（只在非透明区域，用整图处理即可，透明处不影响）
    rgb = Image.new("RGBA", cut.size, (0, 0, 0, 0))
    rgb.paste(cut, (0, 0), cut)
    r, g, b, a = rgb.split()
    body = Image.merge("RGB", (r, g, b))
    body = ImageEnhance.Color(body).enhance(sat)
    body = ImageEnhance.Contrast(body).enhance(con)
    body = ImageOps.posterize(body, bits)
    styled = Image.merge("RGBA", body.split() + (a,))

    icon = fit_icon(styled, size, margin)
    icon = add_outline(icon, outline)

    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    icon.save(dst)
    print("输出:", dst, icon.size, "%d bytes" % os.path.getsize(dst))
    return icon


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--size", type=int, default=96)
    ap.add_argument("--margin", type=int, default=3)
    ap.add_argument("--sat", type=float, default=1.6)
    ap.add_argument("--con", type=float, default=1.25)
    ap.add_argument("--bits", type=int, default=4)
    ap.add_argument("--outline", type=int, default=2)
    ap.add_argument("--tol", type=int, default=26)
    a = ap.parse_args()
    stylize(a.src, a.dst, a.size, a.margin, a.sat, a.con, a.bits, a.outline, a.tol)
    return 0


if __name__ == "__main__":
    sys.exit(main())
