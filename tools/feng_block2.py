# -*- coding: utf-8 -*-
import zipfile

zf = zipfile.ZipFile(r"D:\Apps\steam\steamapps\workshop\content\1942280\3768330140\FengLiu-FengAddMods.zip")
t = zf.read("mods-unpacked/FengLiu-FengAddMods/mod_main.gd").decode("utf-8", "replace")
lines = t.split("\n")
for i, line in enumerate(lines):
    if "Blocked " in line or "blocked" in line:
        print("---- 命中第 %d 行 ----" % (i + 1))
        for j in range(max(0, i - 28), min(len(lines), i + 6)):
            print("%4d %s" % (j + 1, lines[j]))
        break
print("\n=== 文件里所有 func 名 ===")
for i, line in enumerate(lines):
    if line.startswith("func "):
        print("%4d %s" % (i + 1, line))
