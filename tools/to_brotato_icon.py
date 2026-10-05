# -*- coding: utf-8 -*-
"""
把 Seedream 生成的图（白底）裁成土豆兄弟风格的 96x96 带透明通道图标。

用法:
    python to_brotato_icon.py <输入图> <输出png> [--size 96] [--margin 2] [--tol 32] [--keep-raw]

处理:
    1. 从四边泛洪，把接近白色的背景抠成透明（tol 越大抠得越狠）
    2. 去掉半透明边缘的白边（避免白色描边残留）
    3. 按内容裁剪，等比放进 size x size 画布，四周留 margin 像素
    4. LANCZOS 缩放，保存为 RGBA PNG
"""
import argparse, os, sys
from collections import deque
from PIL import Image


def flood_alpha(img: Image.Image, tol: int, soft: int = 24) -> Image.Image:
    """四边泛洪去掉接近白的背景。soft: 边缘羽化过渡带宽度（0 表示硬边）。"""
    im = img.convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_bg(p):
        if p[3] == 0:          # 本来就是透明的像素也算背景，否则会把内部白块隔在外面
            return True
        r, g, b = p[0], p[1], p[2]
        return r >= 255 - tol and g >= 255 - tol and b >= 255 - tol

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))

    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        if not is_bg(px[x, y]):
            continue
        seen[i] = 1
        q.append((x + 1, y))
        q.append((x - 1, y))
        q.append((x, y + 1))
        q.append((x, y - 1))

    out = im.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                op[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
    return out


def dewhite_edge(img: Image.Image, tol: int) -> Image.Image:
    """把仍然偏白但贴着透明区的像素也刷透明，去掉抠图残留的白描边。"""
    im = img.convert("RGBA")
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            near_transparent = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                    near_transparent = True
                    break
            if near_transparent and r >= 255 - tol and g >= 255 - tol and b >= 255 - tol:
                px[x, y] = (r, g, b, 0)
    return im


def fit_icon(img: Image.Image, size: int, margin: int) -> Image.Image:
    im = img.convert("RGBA")
    bbox = im.split()[3].getbbox()
    if bbox:
        im = im.crop(bbox)
    inner = max(1, size - margin * 2)
    w, h = im.size
    scale = min(inner / float(w), inner / float(h))
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(im, ((size - nw) // 2, (size - nh) // 2), im)
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--size", type=int, default=96)
    ap.add_argument("--margin", type=int, default=2)
    ap.add_argument("--tol", type=int, default=26)
    ap.add_argument("--keep-raw", action="store_true", help="额外输出 *_nocut.png（只缩放不抠图）")
    a = ap.parse_args()

    img = Image.open(a.src)
    cut = dewhite_edge(flood_alpha(img, a.tol), a.tol)
    icon = fit_icon(cut, a.size, a.margin)
    os.makedirs(os.path.dirname(os.path.abspath(a.dst)), exist_ok=True)
    icon.save(a.dst)
    print("输出:", a.dst, icon.size, "%d bytes" % os.path.getsize(a.dst))
    if a.keep_raw:
        raw = fit_icon(img, a.size, a.margin)
        p = a.dst.replace(".png", "_nocut.png")
        raw.save(p)
        print("输出:", p, raw.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
