# -*- coding: utf-8 -*-
"""把原版升级（加点）数据挖出来：每个属性每级给多少 -> 用它反推「主属性价值比」。

数据源: D:\\DSH\\Brotato_unpacked_1.1.15.4\\items\\upgrades\\<stat>\\<tier>\\...
每个 <stat>_data.tres 里 effects = [ effect.tres ]，effect.tres 里有 key / value。
"""
import os, re, io, json

ROOT = r"D:\DSH\Brotato_unpacked_1.1.15.4\items\upgrades"


def read(path):
    return io.open(path, encoding="utf-8", errors="replace").read()


def effect_values(effect_path):
    """返回 [(key, value)]，从 effect .tres 里读。"""
    t = read(effect_path)
    key = ""
    m = re.search(r'key\s*=\s*"([^"]*)"', t)
    if m:
        key = m.group(1)
    out = []
    for m in re.finditer(r'^value\s*=\s*(-?[\d.]+)', t, re.M):
        out.append((key, float(m.group(1))))
    return out


rows = {}
for stat_dir in sorted(os.listdir(ROOT)):
    d = os.path.join(ROOT, stat_dir)
    if not os.path.isdir(d):
        continue
    tiers = sorted([x for x in os.listdir(d) if os.path.isdir(os.path.join(d, x))],
                   key=lambda s: int(s) if s.isdigit() else 99)
    for tier in tiers:
        td = os.path.join(d, tier)
        for fn in sorted(os.listdir(td)):
            if not fn.endswith(".tres") or fn.endswith("_data.tres") or fn.endswith("_2_data.tres"):
                continue
            if "effect" not in fn:
                continue
            for key, value in effect_values(os.path.join(td, fn)):
                rows.setdefault(stat_dir, {}).setdefault(tier, []).append((key, value))

print("=== 每个属性的加点数值（升级时每级给多少）===")
for stat in sorted(rows):
    line = []
    for tier in sorted(rows[stat], key=lambda s: int(s) if s.isdigit() else 99):
        vals = rows[stat][tier]
        txt = ", ".join("%s=%g" % (k or "-", v) for k, v in vals)
        line.append("T%s[%s]" % (tier, txt))
    print("%-22s %s" % (stat, "  ".join(line)))
