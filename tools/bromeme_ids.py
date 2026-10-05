#!/usr/bin/env python3
"""
Can we keep the existing my_id values?

If every my_id in the mod's json set is unique, reusing them keeps existing game
saves valid (saves store character ids). If any collide, we must decide which to
rename.
"""
import json, os, collections

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"

by_id = collections.defaultdict(list)
rows = []
for f in sorted(os.listdir(MOD)):
    if not f.endswith(".json"):
        continue
    d = json.loads(open(os.path.join(MOD, f), encoding="utf-8").read())
    mid = d.get("my_id", "<none>")
    by_id[mid].append(f)
    rows.append((f, mid, d.get("item_type"), d.get("name"), d.get("relative_icon_path"),
                 len(d.get("datas", [])), "starting_weapons" in d))

print("json files           :", len(rows))
print("distinct my_id       :", len(by_id))
dups = {k: v for k, v in by_id.items() if len(v) > 1}
print("duplicate my_id      :", len(dups))
for k, v in dups.items():
    print("   %s -> %s" % (k, v))

print()
print("item_type distribution:",
      collections.Counter(r[2] for r in rows))
print("files whose my_id is empty/missing:",
      sum(1 for r in rows if r[1] in ("", "<none>")))
print()
print("sample rows (file, my_id, item_type, name, icon, #datas, has_starting_weapons):")
for r in rows[:8]:
    print("   %s" % (r,))
