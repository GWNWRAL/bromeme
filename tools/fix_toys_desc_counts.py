# -*- coding: utf-8 -*-
"""
Toys&Balls 1.0.7: fix the hard-coded brick-count numbers inside the
LEGO_BOX_DESCRIPTION_1..4 translation strings.

The old text said 1~3 / 1~4 / 2~4 / 2~5 while the code now spawns
0~3 / 1~3 / 1~4 / 2~4. Replace the exact count phrases in every locale column
(zh_Hans_CN, zh_CN, zh_Hant_TW, en, ja, ko) - the ja columns carry the
traditional-Chinese text and the ko columns carry another copy, so all of them
are patched with the same per-key mapping.
"""
import csv, io, sys

CSV = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans.csv"
APPLY = "--apply" in sys.argv

# per key: OLD phrase -> NEW phrase, in the various scripts used in the file
PAIRS = {
    "LEGO_BOX_DESCRIPTION_1": [("1~3", "0~3")],
    "LEGO_BOX_DESCRIPTION_2": [("1~4", "1~3")],
    "LEGO_BOX_DESCRIPTION_3": [("2~4", "1~4")],
    "LEGO_BOX_DESCRIPTION_4": [("2~5", "2~4")],
}

rows = list(csv.reader(io.StringIO(open(CSV, encoding="utf-8").read())))
header = rows[0]

report = []
for r in rows[1:]:
    key = r[0]
    if key not in PAIRS:
        continue
    for i in range(1, len(r)):
        cell = r[i]
        new = cell
        for old, rep in PAIRS[key]:
            new = new.replace(old, rep)
        if new != cell:
            report.append((key, header[i], cell[:40] + "...", new[:40] + "..."))
            r[i] = new

print("=" * 78)
print("%s" % ("APPLIED" if APPLY else "DRY RUN - pass --apply"))
print("=" * 78)
print("cells changed: %d" % len(report))
for key, col, before, after in report:
    print("  %-24s %-12s %s" % (key, col, "count phrase rewritten"))

if APPLY:
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print()
    print("csv written")
else:
    print()
    print("(dry run - nothing written)")
