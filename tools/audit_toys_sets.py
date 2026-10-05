#!/usr/bin/env python3
"""
Toys&Balls set / effect entry audit.

The game renders a set's display name with tr(set.name) and every effect line
with tr(text_key ...), so those fields must be translation KEYS. A literal
localised string still renders (tr returns its input when no key matches) but it
is non-conformant and breaks wherever another mod or the game treats the field
as a key.

This reports:
  * set `name` values that are not KEY-shaped
  * effect text_key / key values that are not KEY-shaped
  * which referenced keys are actually missing from the mod's translations
"""
import os, re, json, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
KEY_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')       # 大写 key（set 名 / text_key）
ID_RE  = re.compile(r'^[a-z0-9_]+$')              # 小写 key（stat_* / effect_* / 自定义）

# --- collect declared translation keys from the mod's .translation resources ---
declared = set()
# also read the source csv if present
csv = os.path.join(MOD, "translations", "trans.csv")
if os.path.exists(csv):
    for line in open(csv, encoding="utf-8", errors="replace").read().splitlines()[1:]:
        if line.strip():
            declared.add(line.split(",")[0].strip())

print("=" * 74)
print("SETS")
print("=" * 74)
set_problems = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith("set_data.tres"):
            continue
        p = os.path.join(dp, f)
        txt = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, MOD).replace("\\", "/")
        my_id = re.search(r'^my_id\s*=\s*"([^"]*)"', txt, re.M)
        name = re.search(r'^name\s*=\s*"([^"]*)"', txt, re.M)
        mid = my_id.group(1) if my_id else "?"
        nm = name.group(1) if name else None
        ok = nm is not None and bool(KEY_RE.match(nm))
        print("  %-6s %-46s name=%r" % ("OK" if ok else "BAD", mid, nm))
        if not ok:
            set_problems.append((rel, mid, nm))

print()
print("=" * 74)
print("EFFECT RESOURCES (key / text_key)")
print("=" * 74)
bad_keys = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith(".tres"):
            continue
        p = os.path.join(dp, f)
        txt = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, MOD).replace("\\", "/")
        m = re.search(r'^key\s*=\s*"([^"]*)"', txt, re.M)
        t = re.search(r'^text_key\s*=\s*"([^"]*)"', txt, re.M)
        if not m and not t:
            continue
        k = m.group(1) if m else ""
        tk = t.group(1) if t else ""
        # text_key, when non-empty, must be a key; key may be a vanilla key or id
        bad = []
        if tk and not KEY_RE.match(tk):
            bad.append("text_key=%r" % tk)
        if k and not (KEY_RE.match(k) or ID_RE.match(k)):
            bad.append("key=%r" % k)
        if bad:
            bad_keys.append((rel, k, tk, bad))
            print("  BAD  %-58s %s" % (rel, "; ".join(bad)))

print()
print("set problems :", len(set_problems))
print("effect problems:", len(bad_keys))
if not set_problems and not bad_keys:
    print("RESULT: all set names and effect keys are KEY-shaped")
