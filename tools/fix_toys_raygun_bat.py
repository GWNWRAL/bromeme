# -*- coding: utf-8 -*-
"""
Toys&Balls 1.0.9

1) ray gun: revert projectile_scene to the vanilla particle-accelerator
   projectile, and delete the two files that existed only for the custom one:
       content/weapons/ranged/ray_gun/ray_gun_projectile.tscn
       content/weapons/ranged/ray_gun/ray_gun_color_randomizer.gd
   (the colour randomizer is referenced by nothing else; ray_beam.png and
    ray_gun_spark_particles.tscn stay - they belong to ray_gun_big_laser)

2) baseball bat: +10% attack speed, i.e. cooldown / 1.1
       82 -> 75    79 -> 72    77 -> 70    71 -> 65

Exact-string edits only (an earlier pass corrupted nested arrays with a
non-greedy regex; not repeating that).
"""
import os, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
APPLY = "--apply" in sys.argv

VANILLA_PROJ = "res://projectiles/bullet_particle_accelerator/particle_accelerator_projectile.tscn"
CUSTOM_PROJ = "res://mods-unpacked/General-Toys_Balls/content/weapons/ranged/ray_gun/ray_gun_projectile.tscn"

DELETES = [
    "content/weapons/ranged/ray_gun/ray_gun_projectile.tscn",
    "content/weapons/ranged/ray_gun/ray_gun_color_randomizer.gd",
]

BAT = [("content/weapons/melee/baseball_bat/1/baseball_bat_stats.tres", 82, 75),
       ("content/weapons/melee/baseball_bat/2/baseball_bat_2_stats.tres", 79, 72),
       ("content/weapons/melee/baseball_bat/3/baseball_bat_3_stats.tres", 77, 70),
       ("content/weapons/melee/baseball_bat/4/baseball_bat_4_stats.tres", 71, 65)]

report = []

# ---- 1) ray gun stats -> vanilla projectile -----------------------------
for i in (2, 3, 4):
    rel = "content/weapons/ranged/ray_gun/%d/ray_gun_%d_stats.tres" % (i, i)
    p = os.path.join(MOD, rel.replace("/", os.sep))
    txt = open(p, encoding="utf-8", errors="replace").read()
    old = '[ext_resource path="%s" type="PackedScene" id=4]' % CUSTOM_PROJ
    new = '[ext_resource path="%s" type="PackedScene" id=4]' % VANILLA_PROJ
    if old not in txt:
        report.append(("NO-MATCH", rel, "custom projectile ext_resource"))
        continue
    if APPLY:
        open(p, "w", encoding="utf-8", newline="").write(txt.replace(old, new, 1))
    report.append(("ok", rel, "projectile -> vanilla particle accelerator"))

# ---- 2) delete custom projectile files ----------------------------------
for rel in DELETES:
    p = os.path.join(MOD, rel.replace("/", os.sep))
    if not os.path.exists(p):
        report.append(("MISSING", rel, "already absent"))
        continue
    if APPLY:
        os.remove(p)
    report.append(("ok", rel, "deleted"))

# ---- 3) baseball bat cooldown -------------------------------------------
for rel, old_cd, new_cd in BAT:
    p = os.path.join(MOD, rel.replace("/", os.sep))
    txt = open(p, encoding="utf-8", errors="replace").read()
    old = "cooldown = %d" % old_cd
    new = "cooldown = %d" % new_cd
    if old not in txt:
        report.append(("NO-MATCH", rel, old))
        continue
    if APPLY:
        open(p, "w", encoding="utf-8", newline="").write(txt.replace(old, new, 1))
    report.append(("ok", rel, "%s -> %s  (+10%% attack speed)" % (old, new)))

print("=" * 78)
print("%s" % ("APPLIED" if APPLY else "DRY RUN - pass --apply"))
print("=" * 78)
for st, rel, note in report:
    print("  %-9s %-58s %s" % (st, rel, note))
bad = [r for r in report if r[0] != "ok"]
print()
print("ok: %d   problems: %d" % (len(report) - len(bad), len(bad)))
