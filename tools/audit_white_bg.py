# -*- coding: utf-8 -*-
"""检查图标里有没有“残留的白色底/白卡片”：
统计不透明像素中，接近白色、且**不与透明区域相连**的像素占比。"""
import os, sys
from collections import deque
from PIL import Image

EDITED = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited"


def audit(path, tol=26, report=0.02):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_white(p):
        return p[3] > 200 and p[0] >= 255 - tol and p[1] >= 255 - tol and p[2] >= 255 - tol

    # 从透明像素出发，标记所有“与透明相连”的白像素
    seen = bytearray(w * h)
    q = deque()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                q.append((x, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h):
            continue
        i = y * w + x
        if seen[i]:
            continue
        if not is_white(px[x, y]):
            continue
        seen[i] = 1
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + d[0], y + d[1]))

    opaque = 0
    trapped = 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] <= 200:
                continue
            opaque += 1
            if is_white(p) and not seen[y * w + x]:
                trapped += 1
    frac = trapped / max(1, opaque)
    return frac, trapped, opaque


def main():
    rows = []
    for f in sorted(os.listdir(EDITED)):
        if not f.endswith(".png") or f.endswith(".body.png"):
            continue
        frac, trapped, opaque = audit(os.path.join(EDITED, f))
        rows.append((frac, f, trapped, opaque))
    rows.sort(reverse=True)
    print("%-18s %8s %8s %8s" % ("file", "trapped", "opaque", "ratio"))
    for frac, f, trapped, opaque in rows[:14]:
        flag = "  <== 白底残留" if frac > 0.02 else ""
        print("%-18s %8d %8d %7.2f%%%s" % (f, trapped, opaque, frac * 100, flag))


if __name__ == "__main__":
    main()
