#!/usr/bin/env python3
"""
Toys&Balls: full audio resolvability audit.

For every weapon/projectile stat file, extract each AudioStream ext_resource and
shooting_sounds array, then check whether the referenced file actually exists:

  * mod-owned path  -> must exist in the build tree
  * vanilla path    -> must exist in the extracted Brotato.pck *or* in the DLC pck
    (note: exported audio exists only as "<name>.import"; the compiled payload
     lives in the pck's .import/ directory)

Flags: empty array, dangling reference, missing compiled payload, duplicate ids.
"""
import os, re, glob, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
PKCS = [r"D:\DSH\_full_pck", r"D:\DSH\_dlc"]
MOD_PREFIX = "res://mods-unpacked/General-Toys_Balls/"

# ---- index the mod tree -------------------------------------------------
mod_files = set()
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        mod_files.add(os.path.relpath(os.path.join(dp, f), MOD).replace("\\", "/"))
mod_import = set()
imp = r"D:\DSH\Toys_Balls_build_v4\.import"
if os.path.isdir(imp):
    mod_import = set(os.listdir(imp))

# ---- index the game pcks -------------------------------------------------
game = set()
game_import = set()
for root in PKCS:
    if not os.path.isdir(root):
        continue
    for dp, dn, fn in os.walk(root):
        for f in fn:
            rel = os.path.relpath(os.path.join(dp, f), root).replace("\\", "/")
            if rel.startswith(".import/"):
                game_import.add(rel[len(".import/"):])
            game.add(rel)


def resolve(path):
    """-> (ok, how)"""
    if path.startswith(MOD_PREFIX):
        rel = path[len(MOD_PREFIX):]
        if rel in mod_files:
            # audio also needs its compiled payload in the mod's .import/
            base = os.path.basename(rel)
            has_payload = any(n.startswith(base + "-") for n in mod_import)
            return (True, "mod(payload)" if has_payload else "mod(NO PAYLOAD)")
        return (False, "mod(MISSING)")
    if path.startswith("res://"):
        rel = path[len("res://"):]
        if rel in game:
            return (True, "vanilla")
        if rel + ".import" in game:
            base = os.path.basename(rel)
            ok = any(n.startswith(base + "-") for n in game_import)
            return (True, "vanilla+payload" if ok else "vanilla(NO PAYLOAD)")
        return (False, "vanilla(MISSING)")
    return (False, "unknown")


stats = sorted(glob.glob(os.path.join(MOD, "content", "**", "*stats*.tres"), recursive=True))
print("stat files scanned:", len(stats))

problems = []
audio_refs = 0
for p in stats:
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()

    ext = {int(i): (path, typ)
           for path, typ, i in re.findall(
               r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M)}

    ids_in_arrays = set()
    for m in re.finditer(r'^(\w*sounds?\w*)\s*=\s*\[([^\]]*)\]', txt, re.M):
        field, body = m.group(1), m.group(2)
        ids = [int(x) for x in re.findall(r'ExtResource\(\s*(\d+)\s*\)', body)]
        ids_in_arrays.update(ids)
        if not ids:
            if field == "shooting_sounds" and any(t == "AudioStream" for _, t in ext.values()):
                problems.append("%s: %s is EMPTY but audio is declared" % (rel, field))

    for rid, (path, typ) in sorted(ext.items()):
        if typ != "AudioStream":
            continue
        audio_refs += 1
        ok, how = resolve(path)
        if not ok:
            problems.append("%s: id=%d dangling -> %s" % (rel, rid, path))
        elif "NO PAYLOAD" in how:
            problems.append("%s: id=%d has no compiled payload -> %s" % (rel, rid, path))
        if rid not in ids_in_arrays:
            problems.append("%s: id=%d declared but never used in any sound array -> %s"
                            % (rel, rid, path))

print("audio ext_resources:", audio_refs)
print()
print("PROBLEMS:", len(problems))
for x in problems:
    print("   -", x)
if not problems:
    print("   (none - every audio reference resolves and is wired up)")
