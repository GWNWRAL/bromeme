# -*- coding: utf-8 -*-
"""
Restore the two scripts damaged by the earlier non-greedy regex (which stopped at
the first ']' inside nested arrays, flattening them and leaving the old tail
behind), then re-apply the intended edits with EXACT string replacement.

Damage for the record:
  BRICK_COUNT_RANGES := [[0, 3], [1, 3], [1, 4], [2, 4]], [1, 4], [2, 4], [2, 5]]
  return [ ["stat_engineering", [0.3, 0.35, 0.4, 0.45][_get_tier_index()]],
           ["stat_levels", [0.05, 0.1, 0.15, 0.2][_get_tier_index()]]]
"""
import os, sys, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
ZIP = r"D:\DSH\_mod_backups\ToysBalls-1.0.6-prebalance\snapshot.zip"
APPLY = "--apply" in sys.argv

REL = [
    "content/weapons/ranged/lego_box/lego_box_projectile.gd",
    "content/effects/lego_box_description_effect.gd",
]

# ---- restore originals from the pre-balance snapshot, then edit ------------
restored = {}
with zipfile.ZipFile(ZIP) as z:
    for rel in REL:
        inner = "mods-unpacked/General-Toys_Balls/" + rel
        restored[rel] = z.read(inner).decode("utf-8").replace("\r\n", "\n")
        print("restored %-58s %d bytes" % (rel, len(restored[rel].encode("utf-8"))))

# ---- intended edits, exact-string only -----------------------------------
NEW_DMG = [6, 10, 15, 20]
NEW_ENG = [0.5, 0.6, 0.7, 0.8]
NEW_LVL = [0.1, 0.2, 0.3, 0.4]

EDITS_PROJ = [
    ("const BURN_DAMAGE := [3, 4, 5, 6]",
     "const BURN_DAMAGE := [3, 4, 5, 6]"),
    ("const BURN_ENG := [0.25, 0.3, 0.35, 0.4]",
     "const BURN_ENG := [0.3, 0.35, 0.4, 0.45]"),
    ("const RED_BURN_DAMAGE := [3, 5, 9, 13]",
     "const RED_BURN_DAMAGE := [3, 4, 5, 6]"),
    ("const RED_BURN_ENG := [0.25, 0.4, 0.45, 0.5]",
     "const RED_BURN_ENG := [0.3, 0.35, 0.4, 0.45]"),
    ("const BRICK_COUNT_RANGES := [[1, 3], [1, 4], [2, 4], [2, 5]]",
     "const BRICK_COUNT_RANGES := [[0, 3], [1, 3], [1, 4], [2, 4]]"),
    ("""		match int(effect.get("value")):
			6:
				return 0
			10:
				return 1
			17:
				return 2
			25:
				return 3""",
     """		match int(effect.get("value")):
			6:
				return 0
			10:
				return 1
			15:
				return 2
			20:
				return 3"""),
]

EDITS_DESC = [
    ("	return [3, 5, 9, 13][_get_tier_index()]",
     "	return [3, 4, 5, 6][_get_tier_index()]"),
    ('		["stat_engineering", [0.25, 0.4, 0.45, 0.5][_get_tier_index()]],',
     '		["stat_engineering", [0.3, 0.35, 0.4, 0.45][_get_tier_index()]],'),
    ("""	match value:
		6:
			return 0
		10:
			return 1
		17:
			return 2
		25:
			return 3""",
     """	match value:
		6:
			return 0
		10:
			return 1
		15:
			return 2
		20:
			return 3"""),
    ("""	match value:
		6:
			return 3
		10:
			return 4
		17:
			return 5
		25:
			return 6""",
     """	match value:
		6:
			return 3
		10:
			return 4
		15:
			return 5
		20:
			return 6"""),
    ("""	match value:
		6:
			return [["stat_engineering", 0.5], ["stat_levels", 0.1]]
		10:
			return [["stat_engineering", 0.8], ["stat_levels", 0.2]]
		17:
			return [["stat_engineering", 0.9], ["stat_levels", 0.3]]
		25:
			return [["stat_engineering", 1.0], ["stat_levels", 0.4]]""",
     """	match value:
		6:
			return [["stat_engineering", 0.5], ["stat_levels", 0.1]]
		10:
			return [["stat_engineering", 0.6], ["stat_levels", 0.2]]
		15:
			return [["stat_engineering", 0.7], ["stat_levels", 0.3]]
		20:
			return [["stat_engineering", 0.8], ["stat_levels", 0.4]]"""),
]

print()
problems = 0
for rel, edits in ((REL[0], EDITS_PROJ), (REL[1], EDITS_DESC)):
    txt = restored[rel]          # 以备份原文为基准做编辑
    for old, new in edits:
        if old not in txt:
            print("  NO-MATCH  %-52s %s" % (os.path.basename(rel), old.splitlines()[0][:50]))
            problems += 1
            continue
        if old != new:
            txt = txt.replace(old, new, 1)
            print("  ok        %-52s %s" % (os.path.basename(rel), old.splitlines()[0][:50]))
        else:
            print("  unchanged %-52s %s" % (os.path.basename(rel), old.splitlines()[0][:50]))
    if APPLY:
        p = os.path.join(MOD, rel.replace("/", os.sep))
        open(p, "w", encoding="utf-8", newline="").write(txt)

print()
print("%s   problems=%d" % ("APPLIED" if APPLY else "DRY RUN - pass --apply", problems))
