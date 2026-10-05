#!/usr/bin/env python3
"""
The `name` field on ItemParentData / WeaponData is a translation KEY everywhere
in vanilla and in other mods - the UI renders it with tr(item.name).

This compares Toys&Balls against vanilla and Dbear-Capybara: for every *_data.tres
it extracts `name` and reports which values are NOT key-shaped (i.e. literal text
that will show the same in every language and cannot be translated).
"""
import os, re, glob, collections

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
VANILLA = r"D:\DSH\_full_pck"
CAPY = r"D:\DSH\mods\Dbear-Capybara\mods-unpacked\Dbear-Capybara"

KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")     # 纯 ASCII 标识符形状
NAME_RE = re.compile(r'^name\s*=\s*"([^"]*)"', re.M)
ID_RE = re.compile(r'^my_id\s*=\s*"([^"]*)"', re.M)


def scan(root, label, pattern="**/*_data.tres"):
    ok, bad, total = 0, [], 0
    for p in glob.glob(os.path.join(root, pattern), recursive=True):
        try:
            t = open(p, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        m = NAME_RE.search(t)
        if not m:
            continue
        total += 1
        nm = m.group(1)
        mid = ID_RE.search(t)
        mid = mid.group(1) if mid else "?"
        if KEY_RE.match(nm):
            ok += 1
        else:
            bad.append((os.path.relpath(p, root).replace("\\", "/"), mid, nm))
    print("=" * 76)
    print("%s   (%d files with a name field)" % (label, total))
    print("=" * 76)
    print("  key-shaped (conformant) : %d" % ok)
    print("  LITERAL text (not a key) : %d" % len(bad))
    for rel, mid, nm in bad[:60]:
        print("      %-58s id=%-34s name=%r" % (rel, mid, nm))
    if len(bad) > 60:
        print("      ... and %d more" % (len(bad) - 60))
    print()
    return bad


scan(VANILLA, "VANILLA  (res://weapons/**/*_data.tres)")
scan(CAPY, "CAPYBARA (contents/weapons/**/*_data.tres)", "contents/**/*_data.tres")
b = scan(MOD, "TOYS&BALLS (content/**/*_data.tres)", "content/**/*_data.tres")

# also check items / pets
print("=" * 76)
print("TOYS&BALLS items & pets")
print("=" * 76)
extra = []
for p in glob.glob(os.path.join(MOD, "content", "**", "*.tres"), recursive=True):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    if rel.endswith("_data.tres"):
        continue
    try:
        t = open(p, encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    m = NAME_RE.search(t)
    if not m:
        continue
    nm = m.group(1)
    if not KEY_RE.match(nm):
        mid = ID_RE.search(t)
        extra.append((rel, mid.group(1) if mid else "?", nm))
print("  non-key names: %d" % len(extra))
for rel, mid, nm in extra[:60]:
    print("      %-58s id=%-32s name=%r" % (rel, mid, nm))
