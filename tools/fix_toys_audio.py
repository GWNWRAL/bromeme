#!/usr/bin/env python3
"""
Toys&Balls audio fix: wire up declared-but-unused shooting sounds.

For every .tres that declares AudioStream ext_resources but leaves
`shooting_sounds` empty, fill the array with those resources in ascending id
order. That matches the convention already used by the working files
(football/water_gun/glass_marble/toy_hammer/tennis_racket/baseball_bat all use
`[ ExtResource( 3 ), ExtResource( 4 ), ... ]` in id order).

Only the single `shooting_sounds = [ ]` line is touched.
"""
import os, re, shutil, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
BACKUP_ROOT = r"D:\DSH\_aitato_work\ToysBalls_audio_backup"

APPLY = "--apply" in sys.argv

changed = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith(".tres"):
            continue
        p = os.path.join(dp, f)
        txt = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, MOD).replace("\\", "/")

        declared = {}
        for m in re.finditer(r'\[ext_resource path="([^"]+)" type="AudioStream" id=(\d+)\]', txt):
            declared[int(m.group(2))] = m.group(1)

        m = re.search(r'^(\s*)shooting_sounds\s*=\s*\[\s*\]\s*$', txt, re.M)
        if not m or not declared:
            continue

        ids = sorted(declared)
        items = ", ".join("ExtResource( %d )" % i for i in ids)
        replacement = "%sshooting_sounds = [ %s ]" % (m.group(1), items)
        new_txt = txt[:m.start()] + replacement + txt[m.end():]

        changed.append((rel, ids, [declared[i] for i in ids]))

        if APPLY:
            bak = os.path.join(BACKUP_ROOT, rel)
            os.makedirs(os.path.dirname(bak), exist_ok=True)
            if not os.path.exists(bak):
                shutil.copy2(p, bak)
            open(p, "w", encoding="utf-8", newline="").write(new_txt)

print("=" * 78)
print("%s  (%d files)" % ("APPLYING" if APPLY else "DRY RUN - pass --apply to write", len(changed)))
print("=" * 78)
for rel, ids, paths in changed:
    print("  %s" % rel)
    for i, pp in zip(ids, paths):
        print("      id=%d  %s" % (i, pp))
if APPLY:
    print()
    print("backups of the originals: %s" % BACKUP_ROOT)
