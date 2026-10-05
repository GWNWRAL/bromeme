#!/usr/bin/env python3
"""
Bromeme / brolab forensics.

Questions:
  1. what does timestamp.txt contain, and do the mod's file names follow it?
  2. for the mod's own items, what is inside `my_id`? Is the timestamp used there
     too (which would make ids collide with - or be derived from - the file name)?
  3. which entries in the live brolab dir belong to this mod (so we can tell mod
     leftovers apart from the user's own BroLab creations)?
"""
import json, os, collections

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
LAB = r"C:\Users\31350\AppData\Roaming\Brotato\brolab"

ts = open(os.path.join(MOD, "timestamp.txt"), encoding="utf-8").read().strip()
print("timestamp.txt : %r" % ts)

res = os.path.join(MOD, "resources")
mod_jsons = sorted(f for f in os.listdir(res) if f.endswith(".json"))
mod_icons = sorted(f for f in os.listdir(os.path.join(res, "icons")) if f.endswith(".png"))
print("mod json files: %d   mod icons: %d" % (len(mod_jsons), len(mod_icons)))
print("first/last json: %s ... %s" % (mod_jsons[0], mod_jsons[-1]))

print()
print("=" * 78)
print("my_id patterns in the mod's own json files")
print("=" * 78)
pats = collections.Counter()
samples = {}
for f in mod_jsons:
    d = json.loads(open(os.path.join(res, f), encoding="utf-8").read())
    mid = d.get("my_id", "")
    # keep the shape, drop digits
    shape = "".join("0" if c.isdigit() else c for c in mid)
    pats[shape] += 1
    samples.setdefault(shape, []).append(mid)
for shape, n in pats.most_common(20):
    print("  %-46s x%d" % (shape, n))
    for s in samples[shape][:3]:
        print("        e.g. %s" % s)

print()
print("=" * 78)
print("do any my_id values equal / contain the timestamp %s ?" % ts)
print("=" * 78)
hit = 0
for f in mod_jsons:
    d = json.loads(open(os.path.join(res, f), encoding="utf-8").read())
    if ts in str(d.get("my_id", "")) or ts in f:
        hit += 1
print("  files where timestamp appears in my_id or filename:", hit)

print()
print("=" * 78)
print("live brolab dir: which files match the mod's set?")
print("=" * 78)
lab_jsons = sorted(f for f in os.listdir(LAB) if f.endswith(".json"))
lab_icons = set(f for f in os.listdir(os.path.join(LAB, "icons")))
mod_set = set(mod_jsons)
lab_set = set(lab_jsons)
print("  mod json      : %d" % len(mod_set))
print("  brolab json   : %d" % len(lab_set))
print("  mod ∩ brolab  : %d   (already imported)" % len(mod_set & lab_set))
print("  mod only      : %d   (not yet imported)" % len(mod_set - lab_set))
print("  brolab only   : %d   (other sources / leftovers)" % len(lab_set - mod_set))
print()
print("  mod icons present in brolab/icons : %d / %d"
      % (len(set(mod_icons) & lab_icons), len(mod_icons)))
print("  mod icons ALSO sitting in brolab root (misplaced): %d"
      % len(set(mod_icons) & set(f for f in os.listdir(LAB) if f.endswith(".png"))))
