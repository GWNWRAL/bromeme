# -*- coding: utf-8 -*-
"""挑战者：加上"每 1 秒击退周围敌人"效果。

范本来自本 mod 的炮塔角色（1784211450.json）：
    "base_resource_path": "res://dlcs/dlc_1/items/lantern/effects/lantern_effect_1.tres"
    "changed_key_values": { "text_key": "EFFECT_KNOCKBACK_AURA", "value": 1 }
这是**原版击退光环**效果，由游戏自己的 knockback_aura 效果行为处理
（炮塔注释里明确写了：击退光环用原版灯笼那条 knockback_aura，不要自己写）。
"""
import io, json, os

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\1790000001.json"
d = json.load(io.open(P, encoding="utf-8"))

# 先移除可能存在的旧击退/减速条目，避免重复
d["datas"] = [x for x in d["datas"]
              if "lantern" not in str(x.get("base_resource_path", ""))]

knock = {
    "base_resource_path": "res://dlcs/dlc_1/items/lantern/effects/lantern_effect_1.tres",
    "changed_key_values": {
        "text_key": "EFFECT_KNOCKBACK_AURA",
        "value": 1,
    },
}
d["datas"].append(knock)

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=2) + "\n")

chk = json.load(io.open(P, encoding="utf-8"))
print("挑战者效果条数:", len(chk["datas"]))
for x in chk["datas"]:
    ck = x["changed_key_values"]
    print("   base=%-58s key=%-24s custom=%-26s value=%s" % (
        x["base_resource_path"].split("/")[-1], ck.get("key", "")[:24],
        ck.get("custom_key", "")[:26], ck.get("value")))
