# -*- coding: utf-8 -*-
"""按 Brotato 真实抽卡概率，算"本 mod 商店货"应该多久刷出来一次。

规则来源 D:\\DSH\\_vscript\\singletons\\item_service.gd:
  _tiers_data[0] = 全 COMMON:  MIN_WAVE 0, BASE_CHANCE 1.0,  WAVE_BONUS 0.0,    MAX 1.0
  _tiers_data[1] = UNCOMMON:   MIN_WAVE 0, BASE_CHANCE 0.0,  WAVE_BONUS 0.06,   MAX 0.6
  _tiers_data[2] = RARE:       MIN_WAVE 2, BASE_CHANCE 0.0,  WAVE_BONUS 0.02,   MAX 0.25
  _tiers_data[3] = LEGENDARY:  MIN_WAVE 6, BASE_CHANCE 0.0,  WAVE_BONUS 0.0023, MAX 0.08
get_tier_from_wave: 从高 tier 往低遍历，rand <= min(chance, max) 就选中该 tier；
tier0 的 chance 恒为 1.0，所以 wave1 基本必出 tier0。
"""
import random

TIERS = [
    # min_wave, base_chance, wave_bonus, max_chance
    (0, 1.0, 0.0, 1.0),
    (0, 0.0, 0.06, 0.6),
    (2, 0.0, 0.02, 0.25),
    (6, 0.0, 0.0023, 0.08),
]

# 实测的池子规模（bromeme-shopprobe 日志）
POOL = {  # tier: (本mod件数, ITEMS池总数)
    0: (0, 101),
    1: (5, 146),
    2: (8, 157),
    3: (11, 106),
}


def tier_chances(wave, luck=0.0):
    """返回每个 tier 被选中的概率（从高到低遍历的首次命中分布）。"""
    p = [0.0, 0.0, 0.0, 0.0]
    remaining = 1.0
    for i in range(len(TIERS) - 1, -1, -1):
        min_wave, base, bonus, cap = TIERS[i]
        wave_base = max(0.0, ((wave - 1) - min_wave) * bonus)
        wave_chance = wave_base * (1 + luck) if luck >= 0 else wave_base / (1 + abs(luck))
        chance = min(base + wave_chance, cap)
        p[i] = remaining * chance
        remaining *= (1.0 - chance)
    return p


print("各波次：抽到某个 tier 的概率 / 该 tier 命中本 mod 道具的概率")
print("（每波商店 4 格，其中前 2 波有 2 格被武器保底占用）")
print()
cum = 0.0
for wave in range(1, 11):
    p = tier_chances(wave)
    # 一格道具槽命中本 mod 的概率
    per_slot = sum(p[t] * (POOL[t][0] / POOL[t][1]) for t in range(4))
    slots = 4 if wave > 2 else 2
    per_shop = 1 - (1 - per_slot) ** slots
    cum = 1 - (1 - cum) * (1 - per_shop)
    print("第 %2d 波: tier概率=%s  单格命中=%.4f  整店命中=%.1f%%  累计=%.1f%%" % (
        wave,
        " ".join("%.3f" % x for x in p),
        per_slot, per_shop * 100, cum * 100))
