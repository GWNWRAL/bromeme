# -*- coding: utf-8 -*-
"""牢大：删除原有的「每 8 近战伤害 +1 远程伤害」那条（即 power_generator_effect_1 且没有覆盖 nb_stat_scaled 的那条）。"""
import io, json, glob, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
report = []
for p in glob.glob(os.path.join(RES, "*.json")):
    d = json.load(io.open(p, encoding="utf-8"))
    if str(d.get("name", "")) != "牢大":
        continue
    kept, removed = [], []
    for x in d["datas"]:
        c = x.get("changed_key_values", {})
        is_scale = "power_generator_effect_1" in x.get("base_resource_path", "")
        if is_scale and c.get("key") == "stat_ranged_damage" and "nb_stat_scaled" not in c:
            removed.append(x["base_resource_path"].split("/")[-1])
            continue
        kept.append(x)
    d["datas"] = kept
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    report.append("牢大(%s): 删除 %s → 效果 %d 条" % (d.get("my_id"), removed, len(kept)))
    report.append("      剩余: %s" % [(x["base_resource_path"].split("/")[-1],
                                   x.get("changed_key_values", {}).get("key"),
                                   x.get("changed_key_values", {}).get("nb_stat_scaled")) for x in kept])
    break
print("\n".join(report) if report else "没找到牢大")
