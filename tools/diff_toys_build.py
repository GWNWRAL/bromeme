#!/usr/bin/env python3
"""Compare the Toys&Balls build_v4 source tree with the installed zip."""
import os, zipfile

SRC = r"D:\DSH\Toys_Balls_build_v4"
ZIP = r"D:\Apps\steam\steamapps\workshop\content\1942280\3609140959\Toys&Balls-1.0.3.zip"

disk = set()
for dp, dn, fn in os.walk(SRC):
    for f in fn:
        rel = os.path.relpath(os.path.join(dp, f), SRC).replace("\\", "/")
        disk.add(rel)

with zipfile.ZipFile(ZIP) as z:
    names = set(z.namelist())

print("installed entries :", len(names))
print("build_v4 files    :", len(disk))
print("only in installed :", len(names - disk))
print("only in build_v4  :", len(disk - names))
for n in sorted(disk - names)[:20]:
    print("   + ", n)
for n in sorted(names - disk)[:20]:
    print("   - ", n)

# content diff for the files I edited
edited = [n for n in disk
          if n.endswith("_stats.tres") and
          any(k in n for k in ("basketball", "boomerang", "easter_egg", "ice_ball", "lego_box", "quidditch"))]
print()
print("edited stat files in tree:", len(edited))
with zipfile.ZipFile(ZIP) as z:
    for n in sorted(edited):
        if n not in names:
            print("   %s  (not in installed zip)" % n)
            continue
        a = z.read(n)
        b = open(os.path.join(SRC, n.replace("/", os.sep)), "rb").read()
        print("   %-70s %s" % (n.split("General-Toys_Balls/")[-1], "same" if a == b else "DIFFERS"))
