#!/usr/bin/env python3
"""
Investigate why the ko column reads empty in the Godot runtime harness even
though the file contains Korean text. Dumps the raw bytes of the new rows so
encoding damage can be ruled in or out.
"""
import csv, io

P = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans.csv"
raw_bytes = open(P, "rb").read()
print("file bytes:", len(raw_bytes))
print("BOM:", raw_bytes[:3] == b"\xef\xbb\xbf")
print("CRLF count:", raw_bytes.count(b"\r\n"), " bare LF:", raw_bytes.count(b"\n") - raw_bytes.count(b"\r\n"))
print("non-ascii bytes:", sum(1 for b in raw_bytes if b > 127))

rows = list(csv.reader(io.StringIO(raw_bytes.decode("utf-8"))))
h = rows[0]
ki = h.index("ko")
print()
print("header:", h)
print()
for r in rows[1:]:
    if r[0].startswith("TOYS_BALLS_"):
        ko = r[ki] if ki < len(r) else "<MISSING COLUMN>"
        print("  %-36s cols=%d  ko=%r  ko_bytes=%s"
              % (r[0], len(r), ko, ko.encode("utf-8").hex() if ko else "-"))
