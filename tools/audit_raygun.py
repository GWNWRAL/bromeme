#!/usr/bin/env python3
"""Resolve weapon `projectile_scene` / `scene` / `stats` refs in Toys&Balls and
check the ray_gun projectile situation, plus scan for Godot 4 type="" strings."""
import os, re, glob

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"

def ext_map(txt):
    return {int(i): (p, t) for p, t, i in
            re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M)}

print("=" * 76)
print("ray_gun stats: where does projectile_scene point?")
print("=" * 76)
for p in sorted(glob.glob(os.path.join(MOD, "content/weapons/ranged/ray_gun/**/*stats.tres"), recursive=True)):
    txt = open(p, encoding="utf-8", errors="replace").read()
    ex = ext_map(txt)
    m = re.search(r'^projectile_scene\s*=\s*ExtResource\(\s*(\d+)\s*\)', txt, re.M)
    if m:
        rid = int(m.group(1))
        print("  %-24s -> %s" % (os.path.basename(p), ex.get(rid, ("<unresolved>",))[0]))

print()
print("=" * 76)
print("which weapon stats point at the custom ray_gun_projectile.tscn?")
print("=" * 76)
hits = 0
for p in glob.glob(os.path.join(MOD, "content", "**", "*.tres"), recursive=True):
    txt = open(p, encoding="utf-8", errors="replace").read()
    if "ray_gun_projectile" in txt:
        hits += 1
        print("  ", os.path.relpath(p, MOD).replace("\\", "/"))
print("  total:", hits)

print()
print("=" * 76)
print("Godot 4 type names used as type=\"...\" in ext_resource lines")
print("=" * 76)
G4 = ["Texture2D", "Sprite2D", "Marker2D", "AudioStreamWAV", "PackedScene2D"]
bad = 0
for p in glob.glob(os.path.join(MOD, "content", "**", "*"), recursive=True):
    if not p.endswith((".tres", ".tscn")):
        continue
    txt = open(p, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M):
        if m.group(2) in G4:
            bad += 1
            print("  %-62s type=%s" % (os.path.relpath(p, MOD).replace("\\", "/"), m.group(2)))
print("  total:", bad)
