#!/usr/bin/env python3
"""
Toys&Balls: make the two set names conform to the project convention.

Vanilla and other mods store a set's display name as a translation KEY and the
game renders it with tr(set.name):

    res://singletons/item_service.gd:661          text += tr(set.name) + ", "
    res://effects/items/class_bonus_effect.gd:38  return [..., tr(set.name)]

Toys&Balls instead stored literal Chinese ("球类" / "玩具") in `name`, which is
non-conformant: the field is a key everywhere else. This rewrites the two set
files to use keys and appends the matching rows to the mod's translation csv.

Keys follow the mod's own existing prefix style (TOY_SET_XP / BALL_BOUNCE_DAMAGE).
"""
import csv, io, os, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
CSV = os.path.join(MOD, "translations", "trans.csv")

APPLY = "--apply" in sys.argv

# key -> {locale: text}
NEW = {
    "BALL_SET_NAME": {
        "zh_Hans_CN": "球类",
        "zh_CN": "球类",
        "zh_Hant_TW": "球類",
        "en": "Ball",
        "ja": "ボール",
        "ko": "공",
    },
    "TOY_SET_NAME": {
        "zh_Hans_CN": "玩具",
        "zh_CN": "玩具",
        "zh_Hant_TW": "玩具",
        "en": "Toy",
        "ja": "おもちゃ",
        "ko": "장난감",
    },
}

SET_FILES = {
    "content/sets/ball/ball_set_data.tres": "BALL_SET_NAME",
    "content/sets/toy/toy_set_data.tres": "TOY_SET_NAME",
}

print("=" * 74)
print("SET name -> translation key")
print("=" * 74)
for rel, key in SET_FILES.items():
    p = os.path.join(MOD, rel.replace("/", os.sep))
    txt = open(p, encoding="utf-8", errors="replace").read()
    import re
    m = re.search(r'^name\s*=\s*"([^"]*)"', txt, re.M)
    old = m.group(1) if m else None
    new_txt = re.sub(r'^name\s*=\s*"[^"]*"', 'name = "%s"' % key, txt, count=1, flags=re.M)
    print("  %-42s %r  ->  %r" % (os.path.basename(rel), old, key))
    if APPLY:
        open(p, "w", encoding="utf-8", newline="").write(new_txt)

print()
print("=" * 74)
print("translations to append")
print("=" * 74)
raw = open(CSV, encoding="utf-8").read()
rows = list(csv.reader(io.StringIO(raw)))
header = rows[0]
existing = {r[0] for r in rows[1:]}

for key, texts in NEW.items():
    if key in existing:
        print("  %-16s already present, skipping" % key)
        continue
    row = [key] + [texts.get(h, texts.get("en", "")) for h in header[1:]]
    rows.append(row)
    print("  + %s" % row)

if APPLY:
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerows(rows)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print()
    print("csv rows now:", len(rows))
else:
    print()
    print("DRY RUN - pass --apply to write")
