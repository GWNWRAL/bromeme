# -*- coding: utf-8 -*-
"""把牢大里我刚误加的那条 power_generator 缩放效果删掉（恢复原状，等确认元素伤害那条的定位再一起改）。"""
import io, json, glob, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
for p in glob.glob(os.path.join(RES, "*.json")):
    d = json.load(io.open(p, encoding="utf-8"))
    if str(d.get("name", "")) != "牢大":
        continue
    before = len(d["datas"])
    kept = []
    for x in d["datas"]:
        c = x.get("changed_key_values", {})
        if "power_generator_effect_1" in x.get("base_resource_path", "") and c.get("nb_stat_scaled") == 5 \
                and c.get("stat_scaled") == "stat_melee_damage":
            continue
        kept.append(x)
    d["datas"] = kept
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print("牢大(%s): 效果 %d → %d 条（已移除误加的那条）" % (d.get("my_id"), before, len(kept)))
    print("      现有: %s" % [(x["base_resource_path"].split("/")[-1], x.get("changed_key_values", {}).get("key"),
                              x.get("changed_key_values", {}).get("value")) for x in kept])
    break
