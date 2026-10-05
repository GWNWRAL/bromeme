# -*- coding: utf-8 -*-
"""打印一批原版效果 .tres 的关键字段，用来搞清楚它们各自是什么。"""
import os, re, sys

ROOT = r"D:\DSH\Brotato_unpacked_1.1.15.4"

PATHS = [
    "items/all/campfire/campfire_effect_2.tres",
    "items/all/shackles/shackles_effect_4.tres",
    "items/all/sifds_relic/sifds_relic_effect_1.tres",
    "items/characters/sick/sick_effect_3.tres",
    "items/characters/speedy/speedy_effect_3.tres",
    "items/characters/speedy/speedy_effect_2.tres",
    "items/characters/bull/bull_effect_4.tres",
    "items/characters/golem/golem_effect_2.tres",
    "items/all/alien_worm/alien_worm_effect_3.tres",
    "dlcs/dlc_1/items/lighthouse/effects/lighthouse_effect_1.tres",
    "items/characters/engineer/engineer_effect_3.tres",
    "items/characters/mage/mage_effect_3.tres",
    "items/all/vigilante_ring/vigilante_ring_effect_1.tres",
    "items/all/cake/cake_effect_1.tres",
    "items/all/coffee/coffee_effect_1.tres",
    "items/all/scar/scar_effect_1.tres",
]

FIELDS = ("key", "text_key", "value", "custom_key", "storage_method", "effect_sign",
          "stat_displayed", "stat_displayed_name", "set_cap_to_current_stat",
          "stats_modified", "stat", "stat_nb", "is_healing", "duration_secs",
          "value2", "nb_stat_scaled")

for rel in PATHS:
    p = os.path.join(ROOT, rel)
    print("=" * 96)
    print("###", rel)
    if not os.path.isfile(p):
        print("   <不存在>")
        continue
    txt = open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r'ext_resource path="([^"]+)" type="Script"', txt)
    print("   script :", m.group(1) if m else "?")
    for line in txt.splitlines():
        s = line.strip()
        for f in FIELDS:
            if s.startswith(f + " = "):
                print("   %-24s %s" % (f, s[len(f) + 3:]))
                break
