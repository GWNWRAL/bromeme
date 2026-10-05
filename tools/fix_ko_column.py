#!/usr/bin/env python3
"""
Fill the Korean column for the two set-name keys.

An empty cell in a Translation does NOT fall back to another language - it
resolves to an empty string - so a blank ko column would render the set name as
nothing for Korean players. Fill it explicitly.
"""
import csv, io, os, sys

CSV = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans.csv"
APPLY = "--apply" in sys.argv

KO = {"BALL_SET_NAME": "공", "TOY_SET_NAME": "장난감"}

rows = list(csv.reader(io.StringIO(open(CSV, encoding="utf-8").read())))
header = rows[0]
ko_i = header.index("ko")

changed = 0
for r in rows[1:]:
    if r[0] in KO and len(r) > ko_i and r[ko_i].strip() == "":
        print("  %-16s ko: '' -> %r" % (r[0], KO[r[0]]))
        r[ko_i] = KO[r[0]]
        changed += 1

if APPLY:
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("rows updated:", changed)
else:
    print("DRY RUN - pass --apply")
