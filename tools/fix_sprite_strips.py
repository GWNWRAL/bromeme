# -*- coding: utf-8 -*-
"""清掉精灵图边缘的抠图残条：贴着画布边、厚度<=2px、像素很少的孤立碎片。"""
import os, sys
from collections import deque
from PIL import Image
import numpy as np

DIR = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
MAX_PIX = 400       # 这么多像素以下才算“残条”
MAX_THICK = 2       # 厚度上限


def components(mask):
    h, w = mask.shape
    seen = np.zeros((h, w), bool)
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0, x0] or not mask[y0, x0]:
                continue
            q = deque([(x0, y0)])
            seen[y0, x0] = True
            pix = []
            while q:
                x, y = q.popleft()
                pix.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny, nx] and mask[ny, nx]:
                        seen[ny, nx] = True
                        q.append((nx, ny))
            comps.append(pix)
    return comps


def fix(path, apply=False):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.uint8).copy()
    h, w = a.shape[:2]
    mask = a[:, :, 3] > 8
    todo = []
    for pix in components(mask):
        if len(pix) > MAX_PIX:
            continue
        xs = [p[0] for p in pix]
        ys = [p[1] for p in pix]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        thick = min(x1 - x0 + 1, y1 - y0 + 1)
        touches = x0 == 0 or y0 == 0 or x1 == w - 1 or y1 == h - 1
        if touches and thick <= MAX_THICK:
            todo.append((len(pix), x0, x1, y0, y1))
    name = os.path.basename(path)
    if not todo:
        print("  %-20s 干净" % name)
        return False
    for n, x0, x1, y0, y1 in todo:
        print("  %-20s 残条 %d px  x[%d..%d] y[%d..%d] -> 清掉" % (name, n, x0, x1, y0, y1))
    if apply:
        for n, x0, x1, y0, y1 in todo:
            # 只清掉这条残条本身（连通域），不动别的
            sub = np.zeros((h, w), bool)
            submask = a[:, :, 3] > 8
            for pix in components(submask):
                xs = [p[0] for p in pix]; ys = [p[1] for p in pix]
                if len(pix) == n and min(xs) == x0 and max(xs) == x1 and min(ys) == y0 and max(ys) == y1:
                    for x, y in pix:
                        sub[y, x] = True
            a[sub] = 0
        Image.fromarray(a, "RGBA").save(path, "PNG", optimize=True)
        print("  -> 已写回 %s" % path)
    return True


if __name__ == "__main__":
    apply = "--apply" in sys.argv
    print("=== 扫描 memeboss 贴图（%s）===" % ("写入" if apply else "只报告"))
    for root, _, files in os.walk(DIR):
        for f in sorted(files):
            if f.lower().endswith(".png"):
                fix(os.path.join(root, f), apply)
