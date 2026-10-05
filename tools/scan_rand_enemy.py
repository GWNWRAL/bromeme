# -*- coding: utf-8 -*-
"""只看 get_rand_enemy 的调用点（崩溃签名最像这个），以及 Bromeme 自带 compat 里的 spawner 调用。"""
import zipfile, os

ROOTS = [r"D:\Apps\steam\steamapps\workshop\content\1942280", r"D:\DSH\mods"]
zips = []
for r in ROOTS:
    if not os.path.isdir(r):
        continue
    for dp, dn, fn in os.walk(r):
        for f in fn:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(dp, f))

print("=== 所有 get_rand_enemy 调用点 ===")
for z in sorted(set(zips)):
    try:
        with zipfile.ZipFile(z) as zf:
            for n in zf.namelist():
                if not n.lower().endswith(".gd"):
                    continue
                try:
                    lines = zf.read(n).decode("utf-8", "ignore").splitlines()
                except Exception:
                    continue
                for i, line in enumerate(lines):
                    if "get_rand_enemy" not in line:
                        continue
                    print("\n%s :: %s:%d" % (os.path.basename(z), n, i + 1))
                    lo = max(0, i - 6)
                    for j in range(lo, min(len(lines), i + 2)):
                        mark = ">>" if j == i else "  "
                        print("   %s %s" % (mark, lines[j].rstrip()[:130]))
    except Exception as e:
        print("skip", z, e)
