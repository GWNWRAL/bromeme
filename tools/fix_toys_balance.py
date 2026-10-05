# -*- coding: utf-8 -*-
"""
Toys&Balls 1.0.7 balance + wiring changes.

1) ray_gun: point projectile_scene at the mod's own projectile
   (ray_gun_projectile.tscn, the one that runs ray_gun_color_randomizer.gd).
   Currently it uses the vanilla particle-accelerator projectile and the custom
   one is referenced by nothing.

2) lego box:
     brick count ranges  [1,3],[1,4],[2,4],[2,5]  ->  [0,3],[1,3],[1,4],[2,4]
     damage              6/10/17/25              ->  6/10/15/20
     engineering scaling 0.5/0.8/0.9/1.0         ->  0.5/0.6/0.7/0.8
     level scaling       0.1/0.2/0.3/0.4         ->  unchanged
     red brick burning   3/5/9/13                ->  3/4/5/6
     red burn eng        0.25/0.4/0.45/0.5       ->  0.30/0.35/0.40/0.45

   NOTE: the code identifies tiers by the *damage value* (match value: 6/10/17/25)
   in two places, so those tables must be updated in lockstep or every tier
   would silently fall back to tier 0.

3) toy hammer effect:
     chance  20/25/30/35   -> 20/23/27/30
     value    5/6/8/10     ->  5/6/7/8
     max_xp  30/42/64/90   -> 40/60/84/120
"""
import os, re, sys

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
APPLY = "--apply" in sys.argv

OLD_DMG = [6, 10, 17, 25]
NEW_DMG = [6, 10, 15, 20]
NEW_ENG = [0.5, 0.6, 0.7, 0.8]
NEW_LVL = [0.1, 0.2, 0.3, 0.4]
NEW_RED_BURN = [3, 4, 5, 6]
NEW_RED_ENG = [0.30, 0.35, 0.40, 0.45]
NEW_RED_LVL = [0.05, 0.1, 0.15, 0.2]
NEW_COUNT = [[0, 3], [1, 3], [1, 4], [2, 4]]
NEW_HEAL = [3, 4, 5, 6]

changes = []


def rd(p):
    return open(p, encoding="utf-8", errors="replace").read()


def wr(p, t):
    if APPLY:
        open(p, "w", encoding="utf-8", newline="").write(t)


def sub1(path, pattern, repl, label, flags=re.M):
    p = os.path.join(MOD, path.replace("/", os.sep))
    if not os.path.exists(p):
        changes.append(("MISSING", path, label))
        return
    txt = rd(p)
    new, n = re.subn(pattern, repl, txt, count=1, flags=flags)
    if n == 0:
        changes.append(("NO-MATCH", path, label))
        return
    wr(p, new)
    changes.append(("ok", path, label))


# ---------------------------------------------------------------- 1) ray gun
RAY_STATS = "res://mods-unpacked/General-Toys_Balls/content/weapons/ranged/ray_gun/ray_gun_projectile.tscn"
for i in (2, 3, 4):
    path = "content/weapons/ranged/ray_gun/%d/ray_gun_%d_stats.tres" % (i, i)
    p = os.path.join(MOD, path.replace("/", os.sep))
    txt = rd(p)
    # replace the ext_resource that currently points at the vanilla projectile
    pat = r'\[ext_resource path="res://projectiles/bullet_particle_accelerator/particle_accelerator_projectile\.tscn" type="PackedScene" id=(\d+)\]'
    new, n = re.subn(pat,
                     lambda m: '[ext_resource path="%s" type="PackedScene" id=%s]' % (RAY_STATS, m.group(1)),
                     txt)
    if n == 0:
        changes.append(("NO-MATCH", path, "ray gun projectile"))
    else:
        wr(p, new)
        changes.append(("ok", path, "ray gun projectile -> %d site(s)" % n))

