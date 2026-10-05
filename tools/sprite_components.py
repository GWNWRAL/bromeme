# -*- coding: utf-8 -*-
"""找出精灵图里跟主体不连通的碎块（例如抠图残留的一条白线）。"""
import sys
from collections import deque
from PIL import Image
import numpy as np


def components(alpha, thr=8):
    h, w = alpha.shape
    seen = np.zeros((h, w), dtype=bool)
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0, x0] or alpha[y0, x0] <= thr:
                continue
            q = deque([(x0, y0)])
            seen[y0, x0] = True
            pix = []
            while q:
                x, y = q.popleft()
                pix.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny, nx] and alpha[ny, nx] > thr:
                        seen[ny, nx] = True
                        q.append((nx, ny))
            comps.append(pix)
    return comps


def main(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(int)
    alpha = a[:, :, 3]
    comps = components(alpha)
    comps.sort(key=len, reverse=True)
    print("连通块 %d 个；前 8 大：" % len(comps))
    for i, pix in enumerate(comps[:8]):
        xs = [p[0] for p in pix]
        ys = [p[1] for p in pix]
        cols = a[[p[1] for p in pix], [p[0] for p in pix], :3]
        print("  #%d  像素 %6d  bbox x[%d..%d] y[%d..%d]  平均色 %s  平均alpha %.0f"
              % (i, len(pix), min(xs), max(xs), min(ys), max(ys),
                 cols.mean(axis=0).round(1), a[[p[1] for p in pix], [p[0] for p in pix], 3].mean()))
    return comps


if __name__ == "__main__":
    main(sys.argv[1])
