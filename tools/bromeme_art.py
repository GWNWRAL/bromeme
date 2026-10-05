# -*- coding: utf-8 -*-
"""Resize bromeme character icons (96x96) + item icons (64x64) into the mod.

Sources : D:\\DSH\\Bromeme\\mods-unpacked\\General-bromeme\\resources\\icons\\*.png
Targets : .../art/char/<name>.png   (96x96)   for character json
          .../art/item/<name>.png   (64x64)   for item json
"""
import json, os, shutil, sys
from PIL import Image

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC_ICONS = os.path.join(MOD, "resources", "icons")
RES = os.path.join(MOD, "resources")
ART = os.path.join(MOD, "art")

def main():
    char_dir = os.path.join(ART, "char")
    item_dir = os.path.join(ART, "item")
    for d in (char_dir, item_dir):
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)

    jsons = sorted(f for f in os.listdir(RES) if f.endswith(".json"))
    chars, items, missing = [], [], []
    for jf in jsons:
        with open(os.path.join(RES, jf), "r", encoding="utf-8") as fh:
            data = json.load(fh)
        name = jf[:-5]
        icon = (data.get("relative_icon_path") or "").replace("\\", "/")
        if icon.startswith("icons/"):
            icon = icon[6:]
        src = os.path.join(SRC_ICONS, icon)
        is_char = int(data.get("item_type", 1)) == 0
        if not os.path.isfile(src):
            missing.append(jf)
            continue
        dst = os.path.join(char_dir if is_char else item_dir, name + ".png")
        size = (96, 96) if is_char else (64, 64)
        im = Image.open(src).convert("RGBA")
        im = im.resize(size, Image.LANCZOS)
        im.save(dst, "PNG", optimize=True)
        (chars if is_char else items).append(name)

    print("characters:", len(chars))
    print("items     :", len(items))
    print("missing   :", len(missing), missing)
    tot = 0
    for d in (char_dir, item_dir):
        for f in os.listdir(d):
            tot += os.path.getsize(os.path.join(d, f))
    print("art bytes :", tot)
    with open(os.path.join(ART, "_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump({"characters": chars, "items": items, "missing": missing},
                  fh, indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main()
