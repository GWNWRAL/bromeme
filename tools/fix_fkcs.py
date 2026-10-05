# -*- coding: utf-8 -*-
"""反抗孙笑川：不再召唤原版特殊敌人，改为纯展示标记（下一波必定触发孙笑川入侵，逻辑在 main 扩展里）。"""
import io, json

p = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\1765216596.json"
d = json.load(io.open(p, encoding="utf-8"))

before = len(d["datas"])
kept = []
for data in d["datas"]:
    if "bait_effect_2" in str(data.get("base_resource_path", "")):
        continue
    kept.append(data)

kept.append({
    "base_resource_path": "res://items/all/cake/cake_effect_1.tres",
    "changed_key_values": {
        "key": "",
        "text_key": "下一波敌袭一开始必定触发孙笑川入侵",
        "custom_key": "",
        "value": 1,
        "storage_method": 0,
        "effect_sign": 0,
    },
})
d["datas"] = kept
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")

print("datas: %d -> %d" % (before, len(kept)))
for i, data in enumerate(kept):
    ck = data.get("changed_key_values", {})
    print("  [%d] %-28s key=%-22s text=%s" % (
        i, data["base_resource_path"].split("/")[-1], ck.get("key", "-"), str(ck.get("text_key", ""))[:36]))
