# -*- coding: utf-8 -*-
"""找 FengAddMods 里“Blocked ... extension”的实现，看它怎么阻断别的 mod 的脚本扩展。"""
import re, zipfile

zf = zipfile.ZipFile(r"D:\Apps\steam\steamapps\workshop\content\1942280\3768330140\FengLiu-FengAddMods.zip")
for n in zf.namelist():
    if not n.endswith((".gd", ".json")):
        continue
    try:
        t = zf.read(n).decode("utf-8", "replace")
    except Exception:
        continue
    if "Blocked" not in t and "block" not in t.lower():
        continue
    print("=" * 70)
    print(n)
    for i, line in enumerate(t.split("\n")):
        if re.search(r"block|Blocked|extension", line, re.I):
            lo = max(0, i - 6)
            print("\n".join("%4d %s" % (j + 1, t.split("\n")[j]) for j in range(lo, min(len(t.split("\n")), i + 8))))
            print("   ...")
            break
