# -*- coding: utf-8 -*-
"""在用户所有模组 zip 里找出 item_brolab_yan / ITEM_BROLAB_YAN 的出处。"""
import zipfile, os

roots = [r"D:\Apps\steam\steamapps\workshop\content\1942280", r"D:\DSH\mods", r"D:\DSH\_mod_inspect"]
zips = []
for r in roots:
    if not os.path.isdir(r):
        continue
    for dp, dn, fn in os.walk(r):
        for f in fn:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(dp, f))

print("zips scanned:", len(zips))
yan_entries = []
key_hits = []
for z in zips:
    try:
        with zipfile.ZipFile(z) as zf:
            for n in zf.namelist():
                low = n.lower()
                if "yan" in low and low.endswith((".tres", ".gd", ".csv", ".tscn")):
                    yan_entries.append((os.path.basename(z), n))
                if low.endswith((".tres", ".gd", ".csv")):
                    try:
                        data = zf.read(n).decode("utf-8", "ignore")
                    except Exception:
                        continue
                    if "brolab_yan" in data.lower():
                        key_hits.append((os.path.basename(z), n))
    except Exception:
        pass

print("\n--- 文件名含 yan 的条目 ---")
for z, n in yan_entries[:40]:
    print("  ", z, "::", n)
print("\n--- 内容里出现 brolab_yan 的条目 ---")
for z, n in key_hits[:40]:
    print("  ", z, "::", n)
