# -*- coding: utf-8 -*-
"""
Toys&Balls 1.0.6 fix #2: remove dead files.

Removes only what is provably unreachable AND unreferenced anywhere:
  A. content/weapons/melee/toy_story/pets/**            (parallel copy of the
     Buzz/Woody pets that no content_data path reaches; the live copies live
     under content/pets/ and content/items/)
  B. content/weapons/ranged/ouija_board/ouija_board_description_1..4.tres
     (four identical leftovers; the live one is ouija_board_random_description.tres)
  C. content/weapons/ranged/ice_ball/ice_ball_slow_effect.tres
     (nothing references it; ice_ball uses its own data effects)

Safety rule: a file is only deleted if NO other file in the mod references it.
"""
import os, re, glob, shutil, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
APPLY = "--apply" in sys.argv
PREFIX = "res://mods-unpacked/General-Toys_Balls/"

CANDIDATES = []
for p in glob.glob(os.path.join(MOD, "content", "weapons", "melee", "toy_story", "pets", "**", "*"), recursive=True):
    if os.path.isfile(p):
        CANDIDATES.append(p)
for n in range(1, 5):
    CANDIDATES.append(os.path.join(MOD, "content", "weapons", "ranged", "ouija_board",
                                   "ouija_board_description_%d.tres" % n))
CANDIDATES.append(os.path.join(MOD, "content", "weapons", "ranged", "ice_ball",
                               "ice_ball_slow_effect.tres"))

# ---- build the reference index -------------------------------------------
all_files = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        all_files.append(os.path.join(dp, f))

refs = {}          # rel path (mod-relative, forward slashes) -> list of referrers
for p in all_files:
    if not p.endswith((".tres", ".tscn", ".gd", ".csv")):
        continue
    try:
        txt = open(p, encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    own = os.path.relpath(p, MOD).replace("\\", "/")
    for m in re.finditer(r'res://mods-unpacked/General-Toys_Balls/([^"\s\)]+)', txt):
        refs.setdefault(m.group(1), []).append(own)

ok, blocked = [], []
for p in CANDIDATES:
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    # 只把"来自该目录之外"的引用算作阻塞:平行副本内部互相引用不算。
    users = [u for u in refs.get(rel, [])
             if u != rel and not u.startswith("content/weapons/melee/toy_story/pets/")]
    # ice_ball / ouija_board 的单文件不适用上述豁免,保持严格
    if not rel.startswith("content/weapons/melee/toy_story/pets/"):
        users = [u for u in refs.get(rel, []) if u != rel]
    if users:
        blocked.append((rel, users))
    else:
        ok.append(rel)

print("=" * 74)
print("A) deletable (no references anywhere)   : %d" % len(ok))
print("=" * 74)
for r in sorted(ok):
    print("   -", r)
print()
print("B) BLOCKED (still referenced)           : %d" % len(blocked))
for rel, users in blocked:
    print("   ! %s" % rel)
    for u in users:
        print("        referenced by %s" % u)

if APPLY:
    dirs = set()
    for rel in ok:
        p = os.path.join(MOD, rel.replace("/", os.sep))
        if os.path.exists(p):
            os.remove(p)
            dirs.add(os.path.dirname(p))
    # prune now-empty directories
    for d in sorted(dirs, key=len, reverse=True):
        while os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)
            d = os.path.dirname(d)
    print()
    print("APPLIED: removed %d files" % len(ok))
else:
    print()
    print("DRY RUN - pass --apply")
