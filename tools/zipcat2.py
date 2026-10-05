#!/usr/bin/env python3
"""Print a line range of a file from a zip (avoids PowerShell quoting issues)."""
import sys, zipfile

zip_path, inner = sys.argv[1], sys.argv[2]
lo = int(sys.argv[3]) if len(sys.argv) > 3 else 1
hi = int(sys.argv[4]) if len(sys.argv) > 4 else 10 ** 9

with zipfile.ZipFile(zip_path) as z:
    data = z.read(inner).decode("utf-8", "replace").splitlines()

for i, line in enumerate(data, 1):
    if lo <= i <= hi:
        print("%4d: %s" % (i, line))
