# -*- coding: utf-8 -*-
"""找绝对路径 /root/Main/UI/PauseMenu 的出处（闪退前的报错就是它解析失败）。"""
import zipfile, os

roots = [r"D:\Apps\steam\steamapps\workshop\content\1942280", r"D:\DSH\mods"]
NEEDLES = ["/root/Main/UI/PauseMenu", "/root/Shop/PauseMenu", "Main/UI/PauseMenu",
           "get_node(\"/root/Main", "NodePath(\"/root/Main"]

zips = []
for r in roots:
    if not os.path.isdir(r):
        continue
    for dp, dn, fn in os.walk(r):
        for f in fn:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(dp, f))

for needle in NEEDLES:
    print("=" * 92)
    print("### %s" % needle)
    total = 0
    for z in zips:
        try:
            with zipfile.ZipFile(z) as zf:
                for n in zf.namelist():
                    if not n.lower().endswith((".gd", ".tscn", ".tres", ".json")):
                        continue
                    try:
                        data = zf.read(n).decode("utf-8", "ignore")
                    except Exception:
                        continue
                    if needle in data:
                        hits = [ln.strip() for ln in data.splitlines() if needle in ln]
                        print("  %-44s %s   (%d 处)" % (os.path.basename(z), n, len(hits)))
                        for h in hits[:3]:
                            print("        %s" % h[:150])
                        total += 1
        except Exception:
            pass
    print("  -> 命中文件数: %d" % total)
