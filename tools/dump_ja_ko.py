#!/usr/bin/env python3
"""Dump the full ja and ko cells for the lego descriptions so the exact
characters (notably the wave-dash variants) are visible."""
import csv, io, unicodedata

P = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans.csv"
rows = list(csv.reader(io.StringIO(open(P, encoding="utf-8").read())))
h = rows[0]
ji, ki, zi = h.index("ja"), h.index("ko"), h.index("zh_Hans_CN")

for r in rows[1:]:
    if not r[0].startswith("LEGO_BOX_DESCRIPTION"):
        continue
    print("=" * 78)
    print(r[0])
    print("  zh : %s" % r[zi])
    print("  ja : %s" % r[ji])
    print("  ko : %s" % r[ki])
    # show any non-ASCII dash-like characters used in each
    for lbl, cell in (("zh", r[zi]), ("ja", r[ji]), ("ko", r[ki])):
        odd = sorted({c for c in cell if ord(c) > 127 and unicodedata.category(c).startswith("P")})
        if odd:
            print("  %s dash/punct: %s" % (lbl, " ".join("%s(U+%04X)" % (c, ord(c)) for c in odd)))
