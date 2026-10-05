#!/usr/bin/env python3
"""
Repackage Toys&Balls from the build_v4 source tree.

Layout must match the installed zip exactly:
    .import/...                            (zip root)
    mods-unpacked/General-Toys_Balls/...   (zip root)
and all separators must be forward slashes (Godot's load_resource_pack rejects
backslashes).
"""
import os, zipfile, hashlib

SRC = r"D:\DSH\Toys_Balls_build_v4"
OUT = r"D:\DSH\_aitato_work\dist\Toys&Balls-1.0.11.zip"

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

print("output   :", OUT)
print("entries  :", len(names), "(wrote %d files)" % count)
print("size     : %.2f MB" % (os.path.getsize(OUT) / 1048576.0))
print("md5      :", hashlib.md5(open(OUT, "rb").read()).hexdigest())
print("ziptest  :", "ok" if bad is None else bad)
print("backslash entries:", len(backslash))
print("top-level:", sorted({n.split("/")[0] for n in names}))
