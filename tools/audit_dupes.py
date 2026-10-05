#!/usr/bin/env python3
"""
Investigate the duplicate my_id findings:
  item_toy_buzz / item_toy_woody / toy_buzz / toy_woody

Two parallel copies exist:
    content/pets/<x>/...      and      content/weapons/melee/toy_story/pets/...

Questions:
  1. are the files identical?
  2. is BOTH copies reachable from content_data (i.e. both get registered)?
  3. does the game end up with two things sharing an id?
"""
import os, re, hashlib, collections

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
PREFIX = "res://mods-unpacked/General-Toys_Balls/"

PAIRS = [
    ("content/pets/buzz/buzz_pet_item.tres", "content/weapons/melee/toy_story/pets/buzz_pet_item.tres"),
    ("content/pets/woody/woody_pet_item.tres", "content/weapons/melee/toy_story/pets/woody_pet_item.tres"),
    ("content/items/buzz/buzz_item_data.tres", "content/weapons/melee/toy_story/pets/buzz_item_data.tres"),
    ("content/items/woody/woody_item_data.tres", "content/weapons/melee/toy_story/pets/woody_item_data.tres"),
    ("content/pets/buzz/buzz_pet.gd", "content/weapons/melee/toy_story/pets/buzz_pet.gd"),
    ("content/pets/woody/woody_pet.gd", "content/weapons/melee/toy_story/pets/woody_pet.gd"),
]

def md5(rel):
    p = os.path.join(MOD, rel.replace("/", os.sep))
    if not os.path.exists(p):
        return None
    return hashlib.md5(open(p, "rb").read()).hexdigest()

print("=" * 78)
print("1) are the duplicated files identical?")
print("=" * 78)
for a, b in PAIRS:
    ha, hb = md5(a), md5(b)
    status = "identical" if (ha and ha == hb) else ("DIFFERENT" if ha and hb else "missing one side")
    print("  %-9s %s" % (status, os.path.basename(a)))
    if ha != hb:
        print("        top : %s" % a)
        print("        ts  : %s" % b)

print()
print("=" * 78)
print("2) which copy is reachable from content_data?")
print("=" * 78)

def ext_refs(rel):
    p = os.path.join(MOD, rel.replace("/", os.sep))
    if not os.path.exists(p):
        return []
    txt = open(p, encoding="utf-8", errors="replace").read()
    out = []
    for path, typ, rid in re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M):
        if path.startswith(PREFIX):
            out.append(path[len(PREFIX):])
    return out

seen = set()
frontier = ["content_data/content_data.tres", "content_data/content_data_effects.tres"]
while frontier:
    rel = frontier.pop()
    if rel in seen:
        continue
    seen.add(rel)
    for nxt in ext_refs(rel):
        if nxt not in seen:
            frontier.append(nxt)

for a, b in PAIRS:
    print("  %-58s reachable=%s" % (a, a in seen))
    print("  %-58s reachable=%s" % (b, b in seen))

print()
print("=" * 78)
print("3) what does toy_story_data.tres pull in?")
print("=" * 78)
for r in ext_refs("content/weapons/melee/toy_story/toy_story_data.tres"):
    print("   ", r)
