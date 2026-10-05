# -*- coding: utf-8 -*-
"""打包 BounceNullFix（中性名字版）。

布局与游戏读取方式一致:
    mods-unpacked/General-BounceNullFix/...   （zip 根）
所有分隔符必须是正斜杠（Godot 的 load_resource_pack 不接受反斜杠）。
"""
import os, zipfile, hashlib, json

SRC = r"D:\DSH\_fixmod"
OUT = r"D:\DSH\_aitato_work\dist\BounceNullFix-1.0.2.zip"

os.makedirs(os.path.dirname(OUT), exist_ok=True)
if os.path.exists(OUT):
    os.remove(OUT)

count = 0
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for dp, dn, fn in os.walk(SRC):
        for f in fn:
            full = os.path.join(dp, f)
            arc = os.path.relpath(full, SRC).replace("\\", "/")
            z.write(full, arc)
            count += 1

with zipfile.ZipFile(OUT) as z:
    names = z.namelist()
    bad = z.testzip()
    backslash = [n for n in names if "\\" in n]
    man = [n for n in names if n.endswith("manifest.json")][0]
    meta = json.loads(z.read(man).decode("utf-8"))

print("output  :", OUT)
print("mod id  : %s-%s  v%s" % (meta["namespace"], meta["name"], meta["version_number"]))
print("entries :", len(names))
print("size    : %.1f KB" % (os.path.getsize(OUT) / 1024.0))
print("md5     :", hashlib.md5(open(OUT, "rb").read()).hexdigest())
print("ziptest :", "ok" if bad is None else bad)
print("backslash entries:", len(backslash))
print("top-level:", sorted({n.split("/")[0] for n in names}))
for n in names:
    print("   ", n)
