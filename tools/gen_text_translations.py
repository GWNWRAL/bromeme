# -*- coding: utf-8 -*-
"""
Generate trans.<locale>.translation as Godot 3 TEXT resources.

Why not csv_translation: Godot 3.6.2's csv_translation importer silently DROPS
Korean characters (verified with a minimal case: `ko HELLO=` comes out empty).
The compiled PHashTranslation format also cannot be produced by hand (smaz,
perfect-hash tables).

A Translation is a plain Resource, so it can be written in the ordinary text
resource format:

    [gd_resource type="Resource" load_steps=2 format=2]
    [ext_resource path="res://resources/translations/translation.gd" type="Script" id=1]
    [resource]
    script = ExtResource( 1 )
    locale = "ko"
    messages = { "KEY": "value", ... }

Godot's ResourceLoader reads the text format when no binary file is present, so
this works at runtime and keeps every character intact.

Also fixes the Japanese brick-count ranges, which use the full-width wave dash
U+301C ('〜') rather than '~' and were therefore missed by the earlier pass.
"""
import csv, io, os, re, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
TRANS_DIR = os.path.join(MOD, "translations")
APPLY = "--apply" in sys.argv

LOCALE_TO_FILE = {
    "zh_Hans_CN": "trans.zh_Hans_CN.translation",
    "zh_Hant_TW": "trans.zh_Hant_TW.translation",
    "en": "trans.en.translation",
    "ja": "trans.ja.translation",
    "ko": "trans.ko.translation",
}

# ---- 1) fix the Japanese ranges (U+301C) ---------------------------------
JA_FIX = [("レゴブロックを1〜3個", "レゴブロックを0〜3個"),
          ("レゴブロックを1〜4個", "レゴブロックを1〜3個"),
          ("レゴブロックを2〜4個", "レゴブロックを1〜4個"),
          ("レゴブロックを2〜5個", "レゴブロックを2〜4個")]

rows = list(csv.reader(io.StringIO(open(os.path.join(TRANS_DIR, "trans.csv"),
                                        encoding="utf-8").read())))
header = rows[0]

ja_i = header.index("ja")
fixed = 0
for r in rows[1:]:
    if not r[0].startswith("LEGO_BOX_DESCRIPTION"):
        continue
    for old, new in JA_FIX:
        if old in r[ja_i]:
            r[ja_i] = r[ja_i].replace(old, new)
            fixed += 1
            break

print("japanese lego ranges fixed: %d" % fixed)
if APPLY and fixed:
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(os.path.join(TRANS_DIR, "trans.csv"), "w", encoding="utf-8", newline="").write(buf.getvalue())

# ---- 2) emit text-format .translation per locale -------------------------
def gd_escape(s):
    return (s.replace("\\", "\\\\")
             .replace('"', '\\"')
             .replace("\n", "\\n")
             .replace("\t", "\\t"))

made = []
for loc, fname in LOCALE_TO_FILE.items():
    if loc not in header:
        print("  locale column missing:", loc)
        continue
    ci = header.index(loc)
    msgs = []
    for r in rows[1:]:
        if not r[0]:
            continue
        val = r[ci] if ci < len(r) else ""
        msgs.append('\t"%s": "%s"' % (gd_escape(r[0]), gd_escape(val)))
    body = ('[gd_resource type="Resource" load_steps=2 format=2]\n\n'
            '[ext_resource path="res://resources/translations/translation.gd" type="Script" id=1]\n\n'
            '[resource]\n'
            'script = ExtResource( 1 )\n'
            'locale = "%s"\n'
            'messages = {\n%s\n}\n' % (loc, ",\n".join(msgs)))
    path = os.path.join(TRANS_DIR, fname)
    if APPLY:
        open(path, "w", encoding="utf-8", newline="").write(body)
    made.append((fname, len(msgs), len(body.encode("utf-8"))))

print()
for fname, n, size in made:
    print("  %-40s %3d messages  %6d bytes" % (fname, n, size))
print()
print("%s" % ("APPLIED" if APPLY else "DRY RUN - pass --apply"))
