#!/usr/bin/env python3
"""Search Brolab's editor UI for how items are keyed: filename vs my_id."""
import zipfile, re, sys

Z = r"D:\Apps\steam\steamapps\workshop\content\1942280\3145676266\Brolab.zip"
TARGETS = [
    "mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/menu_brolab.gd",
    "mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/menu_brolab_manager.gd",
    "mods-unpacked/QianMo-BroLab/extensions/main.gd",
    "mods-unpacked/QianMo-BroLab/mod_main.gd",
]

PATS = sys.argv[1:] or ["\.json", "walk_directory", "save_file", "save_buffer", "delete_file",
                        "relative_icon_path", "my_id", "file_name", "duplicate", "BASE_SAVE_PATH"]

with zipfile.ZipFile(Z) as z:
    for t in TARGETS:
        try:
            lines = z.read(t).decode("utf-8", "replace").splitlines()
        except KeyError:
            continue
        print("=" * 78)
        print(t.split("/")[-1])
        print("=" * 78)
        for i, l in enumerate(lines, 1):
            if any(re.search(p, l) for p in PATS):
                print("%4d: %s" % (i, l.rstrip()[:140]))
        print()
