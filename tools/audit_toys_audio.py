#!/usr/bin/env python3
"""
Resolve every audio reference in the Toys&Balls source tree and check it exists
either in the mod itself (zipped/unpacked) or in the vanilla game pck.

Reports the ones that resolve nowhere -> those are the "missing audio" cases.
"""
import os, re, glob

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
VANILLA = r"D:\DSH\_full_pck"      # extracted Brotato.pck
MOD_PREFIX = "res://mods-unpacked/General-Toys_Balls/"
AUDIO_RE = re.compile(r'res://[^"\s]*\.(?:wav|ogg|mp3)')

# audio actually present in the mod tree
mod_files = set()
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        rel = os.path.relpath(os.path.join(dp, f), MOD).replace("\\", "/")
        mod_files.add(rel)

# compiled audio in the mod's .import/ (root of the zip)
mod_import = set()
imp_root = os.path.join(os.path.dirname(MOD), "..", ".import")
imp_root = os.path.normpath(r"D:\DSH\Toys_Balls_build_v4\.import")
if os.path.isdir(imp_root):
    mod_import = set(os.listdir(imp_root))

vanilla_files = set()
for dp, dn, fn in os.walk(VANILLA):
    for f in fn:
        rel = os.path.relpath(os.path.join(dp, f), VANILLA).replace("\\", "/")
        vanilla_files.add(rel)


def check(ref):
    """Return (kind, detail) for an audio ref."""
    if ref.startswith(".import/") or ref.startswith("res://.import/"):
        name = ref.split("/")[-1]
        return ("mod-import", name in mod_import)
    if ref.startswith(MOD_PREFIX):
        rel = ref[len(MOD_PREFIX):]
        return ("mod", rel in mod_files)
    if ref.startswith("res://"):
        rel = ref[len("res://"):]
        # vanilla path -> .wav / .ogg straight in the pck, or via .import
        if rel in vanilla_files:
            return ("vanilla", True)
        base = os.path.basename(rel)
        for v in vanilla_files:
            if v.endswith("/" + base) or v == base:
                return ("vanilla", True)
        return ("vanilla", False)
    return ("other", False)


rows = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith((".gd", ".tres", ".tscn")):
            continue
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        rel = os.path.relpath(p, MOD).replace("\\", "/")
        for m in AUDIO_RE.finditer(txt):
            rows.append((rel, m.group(0)))

seen = {}
for src, ref in rows:
    seen.setdefault(ref, []).append(src)

print("=" * 78)
print("AUDIO REFERENCES IN TOYS&BALLS  (%d distinct)" % len(seen))
print("=" * 78)
missing = []
for ref in sorted(seen):
    kind, ok = check(ref)
    flag = "OK  " if ok else "MISS"
    if not ok:
        missing.append((ref, kind, seen[ref]))
    if len(seen[ref]) <= 2:
        print("  %s [%s] %s   <- %s" % (flag, kind, ref, ", ".join(sorted(set(seen[ref])))))
    else:
        print("  %s [%s] %s   <- %d sites" % (flag, kind, ref, len(set(seen[ref]))))

print()
print("=" * 78)
print("MISSING (%d)" % len(missing))
print("=" * 78)
for ref, kind, srcs in missing:
    print("  %s   [%s]" % (ref, kind))
    for s in sorted(set(srcs)):
        print("      used by %s" % s)
