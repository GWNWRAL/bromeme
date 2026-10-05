#!/usr/bin/env python3
"""Print selected functions from Brolab's brolab_manager.gd."""
import zipfile, sys

Z = r"D:\Apps\steam\steamapps\workshop\content\1942280\3145676266\Brolab.zip"
INNER = "mods-unpacked/QianMo-BroLab/brolab_manager.gd"

lo = int(sys.argv[1]) if len(sys.argv) > 1 else 1
hi = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

with zipfile.ZipFile(Z) as z:
    lines = z.read(INNER).decode("utf-8", "replace").splitlines()

for i, l in enumerate(lines, 1):
    if lo <= i <= hi:
        print("%4d: %s" % (i, l.rstrip()))
