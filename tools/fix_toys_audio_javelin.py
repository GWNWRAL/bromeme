#!/usr/bin/env python3
"""
Point the Toys&Balls ranged weapons at the same shooting sounds as the vanilla
Javelin weapon.

Vanilla javelin (res://dlcs/dlc_1/weapons/ranged/javelin/1/javelin_stats.tres):

    [ext_resource ... res://weapons/melee_sounds/whoosh_swish_high_fast_01.wav ... id=3]
    [ext_resource ... res://weapons/melee_sounds/whoosh_swish_high_fast_04.wav ... id=4]
    [ext_resource ... res://weapons/melee_sounds/whoosh_swish_high_fast_03.wav ... id=5]
    [ext_resource ... res://weapons/melee_sounds/whoosh_swish_high_fast_02.wav ... id=6]
    shooting_sounds = [ ExtResource( 3 ), ExtResource( 6 ), ExtResource( 5 ), ExtResource( 4 ) ]

This rewrites the AudioStream ext_resource block of each target file to those
four sounds (same ids / same order) and sets shooting_sounds to the identical
array. Non-audio ext_resources and everything else are left untouched.
"""
import os, re, shutil, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
BACKUP_ROOT = r"D:\DSH\_aitato_work\ToysBalls_audio_backup"

APPLY = "--apply" in sys.argv

WHOOSH = [
    "res://weapons/melee_sounds/whoosh_swish_high_fast_01.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_04.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_03.wav",
    "res://weapons/melee_sounds/whoosh_swish_high_fast_02.wav",
]
# ids exactly as vanilla javelin uses them (kept so the array reads identically)
IDS = [3, 4, 5, 6]
# vanilla javelin's array order: 01(id3), 02(id6), 03(id5), 04(id4)
ARRAY_ORDER = [3, 6, 5, 4]

TARGETS = [
    "content/weapons/ranged/basketball/1/basketball_stats.tres",
    "content/weapons/ranged/basketball/2/basketball_2_stats.tres",
    "content/weapons/ranged/basketball/3/basketball_3_stats.tres",
    "content/weapons/ranged/basketball/4/basketball_4_stats.tres",
    "content/weapons/ranged/boomerang/1/boomerang_stats.tres",
    "content/weapons/ranged/boomerang/2/boomerang_2_stats.tres",
    "content/weapons/ranged/boomerang/3/boomerang_3_stats.tres",
    "content/weapons/ranged/boomerang/4/boomerang_4_stats.tres",
    "content/weapons/ranged/easter_egg/1/easter_egg_stats.tres",
    "content/weapons/ranged/easter_egg/2/easter_egg_2_stats.tres",
    "content/weapons/ranged/easter_egg/3/easter_egg_3_stats.tres",
    "content/weapons/ranged/easter_egg/4/easter_egg_4_stats.tres",
    "content/weapons/ranged/ice_ball/1/ice_ball_stats.tres",
    "content/weapons/ranged/ice_ball/2/ice_ball_2_stats.tres",
    "content/weapons/ranged/ice_ball/3/ice_ball_3_stats.tres",
    "content/weapons/ranged/ice_ball/4/ice_ball_4_stats.tres",
    "content/weapons/ranged/lego_box/1/lego_box_stats.tres",
    "content/weapons/ranged/lego_box/2/lego_box_stats.tres",
    "content/weapons/ranged/lego_box/3/lego_box_3_stats.tres",
    "content/weapons/ranged/lego_box/4/lego_box_4_stats.tres",
    "content/weapons/ranged/quidditch_ball/quidditch_ball_stats.tres",
]

report = []
for rel in TARGETS:
    p = os.path.join(MOD, rel.replace("/", os.sep))
    if not os.path.exists(p):
        report.append((rel, "MISSING FILE", None))
        continue

    txt = open(p, encoding="utf-8", errors="replace").read()
    orig = txt

    # 1) replace every AudioStream ext_resource line with the javelin set.
    #    Remove old audio lines, then insert the four new ones where the first was.
    audio_line = re.compile(r'^\[ext_resource path="[^"]+" type="AudioStream" id=(\d+)\]\s*$', re.M)
    matches = list(audio_line.finditer(txt))
    if not matches:
        report.append((rel, "NO AudioStream ext_resource", None))
        continue

    insert_at = matches[0].start()
    txt = audio_line.sub("", txt)
    txt = re.sub(r'\n{3,}', '\n\n', txt)

    block = "\n".join(
        '[ext_resource path="%s" type="AudioStream" id=%d]' % (WHOOSH[i], IDS[i])
        for i in range(len(WHOOSH))
    )
    txt = txt[:insert_at] + block + "\n" + txt[insert_at:]

    # 2) point shooting_sounds at the same array as vanilla javelin
    arr = "[ %s ]" % ", ".join("ExtResource( %d )" % i for i in ARRAY_ORDER)
    txt, n = re.subn(r'^(\s*)shooting_sounds\s*=\s*\[[^\]]*\]\s*$',
                     lambda m: "%sshooting_sounds = %s" % (m.group(1), arr),
                     txt, count=1, flags=re.M)
    if n == 0:
        report.append((rel, "shooting_sounds line not found", None))
        continue

    # 3) load_steps sanity: count ext_resource + sub_resource + 1
    steps = len(re.findall(r'^\[ext_resource', txt, re.M)) + \
            len(re.findall(r'^\[sub_resource', txt, re.M)) + 1
    txt = re.sub(r'^\[gd_resource type="Resource" load_steps=\d+',
                 '[gd_resource type="Resource" load_steps=%d' % steps, txt, count=1, flags=re.M)

    changed = txt != orig
    if APPLY and changed:
        bak = os.path.join(BACKUP_ROOT, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(bak), exist_ok=True)
        shutil.copy2(p, bak)
        open(p, "w", encoding="utf-8", newline="").write(txt)

    report.append((rel, "OK" if changed else "unchanged", steps))

print("=" * 78)
print("%s  (%d targets)" % ("APPLYING" if APPLY else "DRY RUN - pass --apply", len(TARGETS)))
print("=" * 78)
ok = 0
for rel, status, steps in report:
    if status == "OK":
        ok += 1
    print("  %-8s %s%s" % (status, rel, "" if steps is None else "   (load_steps=%d)" % steps))
print()
print("changed: %d / %d" % (ok, len(TARGETS)))
if APPLY:
    print("backups: %s" % BACKUP_ROOT)
