#!/usr/bin/env python3
"""
Validate the 21 edited Toys&Balls stat files without launching the game:

  * the .tres is structurally intact (gd_resource header / one [resource] block)
  * load_steps matches the real resource count
  * every ext_resource path resolves - either to a mod file or to a vanilla file
    (vanilla audio only exists as .import inside the pck, so accept that too)
  * shooting_sounds references only ids that are declared in the same file
  * the sound set is identical to vanilla javelin's
"""
import os, re, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
MOD_PREFIX = "res://mods-unpacked/General-Toys_Balls/"
VANILLA = r"D:\DSH\_full_pck"

TARGETS = [
    "content/weapons/ranged/basketball/%s/basketball%s_stats.tres",
]
import glob

files = []
for pat in ("basketball", "boomerang", "easter_egg", "ice_ball", "lego_box"):
    files += glob.glob(os.path.join(MOD, "content", "weapons", "ranged", pat, "[0-9]", "*_stats.tres"))
files += glob.glob(os.path.join(MOD, "content", "weapons", "ranged", "quidditch_ball", "*_stats.tres"))

# vanilla resource index (files as they exist in the extracted pck)
vanilla = set()
for dp, dn, fn in os.walk(VANILLA):
    for f in fn:
        vanilla.add(os.path.relpath(os.path.join(dp, f), VANILLA).replace("\\", "/"))


def resolves(path):
    if path.startswith(MOD_PREFIX):
        rel = path[len(MOD_PREFIX):]
        return os.path.exists(os.path.join(MOD, rel.replace("/", os.sep)))
    if path.startswith("res://"):
        rel = path[len("res://"):]
        if rel in vanilla:
            return True
        # exported audio lives as <name>.import only
        if rel + ".import" in vanilla:
            return True
        base = os.path.basename(rel)
        for v in vanilla:
            if v.endswith("/" + base) or v.endswith("/" + base + ".import"):
                return True
        return False
    return False


JAVELIN_SOUNDS = [
    "res://weapons/melee_sounds/whoosh_swish_high_fast_01.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_04.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_03.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_02.wav",
]

problems = []
for p in sorted(files):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()

    if not txt.startswith("[gd_resource type=\"Resource\""):
        problems.append("%s: bad header" % rel)
    if txt.count("[resource]") != 1:
        problems.append("%s: expected exactly one [resource] block" % rel)

    ext = re.findall(r'^\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]', txt, re.M)
    sub = re.findall(r'^\[sub_resource type="([^"]+)" id=(\d+)\]', txt, re.M)

    m = re.search(r'load_steps=(\d+)', txt)
    declared_steps = int(m.group(1))
    actual_steps = len(ext) + len(sub) + 1
    if declared_steps != actual_steps:
        problems.append("%s: load_steps=%d but actual=%d" % (rel, declared_steps, actual_steps))

    for path, typ, rid in ext:
        if not resolves(path):
            problems.append("%s: unresolved ext_resource %s" % (rel, path))

    # shooting_sounds must only use declared ids
    m = re.search(r'^shooting_sounds\s*=\s*\[([^\]]*)\]', txt, re.M)
    if not m:
        problems.append("%s: no shooting_sounds" % rel)
    else:
        ids = [int(x) for x in re.findall(r'ExtResource\(\s*(\d+)\s*\)', m.group(1))]
        declared_ids = {int(r) for _, _, r in ext}
        for i in ids:
            if i not in declared_ids:
                problems.append("%s: shooting_sounds uses undeclared id %d" % (rel, i))
        if not ids:
            problems.append("%s: shooting_sounds is EMPTY" % rel)
        elif len(ids) != 4:
            problems.append("%s: shooting_sounds has %d entries (javelin has 4)" % (rel, len(ids)))

    # the four audio ext_resources must be exactly javelin's set
    audio_paths = [p for p, t, _ in ext if t == "AudioStream"]
    if sorted(audio_paths) != sorted(JAVELIN_SOUNDS):
        problems.append("%s: audio set differs from javelin: %s" % (rel, audio_paths))

print("checked files:", len(files))
print("problems:", len(problems))
for x in problems:
    print("   -", x)
if not problems:
    print("RESULT: OK - all files structurally valid and javelin-consistent")
