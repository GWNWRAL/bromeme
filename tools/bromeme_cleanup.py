# -*- coding: utf-8 -*-
"""Remove bromeme's imported leftovers from %APPDATA%/Brotato/brolab.

The old version of the mod COPIED resources/*.json + resources/icons/*.png into
the brolab folder. Now that the mod registers its content directly, those copies
are orphaned: deleting the mod leaves them behind, and their timestamp names can
collide with other BroLab content.

Deletion set is derived strictly from THIS mod's own file list, and every icon
still referenced by a surviving (BroLab-only) json is protected.

Usage:  python bromeme_cleanup.py [--apply]
"""
import json
import os
import sys

MOD_DIR = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES_DIR = os.path.join(MOD_DIR, "resources")
ICON_DIR = os.path.join(RES_DIR, "icons")
BROLAB = os.path.join(os.environ["APPDATA"], "Brotato", "brolab")
BROLAB_ICONS = os.path.join(BROLAB, "icons")


def our_files():
    with open(os.path.join(RES_DIR, "_index.json"), "r", encoding="utf-8") as fh:
        files = json.load(fh)["files"]
    jsons = set(files)
    icons = set()
    for jf in files:
        with open(os.path.join(RES_DIR, jf), "r", encoding="utf-8") as fh:
            data = json.load(fh)
        rel = (data.get("relative_icon_path") or "").replace("\\", "/")
        if rel.startswith("icons/"):
            rel = rel[6:]
        if rel:
            icons.add(os.path.basename(rel))
    return jsons, icons


def main():
    apply = "--apply" in sys.argv

    jsons, icons = our_files()
    present_json = set(f for f in os.listdir(BROLAB) if f.lower().endswith(".json"))
    present_icon = set(os.listdir(BROLAB_ICONS)) if os.path.isdir(BROLAB_ICONS) else set()

    doomed_json = sorted(jsons & present_json)
    survivors = sorted(present_json - jsons)

    # 还活着的 BroLab 内容引用的图标必须保留
    protected = set()
    for jf in survivors:
        try:
            with open(os.path.join(BROLAB, jf), "r", encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception as exc:
            print("  !! cannot read %s: %s" % (jf, exc))
            continue
        rel = (data.get("relative_icon_path") or "").replace("\\", "/")
        if rel:
            protected.add(os.path.basename(rel))

    doomed_icon = sorted((icons & present_icon) - protected)
    kept_icon = sorted(present_icon - set(doomed_icon))

    print("brolab: %s" % BROLAB)
    print("  json   total=%-4d delete=%-4d keep(BroLab-only)=%d"
          % (len(present_json), len(doomed_json), len(survivors)))
    print("  icons  total=%-4d delete=%-4d keep=%d (protected=%d)"
          % (len(present_icon), len(doomed_icon), len(kept_icon), len(protected)))

    print("\n--- WILL DELETE (json) ---")
    for f in doomed_json:
        print("   ", f)
    print("--- WILL KEEP (json, BroLab-only) ---")
    for f in survivors:
        print("   ", f)
    print("--- WILL DELETE (icons) --- %d files" % len(doomed_icon))
    for f in doomed_icon[:20]:
        print("   ", f)
    if len(doomed_icon) > 20:
        print("    ... +%d more" % (len(doomed_icon) - 20))

    if not apply:
        print("\nDRY RUN - pass --apply to delete")
        return

    removed = 0
    for f in doomed_json:
        os.remove(os.path.join(BROLAB, f))
        removed += 1
    for f in doomed_icon:
        p = os.path.join(BROLAB_ICONS, f)
        if os.path.isfile(p):
            os.remove(p)
            removed += 1
    print("\nremoved %d files" % removed)


if __name__ == "__main__":
    main()
