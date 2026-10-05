# -*- coding: utf-8 -*-
"""Apply the requested art edits for bromeme.

Writes into  resources/edited/  :
    <stem>.png        replaces the icon AND the in-game body art
    <stem>.body.png   replaces only the in-game body art (icon untouched)

resources/icons/ keeps the untouched originals, so every edit is replayable.
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC = os.path.join(MOD, "resources", "icons")
EDITED = os.path.join(MOD, "resources", "edited")
PREV = r"D:\DSH\_aitato_work\prev"

MIRROR = ["1762531564", "1784872500", "1783444690", "1784882689", "1780863546"]
MIRROR = ["1762531564", "1784872500", "1783444690", "1784882689"]


def load(stem):
    return Image.open(os.path.join(SRC, stem + ".png")).convert("RGBA")


def rgb_of(im):
    a = np.array(im).astype(np.int16)
    return a[:, :, :3]


def flood(rgb, seeds, tol, pred=None):
    """Background mask: region growing from `seeds`, optionally accepting
    pixels that `pred` classifies as background regardless of neighbourhood."""
    a = rgb.astype(np.int16)
    h, w, _ = a.shape
    bg = np.zeros((h, w), bool)
    dq = deque()
    for x, y in seeds:
        if 0 <= x < w and 0 <= y < h and not bg[y, x]:
            bg[y, x] = True
            dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        cur = a[y, x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= w or ny >= h or bg[ny, nx]:
                continue
            nxt = a[ny, nx]
            take = int(np.abs(nxt - cur).max()) <= tol
            if not take and pred is not None:
                take = bool(pred(nxt))
            if take:
                bg[ny, nx] = True
                dq.append((nx, ny))
    return bg


def model_flood(rgb, refs, tol, seeds):
    """Background mask from a fixed palette of background colours."""
    a = rgb.astype(np.int16)
    r = np.asarray(refs, dtype=np.int16)
    h, w, _ = a.shape

    def is_bg(c):
        return int(np.abs(r - c).max(axis=1).min()) <= tol

    bg = np.zeros((h, w), bool)
    dq = deque()
    edge = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    edge += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for x, y in edge + list(seeds):
        if not bg[y, x] and is_bg(a[y, x]):
            bg[y, x] = True
            dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not bg[ny, nx] and is_bg(a[ny, nx]):
                bg[ny, nx] = True
                dq.append((nx, ny))
    return bg


def cut(im, mask, feather=0.9, white_key=None):
    arr = np.array(im)
    alpha = arr[:, :, 3].astype(np.float32)
    keep = (~mask).astype(np.float32) * 255.0
    if white_key is not None:
        lum = arr[:, :, :3].astype(np.float32).max(axis=2)
        lo, hi = white_key
        ramp = np.clip((lum - lo) / float(hi - lo), 0.0, 1.0) * 255.0
        keep = np.minimum(keep, ramp)
    alpha = np.minimum(alpha, keep)
    if feather > 0:
        alpha = np.array(
            Image.fromarray(alpha.astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(feather))
        ).astype(np.float32)
    arr[:, :, 3] = alpha.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def drop_small_blobs(mask, min_px):
    """`mask` is the BACKGROUND mask. Any isolated foreground island smaller
    than min_px is handed back to the background (kills leftover shards)."""
    h, w = mask.shape
    fg = ~mask
    seen = np.zeros((h, w), bool)
    for y0 in range(h):
        for x0 in range(w):
            if not fg[y0, x0] or seen[y0, x0]:
                continue
            stack = [(x0, y0)]
            seen[y0, x0] = True
            blob = []
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and fg[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
            if len(blob) < min_px:
                for x, y in blob:
                    mask[y, x] = True
    return mask


def fill_small_holes(mask, min_px):
    """Transparent islands fully enclosed by foreground get filled back in."""
    h, w = mask.shape
    seen = np.zeros((h, w), bool)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                stack.append((x, y))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((nx, ny))
    # everything still unseen is an enclosed background island
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                mask[y, x] = False
    return mask


def corners(w, h):
    return [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]


def save(im, stem, body_only=False):
    name = stem + (".body" if body_only else "") + ".png"
    im.save(os.path.join(EDITED, name), "PNG", optimize=True)
    return name


def preview(im, size=300, bg=(255, 0, 255)):
    c = Image.new("RGB", (size, size), bg)
    t = im.copy()
    t.thumbnail((size, size), Image.LANCZOS)
    c.paste(t, ((size - t.width) // 2, (size - t.height) // 2), t)
    return c


def main():
    os.makedirs(EDITED, exist_ok=True)
    made = []

    # --- 1. plain horizontal mirrors -------------------------------------
    for stem in MIRROR:
        im = load(stem).transpose(Image.FLIP_LEFT_RIGHT)
        made.append((save(im, stem), im))

    # --- 2. 猪猪侠: drop the scene slivers around the silhouette ----------
    im = load("1761042954")
    m = model_flood(rgb_of(im), [np.array(c, dtype=np.int16) for c in
                                 [np.array(im)[y, x][:3] for x, y in corners(im.width, im.height)]],
                    tol=20, seeds=[])
    # model_flood expects a palette; feed the four corner colours explicitly
    refs = [np.array(im)[y, x][:3] for x, y in corners(im.width, im.height)]
    m = model_flood(rgb_of(im), refs, tol=20, seeds=[])
    out = cut(im, m, 0.6)
    made.append((save(out, "1761042954"), out))

    # --- 3. 李文亚: magazine cover -> figure. body only, icon untouched ---
    im = load("1765220738")

    def lwy_pred(c):
        r, g, b = int(c[0]), int(c[1]), int(c[2])
        reddish = r > 110 and r - g > 60 and r - b > 60
        dark = max(r, g, b) < 110 and (max(r, g, b) - min(r, g, b)) < 45
        return reddish or dark

    from edit_lib import border_seeds
    m = flood(rgb_of(im), border_seeds(im.width, im.height), tol=18, pred=lwy_pred)
    # 封面底色亮度约 50~110，白描线条 190+，用亮度再筛一道把灰底清干净
    out = cut(im, m, 1.0, white_key=(140.0, 195.0))
    made.append((save(out, "1765220738", body_only=True), out))

    # --- 4. 龙卷风: 只做镜像 ---------------------------------------------
    # 这张是"机甲 + 火焰背景"，机甲和火焰都是橙色系，颜色分割一定会把机甲
    # 咬碎（试过 margin/seed/global 三种 key，最好也会留下锯齿状火苗）。
    # 所以这里只镜像；抠图请用 PS 的"移除背景/选择主体"导出到
    #   resources/edited/1760863546.png
    # 构建脚本会自动认它。下面同时导出我的最佳尝试，供对比：
    im = load("1760863546")
    A = np.array(im.convert("RGB"))
    sky = [(340, 66), (60, 200), (60, 440), (400, 455), (390, 300), (35, 300),
           (400, 58), (60, 58), (690, 430), (690, 250)]
    refs = [A[y, x] for x, y in sky]
    m = model_flood(rgb_of(im), refs, tol=24, seeds=sky)
    m = drop_small_blobs(m, 900)
    m = fill_small_holes(m, 4000)
    attempt = cut(im, m, 1.0).transpose(Image.FLIP_LEFT_RIGHT)
    attempt.save(os.path.join(EDITED, "1760863546.bg-attempt.png"), "PNG", optimize=True)

    out = im.transpose(Image.FLIP_LEFT_RIGHT)
    made.append((save(out, "1760863546"), out))

    # --- preview sheet ---------------------------------------------------
    order = [("1762531564", "NZ 哪吒"), ("1784872500", "NW 奶蛙"),
             ("1783444690", "ZXF 张雪峰"), ("1784882689", "BSLB 不死老表"),
             ("1761042954", "ZZX 猪猪侠"), ("1765220738", "LWY 李文亚"),
             ("1760863546", "LJF 龙卷风")]
    S = 300
    sheet = Image.new("RGB", (S * len(order), S * 2 + 44), (255, 0, 255))
    d = ImageDraw.Draw(sheet)
    for i, (stem, label) in enumerate(order):
        sheet.paste(preview(load(stem), S), (i * S, 22))
        after = Image.open(os.path.join(EDITED, stem + ".png")) if os.path.exists(
            os.path.join(EDITED, stem + ".png")) else Image.open(
            os.path.join(EDITED, stem + ".body.png"))
        sheet.paste(preview(after, S), (i * S, S + 44))
        d.text((i * S + 4, 6), "BEFORE " + label, fill=(0, 0, 0))
        d.text((i * S + 4, S + 28), "AFTER (mirrored view matches in-game)", fill=(0, 0, 0))
    os.makedirs(PREV, exist_ok=True)
    sheet.save(os.path.join(PREV, "sheet_edits_final.png"))

    for name, _ in made:
        print("wrote resources/edited/" + name)


if __name__ == "__main__":
    sys.exit(main())
