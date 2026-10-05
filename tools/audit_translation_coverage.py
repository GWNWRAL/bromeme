#!/usr/bin/env python3
"""
Do the runtime CSV translations cover everything the shipped compiled
.translation files provide?

The compiled files are Godot PHashTranslation: keys are hashed away, so the keys
cannot be read back. Instead we reconstruct the key set from the values: any
value string present in a compiled file but absent from the CSV means the CSV
does not cover that entry and dropping the compiled file would lose it.
"""
import os, re, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
ZIP = r"D:\Apps\steam\steamapps\workshop\content\1942280\3609140959\Toys&Balls-diag.zip"

import csv, io
rows = list(csv.reader(io.StringIO(
    open(os.path.join(MOD, "translations", "trans.csv"), encoding="utf-8").read())))
csv_keys = [r[0] for r in rows[1:]]
csv_values = set()
for r in rows[1:]:
    for cell in r[1:]:
        if cell.strip():
            csv_values.add(cell)

print("csv keys: %d   distinct csv values: %d" % (len(csv_keys), len(csv_values)))
print()

with zipfile.ZipFile(ZIP) as z:
    for name in sorted(n for n in z.namelist() if n.endswith(".translation")):
        raw = z.read(name)
        # PHashTranslation stores translated values inline (smaz-compressed when
        # shorter). Pull the readable ASCII/UTF-8 runs that look like sentences.
        text = raw.decode("utf-8", "replace")
        runs = [m.group(0) for m in re.finditer(r"[\x20-\x7e\u00c0-\uffff]{6,}", text)]
        runs = [r.strip() for r in runs if r.strip()]
        not_in_csv = [r for r in runs if r not in csv_values]
        # filter out obvious smaz noise (no spaces & no known markers)
        suspicious = [r for r in not_in_csv if (" " in r or "%" in r or "{" in r)]
        print("%-52s readable runs=%3d  not-in-csv=%3d" % (name.split("/")[-1], len(runs), len(not_in_csv)))
        for r in suspicious[:6]:
            print("      e.g. %r" % r[:90])
print()
print("If the not-in-csv counts are small/noisy, the CSV is the superset and the")
print("compiled files can be dropped in favour of the runtime registration.")
