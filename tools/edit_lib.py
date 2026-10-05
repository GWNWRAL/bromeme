# -*- coding: utf-8 -*-
"""Prototype: mirror + background removal for bromeme character art.

Writes previews to D:\\DSH\\_aitato_work\\prev\\ so they can be eyeballed before
anything is committed to resources/edited/.
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\icons"
OUT = r"D:\DSH\_aitato_work\prev"
os.makedirs(OUT, exist_ok=True)


def load(stem):
    return Image.open(os.path.join(SRC, stem + ".png")).convert("RGBA")


def mirror(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def region_grow_mask(rgb, seeds, tol=30, pred=None):
    """Flood from seeds; accept a neighbour when it is within `tol` of the pixel
    we came from (tolerant of gradients) or when `pred(colour)` says yes.

    `rgb` must be an HxWx3 array (no alpha channel)."""
    arr = rgb
    h, w, _ = arr.shape
    accepted = np.zeros((h, w), dtype=bool)
    dq = deque()
    a = arr.astype(np.int16)
    for x, y in seeds:
        if 0 <= x < w and 0 <= y < h and not accepted[y, x]:
            accepted[y, x] = True
            dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        cur = a[y, x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= w or ny >= h or accepted[ny, nx]:
                continue
            nxt = a[ny, nx]
            near = int(np.abs(nxt - cur).max()) <= tol
            if pred is not None and not near:
                near = bool(pred(nxt))
            if near:
                accepted[ny, nx] = True
                dq.append((nx, ny))
    return accepted


def border_seeds(w, h):
    seeds = []
    for x in range(w):
        seeds.append((x, 0))
        seeds.append((x, h - 1))
    for y in range(h):
        seeds.append((0, y))
        seeds.append((w - 1, y))
    return seeds


def apply_mask(im, mask, feather=1.2):
    arr = np.array(im)
    alpha = arr[:, :, 3].astype(np.float32)
    keep = (~mask).astype(np.float32) * 255.0
    alpha = np.minimum(alpha, keep)
    if feather > 0:
        a_img = Image.fromarray(alpha.astype(np.uint8), "L").filter(
            ImageFilter.GaussianBlur(feather))
        alpha = np.array(a_img).astype(np.float32)
    arr[:, :, 3] = alpha.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def keep_largest_blob(mask):
    """Drop tiny specks left inside the subject."""
    from collections import deque as dq2
    h, w = mask.shape
    seen = np.zeros((h, w), bool)
    blobs = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                q = dq2([(x, y)])
                seen[y, x] = True
                n = 0
                while q:
                    cx, cy = q.popleft()
                    n += 1
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((nx, ny))
                blobs.append((n, mask & seen))
    if not blobs:
        return mask
    blobs.sort(key=lambda t: -t[0])
    return blobs[0][1]


def preview(im, name, size=260, bg=(255, 0, 255)):
    canvas = Image.new("RGB", (size, size), bg)
    t = im.copy()
    t.thumbnail((size, size), Image.LANCZOS)
    canvas.paste(t, ((size - t.width) // 2, (size - t.height) // 2), t)
    canvas.save(os.path.join(OUT, name + ".png"))
    return canvas


def sheet(canvases, labels, path, size=260):
    s = Image.new("RGB", (size * len(canvases), size + 22), (255, 0, 255))
    d = ImageDraw.Draw(s)
    for i, c in enumerate(canvases):
        s.paste(c, (i * size, 22))
        d.text((i * size + 4, 6), labels[i], fill=(0, 0, 0))
    s.save(path)
    return s
