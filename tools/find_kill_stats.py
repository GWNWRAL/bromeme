# -*- coding: utf-8 -*-
"""列出被启用的工坊 mod 里，名字/id 带 kill 且是主属性的 stat。"""
import os, re, zipfile

root = r"D:\Apps\steam\steamapps\workshop\content\1942280"
seen = []
for d in sorted(os.listdir(root)):
    p = os.path.join(root, d)
    if not os.path.isdir(p):
        continue
    for f in os.listdir(p):
        if not f.lower().endswith(".zip"):
            continue
        try:
            zf = zipfile.ZipFile(os.path.join(p, f))
        except Exception:
            continue
        for n in zf.namelist():
            if not n.endswith(".tres"):
                continue
            try:
                b = zf.read(n).decode("utf-8", "replace")
            except Exception:
                continue
            if "kill" in b.lower() and "is_primary_stat = true" in b:
                m = re.search(r'stat_name = "([^"]+)"', b)
                seen.append((f, m.group(1) if m else "?", n.split("/")[-1]))

for f, name, file in sorted(set(seen)):
    print("%-44s %-40s %s" % (f[:42], name, file))
print("共", len(set(seen)))
