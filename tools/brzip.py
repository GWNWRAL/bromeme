#!/usr/bin/env python3
"""Dump a file (or list files) from the BroLab workshop zip."""
import zipfile, sys

Z = r"D:\Apps\steam\steamapps\workshop\content\1942280\3145676266\Brolab.zip"

with zipfile.ZipFile(Z) as z:
    names = z.namelist()
    args = sys.argv[1:]
    if not args:
        for n in names:
            print(n)
        sys.exit(0)
    if args[0] == "--list-gd":
        for n in names:
            if n.endswith(".gd"):
                print(n)
        sys.exit(0)
    if args[0] == "--grep":
        pat = args[1]
        for n in names:
            if not n.endswith((".gd", ".tscn", ".tres", ".json", ".cfg")):
                continue
            try:
                txt = z.read(n).decode("utf-8", "replace")
            except Exception:
                continue
            for i, l in enumerate(txt.splitlines(), 1):
                if pat in l:
                    print("%s:%d: %s" % (n, i, l.rstrip()[:180]))
        sys.exit(0)
    for a in args:
        try:
            data = z.read(a)
        except KeyError:
            cand = [n for n in names if n.endswith(a)]
            if not cand:
                print("NOT FOUND: %s" % a)
                continue
            a = cand[0]
            data = z.read(a)
        print("=" * 78)
        print(a)
        print("=" * 78)
        sys.stdout.write(data.decode("utf-8", "replace"))
        print()