# ------------------------------------------------------------- 2) lego stats
for i in range(4):
    tier = i + 1
    # 1 级与 2 级都叫 lego_box_stats.tres(只是目录不同),3/4 级带序号
    fname = "lego_box_stats.tres" if tier <= 2 else "lego_box_%d_stats.tres" % tier
    path = "content/weapons/ranged/lego_box/%d/%s" % (tier, fname)
    p = os.path.join(MOD, path.replace("/", os.sep))
    if not os.path.exists(p):
        changes.append(("MISSING", path, "lego stats"))
        continue
    txt = rd(p)
    txt = re.sub(r'^damage = \d+', 'damage = %d' % NEW_DMG[i], txt, count=1, flags=re.M)
    scal = '[ [ "stat_engineering", %s ], [ "stat_levels", %s ] ]' % (NEW_ENG[i], NEW_LVL[i])
    txt = re.sub(r'^scaling_stats = \[.*?\]\s*$', 'scaling_stats = ' + scal, txt, count=1, flags=re.M)
    wr(p, txt)
    changes.append(("ok", path, "damage=%d eng=%s lvl=%s" % (NEW_DMG[i], NEW_ENG[i], NEW_LVL[i])))

# -------------------------------------------------------- 3) lego effect .tres
for i in range(4):
    tier = i + 1
    path = "content/weapons/ranged/lego_box/%d/lego_box_effect_0.tres" % tier
    p = os.path.join(MOD, path.replace("/", os.sep))
    if not os.path.exists(p):
        changes.append(("MISSING", path, "lego effect"))
        continue
    txt = rd(p)
    txt = re.sub(r'^value = \d+', 'value = %d' % NEW_DMG[i], txt, count=1, flags=re.M)
    scal = '[ [ "stat_engineering", %s ], [ "stat_levels", %s ] ]' % (NEW_ENG[i], NEW_LVL[i])
    txt = re.sub(r'^scaling_stats = \[.*?\]\s*$', 'scaling_stats = ' + scal, txt, count=1, flags=re.M)
    wr(p, txt)
    changes.append(("ok", path, "value=%d" % NEW_DMG[i]))

# ------------------------------------------- 4) lego_box_projectile.gd tables
path = "content/weapons/ranged/lego_box/lego_box_projectile.gd"
p = os.path.join(MOD, path.replace("/", os.sep))
txt = rd(p)
txt = re.sub(r'^const BURN_DAMAGE := \[.*?\]',
             'const BURN_DAMAGE := [%s]' % ", ".join(str(x) for x in NEW_RED_BURN), txt, count=1, flags=re.M)
txt = re.sub(r'^const BURN_ENG := \[.*?\]',
             'const BURN_ENG := [%s]' % ", ".join(str(x) for x in NEW_RED_ENG), txt, count=1, flags=re.M)
txt = re.sub(r'^const RED_BURN_DAMAGE := \[.*?\]',
             'const RED_BURN_DAMAGE := [%s]' % ", ".join(str(x) for x in NEW_RED_BURN), txt, count=1, flags=re.M)
txt = re.sub(r'^const RED_BURN_ENG := \[.*?\]',
             'const RED_BURN_ENG := [%s]' % ", ".join(str(x) for x in NEW_RED_ENG), txt, count=1, flags=re.M)
txt = re.sub(r'^const RED_BURN_LVL := \[.*?\]',
             'const RED_BURN_LVL := [%s]' % ", ".join(str(x) for x in NEW_RED_LVL), txt, count=1, flags=re.M)
txt = re.sub(r'^const BRICK_COUNT_RANGES := \[.*?\]',
             'const BRICK_COUNT_RANGES := [%s]' % ", ".join("[%d, %d]" % (a, b) for a, b in NEW_COUNT),
             txt, count=1, flags=re.M)
# tier lookup now keyed on the NEW damage values
old_match = """		match int(effect.get("value")):
			6:
				return 0
			10:
				return 1
			17:
				return 2
			25:
				return 3"""
new_match = """		match int(effect.get("value")):
			%d:
				return 0
			%d:
				return 1
			%d:
				return 2
			%d:
				return 3""" % tuple(NEW_DMG)
if old_match in txt:
    txt = txt.replace(old_match, new_match)
    changes.append(("ok", path, "tier lookup 6/10/17/25 -> 6/10/15/20"))
else:
    changes.append(("NO-MATCH", path, "tier lookup block"))
wr(p, txt)

