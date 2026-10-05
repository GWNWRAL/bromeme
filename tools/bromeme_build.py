# -*- coding: utf-8 -*-
"""Build bromeme's generated assets.

  1. art/char/<stem>.png  96x96  (from resources/icons/, used as body art + portrait)
  2. art/item/<stem>.png  96x96  (shop/inventory icon)
  3. resources/_index.json       (ordered list of content json files)
  4. Bromeme.zip                 (mods-unpacked/General-bromeme/...)

Source of truth stays resources/*.json + resources/icons/*.png; this script only
regenerates derived files.  Run it whenever a json/icon is added or edited.
"""
import json
import os
import sys
import zipfile
import numpy as np
from PIL import Image

MOD_DIR = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES_DIR = os.path.join(MOD_DIR, "resources")
ICON_DIR = os.path.join(RES_DIR, "icons")
EDITED_DIR = os.path.join(RES_DIR, "edited")
ART_DIR = os.path.join(MOD_DIR, "art")
ZIP_PATH = r"D:\DSH\Bromeme\Bromeme.zip"

CHAR_SIZE = 96
ITEM_SIZE = 96


def _icons_for(stem, data):
    """Return (icon_source, body_source).

    resources/edited/<stem>.png       replaces icon + in-game body
    resources/edited/<stem>.body.png  replaces only the in-game body
    (Photoshop output can simply be dropped at either path.)
    """
    rel = (data.get("relative_icon_path") or "").replace("\\", "/")
    if rel.startswith("icons/"):
        rel = rel[6:]
    base = os.path.join(ICON_DIR, rel)

    icon = os.path.join(EDITED_DIR, stem + ".png")
    if not os.path.isfile(icon):
        icon = base

    body = os.path.join(EDITED_DIR, stem + ".body.png")
    if not os.path.isfile(body):
        body = icon
    return icon, body


def build_art():
    char_dir = os.path.join(ART_DIR, "char")
    item_dir = os.path.join(ART_DIR, "item")
    body_dir = os.path.join(ART_DIR, "body")
    import shutil
    for d in (char_dir, item_dir, body_dir):
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)

    files = sorted(f for f in os.listdir(RES_DIR) if f.endswith(".json") and not f.startswith("_"))
    stats = {"char": 0, "item": 0, "body": 0}
    missing = []
    for jf in files:
        with open(os.path.join(RES_DIR, jf), "r", encoding="utf-8") as fh:
            data = json.load(fh)
        stem = jf[:-5]
        kind = "char" if int(data.get("item_type", 1)) == 0 else "item"
        size = CHAR_SIZE if kind == "char" else ITEM_SIZE

        icon_src, body_src = _icons_for(stem, data)
        if not os.path.isfile(icon_src):
            missing.append((jf, icon_src))
            continue

        target = char_dir if kind == "char" else item_dir
        _write_resized(icon_src, os.path.join(target, stem + ".png"), size)
        stats[kind] += 1

        # only store a separate in-game body art when it actually differs
        if kind == "char" and body_src != icon_src:
            if not os.path.isfile(body_src):
                missing.append((jf, body_src))
                continue
            _write_resized(body_src, os.path.join(body_dir, stem + ".png"), size)
            stats["body"] += 1

    total = 0
    for d in (char_dir, item_dir, body_dir):
        for f in os.listdir(d):
            total += os.path.getsize(os.path.join(d, f))
    print("art: %d char + %d item + %d body-override, %.1f KB"
          % (stats["char"], stats["item"], stats["body"], total / 1024.0))
    if missing:
        print("MISSING SOURCES:")
        for jf, p in missing:
            print("   ", jf, "->", p)
    return files, missing


def _write_resized(src, dst, size):
    """Resize on premultiplied alpha so transparent pixels' colours cannot
    bleed a grey box into the downscaled sprite."""
    im = Image.open(src).convert("RGBA")
    if im.size == (size, size):
        im.save(dst, "PNG", optimize=True)
        return
    a = np.asarray(im).astype(np.float32)
    alpha = a[:, :, 3:4] / 255.0
    pre = np.concatenate([a[:, :, :3] * alpha, a[:, :, 3:4]], axis=2)
    pre_img = Image.fromarray(np.clip(pre + 0.5, 0, 255).astype(np.uint8), "RGBA")
    pre_img = pre_img.resize((size, size), Image.LANCZOS)
    b = np.asarray(pre_img).astype(np.float32)
    a2 = b[:, :, 3:4] / 255.0
    rgb = np.where(a2 > 0.004, b[:, :, :3] / np.maximum(a2, 0.004), 0)
    out = np.concatenate([np.clip(rgb, 0, 255), b[:, :, 3:4]], axis=2)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(dst, "PNG", optimize=True)


def build_index(files):
    path = os.path.join(RES_DIR, "_index.json")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"files": files}, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    print("index: %d files -> %s" % (len(files), path))


def build_zip(include_source_icons=False):
    root = os.path.dirname(MOD_DIR)  # ...\mods-unpacked
    base = os.path.dirname(root)     # ...\Bromeme
    if os.path.isfile(ZIP_PATH):
        os.remove(ZIP_PATH)
    skip_ext = (".import",)
    skip_names = {"timestamp.txt", ".DS_Store"}
    # resources/icons 和 resources/edited 只是生成 art/ 的素材，
    # 运行时不再读取（art/ 已经是 96x96），默认不打进 zip。
    # 原图/PS 稿仍保留在工程目录里。
    skip_dirs = {"__pycache__", ".import", "edited"}
    if not include_source_icons:
        skip_dirs.add("icons")
    count = 0
    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip_dirs]
            for fn in sorted(filenames):
                if fn in skip_names or fn.endswith(skip_ext):
                    continue
                full = os.path.join(dirpath, fn)
                arc = os.path.relpath(full, base).replace(os.sep, "/")
                z.write(full, arc)
                count += 1
    print("zip: %d entries, %.2f MB -> %s%s" % (
        count, os.path.getsize(ZIP_PATH) / 1048576.0, ZIP_PATH,
        "" if include_source_icons else "  (resources/icons 未打包，原图仍在工程目录)"))


def main():
    files, missing = build_art()
    build_index(files)
    build_zip()
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
