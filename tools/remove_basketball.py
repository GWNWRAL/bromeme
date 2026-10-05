# -*- coding: utf-8 -*-
"""撤掉 2.39.0 那两处：牢大/鸡哥初始武器里的 weapon_basketball_1，以及 manifest 对 Toys&Balls 的依赖。"""
import io, json, glob, os

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
WEAPON = "weapon_basketball_1"
report = []


def load(p):
    return json.load(io.open(p, encoding="utf-8"))


def save(p, d):
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")


for who in ("牢大", "鸡哥"):
    for p in glob.glob(os.path.join(RES, "*.json")):
        d = load(p)
        if str(d.get("name", "")) != who:
            continue
        sw = d.get("starting_weapons") or []
        if WEAPON in sw:
            sw = [w for w in sw if w != WEAPON]
            d["starting_weapons"] = sw
            save(p, d)
            report.append("%s(%s): 已移除 %s → 共 %d 把" % (who, d.get("my_id"), WEAPON, len(sw)))
        else:
            report.append("%s: 本来就没有 %s" % (who, WEAPON))
        break

mp = os.path.join(MOD, "manifest.json")
md = load(mp)
godot = md.setdefault("extra", {}).setdefault("godot", {})
od = godot.get("optional_dependencies") or []
if "General-Toys_Balls" in od:
    od = [x for x in od if x != "General-Toys_Balls"]
    godot["optional_dependencies"] = od
    save(mp, md)
    report.append("manifest: optional_dependencies = %s" % od)

print("\n".join(report) if report else "没有改动")
