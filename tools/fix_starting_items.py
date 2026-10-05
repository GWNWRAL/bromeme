# -*- coding: utf-8 -*-
"""挑战者"初始携带苍/赫"改用原版机制。

关键发现：RunData.add_starting_items_and_weapons() 读的是
  effects[Keys.starting_item_hash] —— 来自 custom_key == "starting_item" 的效果，
  json 形状：{key: <道具 my_id>, value: <数量>, custom_key: "starting_item", storage_method: 1}
而 character.starting_items 只用于"武器/道具选择界面"的展示，不会真的发放。
"""
import io, json, os

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\1790000001.json"
BASE = "res://items/all/cake/cake_effect_1.tres"

d = json.load(io.open(P, encoding="utf-8"))

# 先移除旧写法（避免重复发放）
d["datas"] = [x for x in d["datas"]
              if not (x.get("changed_key_values", {}).get("custom_key") == "starting_item")]

for item_id in ["item_bromeme_orbs_cang", "item_bromeme_orbs_he"]:
    d["datas"].append({
        "base_resource_path": BASE,
        "changed_key_values": {
            "key": item_id,
            "text_key": "effect_starting_item",
            "custom_key": "starting_item",
            "value": 1,
            "storage_method": 1,
            "effect_sign": 3,
        },
    })

# starting_items 字段保留（界面会显示"初始道具"），但真正的发放靠上面的效果
d["starting_items"] = ["item_bromeme_orbs_cang", "item_bromeme_orbs_he"]

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=2) + "\n")

chk = json.load(io.open(P, encoding="utf-8"))
print("挑战者 datas 条数:", len(chk["datas"]))
for x in chk["datas"]:
    ck = x["changed_key_values"]
    print("   key=%-28s text_key=%-26s custom_key=%-16s value=%s" % (
        ck.get("key", ""), ck.get("text_key", ""), ck.get("custom_key", ""), ck.get("value")))
