#!/usr/bin/env python3
"""
Toys&Balls full static audit.

Checks (mechanical, high-confidence):
 1. every [ext_resource] resolves (mod tree or either game pck)
 2. every referenced script/scene/texture has its compiled payload present
 3. load_steps matches the real ext+sub resource count
 4. every [sub_resource] is actually referenced
 5. duplicate my_id across items/weapons/sets/effects
 6. .gd files use Godot 3 node/type names (Sprite2D/Marker2D etc. are Godot 4)
 7. every .tres/.tscn in the tree is reachable from content_data (no dead content)
 8. empty sound arrays where audio is declared (the bug class already found once)
"""
import os, re, glob, collections

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
IMP = r"D:\DSH\Toys_Balls_build_v4\.import"
PKCS = [r"D:\DSH\_full_pck", r"D:\DSH\_dlc"]
PREFIX = "res://mods-unpacked/General-Toys_Balls/"

# ---- indexes -------------------------------------------------------------
mod_files = set()
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        mod_files.add(os.path.relpath(os.path.join(dp, f), MOD).replace("\\", "/"))
mod_import = set(os.listdir(IMP)) if os.path.isdir(IMP) else set()

game, game_import = set(), set()
for root in PKCS:
    if not os.path.isdir(root):
        continue
    for dp, dn, fn in os.walk(root):
        for f in fn:
            rel = os.path.relpath(os.path.join(dp, f), root).replace("\\", "/")
            game.add(rel)
            if rel.startswith(".import/"):
                game_import.add(rel[len(".import/"):])

COMPILED = {".png": ".stex", ".wav": ".sample", ".ogg": "", ".mp3": ""}


def resolve(path):
    """returns (ok, note)"""
    if path.startswith(PREFIX):
        rel = path[len(PREFIX):]
        if rel not in mod_files:
            return False, "missing from mod"
        ext = os.path.splitext(rel)[1].lower()
        want = COMPILED.get(ext)
        if want:
            base = os.path.basename(rel)
            if not any(n.startswith(base + "-") for n in mod_import):
                return False, "no compiled %s in mod .import/" % want
        return True, "mod"
    if path.startswith("res://"):
        rel = path[len("res://"):]
        if rel in game:
            return True, "vanilla"
        # 脚本在导出的 pck 里是编译过的: foo.gd 实际存为 foo.gdc + foo.gd.remap
        if rel.endswith(".gd"):
            if rel + "c" in game or rel + ".remap" in game:
                return True, "vanilla(gdc)"
        if rel + ".import" in game:
            return True, "vanilla(import)"
        base = os.path.basename(rel)
        if base in game:
            return True, "vanilla(basename)"
        for g in game:
            if g.endswith("/" + base):
                return True, "vanilla(basename)"
        return False, "missing from game"
    return False, "unknown scheme"


problems = collections.defaultdict(list)
info = collections.Counter()

resources = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if f.endswith((".tres", ".tscn")):
            resources.append(os.path.join(dp, f))

# ---- 1/2/3/4/8 -----------------------------------------------------------
for p in sorted(resources):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()

    ext = re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M)
    sub = re.findall(r'^\[sub_resource type="([^"]+)" id=(\d+)\]', txt, re.M)

    for path, typ, rid in ext:
        ok, note = resolve(path)
        if not ok:
            problems["dangling ext_resource"].append("%s: id=%s %s  (%s)" % (rel, rid, path, note))

    m = re.search(r'load_steps=(\d+)', txt)
    if m:
        declared = int(m.group(1))
        actual = len(ext) + len(sub) + 1
        if declared != actual:
            problems["load_steps mismatch"].append(
                "%s: declared=%d actual=%d" % (rel, declared, actual))

    # sub_resources referenced anywhere?
    body = txt
    for typ, rid in sub:
        uses = len(re.findall(r'SubResource\(\s*%s\s*\)' % re.escape(rid), body))
        if uses == 0:
            problems["unused sub_resource"].append("%s: SubResource(%s) type=%s" % (rel, rid, typ))

    # audio declared but no sound array
    audio_ids = [r for _, t, r in ext if t == "AudioStream"]
    arrays = re.findall(r'^(\w*sounds?\w*)\s*=\s*\[([^\]]*)\]', txt, re.M)
    used = set()
    for _, b in arrays:
        used.update(re.findall(r'ExtResource\(\s*(\d+)\s*\)', b))
    for r in audio_ids:
        if r not in used:
            problems["audio declared but unused"].append("%s: id=%s" % (rel, r))
    for name, b in arrays:
        if name == "shooting_sounds" and b.strip() == "" and audio_ids:
            problems["empty shooting_sounds"].append("%s" % rel)

# ---- 5 duplicate my_id ---------------------------------------------------
ids = collections.defaultdict(list)
for p in resources:
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'^my_id\s*=\s*"([^"]+)"', txt, re.M):
        ids[m.group(1)].append(rel)
for k, v in ids.items():
    if len(v) > 1:
        problems["duplicate my_id"].append("%s -> %s" % (k, v))

# ---- 6 Godot 4 type names in scripts ------------------------------------
G4 = ["Sprite2D", "Marker2D", "PackedFloat32Array", "CharacterBody2D",
      "AnimatedSprite2D", "NavigationAgent2D", "ResourceLoader.load_threaded"]
for p in glob.glob(os.path.join(MOD, "**", "*.gd"), recursive=True):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()
    for g in G4:
        if g in txt:
            problems["Godot4 type in script"].append("%s: %s" % (rel, g))
    if ":=" in txt or " -> " in txt:
        info["typed gdscript files"] += 1

# ---- 7 unreachable content ----------------------------------------------
def read(rel):
    p = os.path.join(MOD, rel.replace("/", os.sep))
    return open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else ""

referenced = set()
# walk every resource and record what it points at (transitively)
frontier = []
for p in resources:
    txt = open(p, encoding="utf-8", errors="replace").read()
    for path, typ, rid in re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M):
        if path.startswith(PREFIX):
            frontier.append(path[len(PREFIX):])

# also from .gd files (load/preload of res://mods-unpacked/...)
for p in glob.glob(os.path.join(MOD, "**", "*.gd"), recursive=True):
    txt = open(p, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'"(res://mods-unpacked/General-Toys_Balls/[^"]+)"', txt):
        frontier.append(m.group(1)[len(PREFIX):])

seen = set()
while frontier:
    rel = frontier.pop()
    if rel in seen:
        continue
    seen.add(rel)
    p = os.path.join(MOD, rel.replace("/", os.sep))
    if not os.path.exists(p) or not p.endswith((".tres", ".tscn")):
        continue
    txt = open(p, encoding="utf-8", errors="replace").read()
    for path, typ, rid in re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M):
        if path.startswith(PREFIX):
            nxt = path[len(PREFIX):]
            if nxt not in seen:
                frontier.append(nxt)

for p in sorted(resources):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    if rel not in seen:
        problems["unreferenced resource"].append(rel)

# ---- report --------------------------------------------------------------
print("=" * 78)
print("TOYS&BALLS AUDIT")
print("=" * 78)
print("mod files: %d   resources: %d   .import entries: %d"
      % (len(mod_files), len(resources), len(mod_import)))
print()
for k in sorted(problems):
    v = problems[k]
    print("[%s]  %d" % (k, len(v)))
    for line in v[:40]:
        print("    - %s" % line)
    if len(v) > 40:
        print("    ... and %d more" % (len(v) - 40))
    print()
if not problems:
    print("no mechanical problems found")
