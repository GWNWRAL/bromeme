# -*- coding: utf-8 -*-
"""找出是谁在找 /root/Main/UI/PauseMenu/.../ButtonModOptions（闪退现场的报错来源）。"""
import zipfile, os

roots = [r"D:\Apps\steam\steamapps\workshop\content\1942280", r"D:\DSH\mods"]
NEEDLES = ["ButtonModOptions", "HBoxContainer2", "MenuOptions/Buttons", "PauseMenu"]

zips = []
for r in roots:
    if not os.path.isdir(r):
        continue
    for dp, dn, fn in os.walk(r):
        for f in fn:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(dp, f))

for needle in NEEDLES:
    print("=" * 90)
    print("### 搜 %s" % needle)
    for z in zips:
        try:
            with zipfile.ZipFile(z) as zf:
                for n in zf.namelist():
                    if not n.lower().endswith((".gd", ".tscn", ".tres", ".json", ".csv")):
                        continue
                    try:
                        data = zf.read(n).decode("utf-8", "ignore")
                    except Exception:
                        continue
                    if needle in data:
                        hits = [ln.strip() for ln in data.splitlines() if needle in ln]
                        print("  %-42s %s" % (os.path.basename(z), n))
                        for h in hits[:4]:
                            print("        %s" % h[:150])
        except Exception:
            pass