# --------------------------------- 5) lego_box_description_effect.gd tables
path = "content/effects/lego_box_description_effect.gd"
p = os.path.join(MOD, path.replace("/", os.sep))
txt = rd(p)
txt = txt.replace("""	match value:
		6:
			return 0
		10:
			return 1
		17:
			return 2
		25:
			return 3""", """	match value:
		%d:
			return 0
		%d:
			return 1
		%d:
			return 2
		%d:
			return 3""" % tuple(NEW_DMG))
txt = re.sub(r'return \[3, 5, 9, 13\]\[_get_tier_index\(\)\]',
             'return [%s][_get_tier_index()]' % ", ".join(str(x) for x in NEW_RED_BURN), txt)
txt = re.sub(r'\["stat_engineering", \[0\.25, 0\.4, 0\.45, 0\.5\]\[_get_tier_index\(\)\]\]',
             '["stat_engineering", [%s][_get_tier_index()]]' % ", ".join(str(x) for x in NEW_RED_ENG), txt)
txt = txt.replace("""	match value:
		6:
			return 3
		10:
			return 4
		17:
			return 5
		25:
			return 6""", """	match value:
		%d:
			return %d
		%d:
			return %d
		%d:
			return %d
		%d:
			return %d""" % (NEW_DMG[0], NEW_HEAL[0], NEW_DMG[1], NEW_HEAL[1],
                        NEW_DMG[2], NEW_HEAL[2], NEW_DMG[3], NEW_HEAL[3]))
txt = txt.replace("""	match value:
		6:
			return [["stat_engineering", 0.5], ["stat_levels", 0.1]]
		10:
			return [["stat_engineering", 0.8], ["stat_levels", 0.2]]
		17:
			return [["stat_engineering", 0.9], ["stat_levels", 0.3]]
		25:
			return [["stat_engineering", 1.0], ["stat_levels", 0.4]]""",
                  """	match value:
		%d:
			return [["stat_engineering", %s], ["stat_levels", %s]]
		%d:
			return [["stat_engineering", %s], ["stat_levels", %s]]
		%d:
			return [["stat_engineering", %s], ["stat_levels", %s]]
		%d:
			return [["stat_engineering", %s], ["stat_levels", %s]]""" % (
                      NEW_DMG[0], NEW_ENG[0], NEW_LVL[0],
                      NEW_DMG[1], NEW_ENG[1], NEW_LVL[1],
                      NEW_DMG[2], NEW_ENG[2], NEW_LVL[2],
                      NEW_DMG[3], NEW_ENG[3], NEW_LVL[3]))
wr(p, txt)
changes.append(("ok", path, "tier tables updated"))

# --------------------------------------------------------- 6) toy hammer
TH = [("toy_hammer_effect_1.tres", 20, 5, 40),
      ("toy_hammer_effect_2.tres", 23, 6, 60),
      ("toy_hammer_effect_3.tres", 27, 7, 84),
      ("toy_hammer_effect_4.tres", 30, 8, 120)]
for name, chance, value, max_xp in TH:
    path = "content/weapons/melee/toy_hammer/" + name
    p = os.path.join(MOD, path.replace("/", os.sep))
    if not os.path.exists(p):
        changes.append(("MISSING", path, "toy hammer"))
        continue
    txt = rd(p)
    txt = re.sub(r'^value = \d+', 'value = %d' % value, txt, count=1, flags=re.M)
    txt = re.sub(r'^max_xp = \d+', 'max_xp = %d' % max_xp, txt, count=1, flags=re.M)
    txt = re.sub(r'^chance = \d+', 'chance = %d' % chance, txt, count=1, flags=re.M)
    wr(p, txt)
    changes.append(("ok", path, "chance=%d value=%d max_xp=%d" % (chance, value, max_xp)))

print("=" * 78)
print("%s" % ("APPLIED" if APPLY else "DRY RUN - pass --apply"))
print("=" * 78)
for st, path, note in changes:
    print("  %-9s %-62s %s" % (st, path, note))
bad = [c for c in changes if c[0] != "ok"]
print()
print("ok: %d   problems: %d" % (len(changes) - len(bad), len(bad)))
