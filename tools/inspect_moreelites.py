# -*- coding: utf-8 -*-
"""看 MoreElites-BossPack 里那两个不匹配的粒子场景是怎么被用的（找对 null 调方法的 1 参数调用）。"""
import zipfile, os, re

z = r"D:\Apps\steam\steamapps\workshop\content\1942280\3796570766\MoreElites-BossPack-0.1.2.zip"
if not os.path.isfile(z):
    # 兜底：全盘找
    for dp, dn, fn in os.walk(r"D:\Apps\steam\steamapps\workshop\content\1942280"):
        for f in fn:
            if f == "MoreElites-BossPack-0.1.2.zip":
                z = os.path.join(dp, f)
print("zip:", z)

with zipfile.ZipFile(z) as zf:
    names = zf.namelist()
    part = [n for n in names if "mage_elite" in n or "sniper_elite" in n]
    print("\n=== mage/sniper elite 相关文件 ===")
    for n in part:
        print("   ", n)

    print("\n=== 那两个粒子场景的内容（前 40 行） ===")
    for n in part:
        if not n.endswith(".tscn"):
            continue
        if "mage_elite" not in n and "sniper_elite" not in n:
            continue
        txt = zf.read(n).decode("utf-8", "ignore")
        if "Particles2D" not in txt:
            continue
        print("-----", n)
        for line in txt.splitlines()[:40]:
            print("    ", line)

    print("\n=== 所有 .gd 里出现 Particles 的地方 ===")
    for n in names:
        if not n.endswith(".gd"):
            continue
        try:
            txt = zf.read(n).decode("utf-8", "ignore")
        except Exception:
            continue
        for i, line in enumerate(txt.splitlines()):
            if re.search(r"[Pp]articles", line) and (".instance()" in line or re.search(r"\.\w+\(", line)):
                print("%-70s :%d  %s" % (n.split("mods-unpacked/")[-1], i + 1, line.strip()[:110]))
