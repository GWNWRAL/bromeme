#!/usr/bin/env python3
"""
Find weapons that DECLARE audio ExtResources but leave shooting_sounds empty.

That pattern is a bug rather than an intentional silence: the resource is loaded
and referenced, but never wired into the array the game actually plays, so the
weapon fires silently.

Also reports sound-bearing fields on projectiles/effects for completeness.
"""
import os, re

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
AUDIO_EXT = (".wav", ".ogg", ".mp3")

rows = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith(".tres"):
            continue
        p = os.path.join(dp, f)
        txt = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, MOD).replace("\\", "/")

        # audio ext_resources declared in this file
        declared = {}
        for m in re.finditer(r'\[ext_resource path="([^"]+)" type="AudioStream" id=(\d+)\]', txt):
            declared[m.group(2)] = m.group(1)

        # shooting_sounds / any *_sounds array content
        arrays = {}
        for m in re.finditer(r'^(\w*sounds?\w*)\s*=\s*\[([^\]]*)\]', txt, re.M):
            arrays[m.group(1)] = m.group(2).strip()

        used_ids = set(re.findall(r'ExtResource\(\s*(\d+)\s*\)',
                                  "".join(arrays.values())))
        orphan = {i: p for i, p in declared.items() if i not in used_ids}

        if declared:
            rows.append((rel, declared, arrays, orphan))

print("=" * 78)
print("WEAPONS DECLARING AUDIO")
print("=" * 78)
orphan_total = 0
for rel, declared, arrays, orphan in rows:
    tag = "ORPHAN" if orphan else "ok    "
    sound_arr = arrays.get("shooting_sounds", None)
    arr_desc = "[]" if sound_arr == "" else (sound_arr if sound_arr is not None else "<none>")
    if orphan:
        orphan_total += 1
        print("  %s %s" % (tag, rel))
        print("        shooting_sounds = [%s]" % arr_desc)
        for i, p in sorted(orphan.items()):
            print("        declared but UNUSED: id=%s  %s" % (i, p))

print()
print("files with orphan audio declarations: %d / %d" % (orphan_total, len(rows)))
