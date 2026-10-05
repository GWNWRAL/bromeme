# -*- coding: utf-8 -*-
"""去掉图标里残留的“白色卡片/底框”：把横跨画面、贴近边缘的大块近白区域扣成透明。"""
import os, sys
from collections import deque
from PIL import Image

sys.path.insert(0, r"D:\DSH\_aitato_work")
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402

RAW = r"D:\DSH\Bromeme\aiart_src\1761539722.png"
OUT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited\1761539722.png"


def drop_cards(im, tol=26, min_w=0.70, min_h=0.12, min_alpha=200,
               min_area=0, drop_trapped=False):
    """把近白的“背景卡片”扣成透明。

    drop_trapped=True 时不再要求连通到边缘，而是把所有面积 >= min_area 的近白区域都扣掉
    （用于“白卡片被细线围住、扣不到”的情况）。
    """
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    def white(p):
        return p[3] >= min_alpha and p[0] >= 255 - tol and p[1] >= 255 - tol and p[2] >= 255 - tol

    seen = bytearray(w * h)
    removed = []
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if seen[i0] or not white(px[x0, y0]):
                continue
            q = deque([(x0, y0)])
            seen[i0] = 1
            comp = []
            x1 = x2 = x0
            y1 = y2 = y0
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                x1 = min(x1, x)
                x2 = max(x2, x)
                y1 = min(y1, y)
                y2 = max(y2, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and white(px[nx, ny]):
                            seen[j] = 1
                            q.append((nx, ny))
            bw = (x2 - x1 + 1) / w
            bh = (y2 - y1 + 1) / h
            touches_edge = y1 <= 1 or y2 >= h - 2 or x1 <= 1 or x2 >= w - 2
            hit = (drop_trapped and len(comp) >= min_area) or \
                  (touches_edge and bw >= min_w and bh >= min_h)
            if hit:
                removed.append((x1, y1, x2, y2, len(comp)))
                for x, y in comp:
                    p = px[x, y]
                    px[x, y] = (p[0], p[1], p[2], 0)
    return im, removed


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else RAW
    dst = sys.argv[2] if len(sys.argv) > 2 else OUT
    tol = int(sys.argv[3]) if len(sys.argv) > 3 else 26
    min_area = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    img = Image.open(src)
    cut = dewhite_edge(flood_alpha(img, 40), 40)
    cut, removed = drop_cards(cut, tol=tol, min_area=min_area, drop_trapped=min_area > 0)
    icon = fit_icon(cut, 96, 2)
    icon.save(dst)
    print("移除的白色卡片区域 %d 块，共 %d 像素" % (len(removed), sum(r[4] for r in removed)))
    for r in removed[:10]:
        print("   ", r)
    print("输出:", dst, icon.size, os.path.getsize(dst), "bytes")


if __name__ == "__main__":
    main()
