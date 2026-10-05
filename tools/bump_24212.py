# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.12 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.12: two changes. (1) Random meme and meme core now also grant +30 meme value - a second effect entry "
    "built the same way the other +meme value items use (cake_effect_1 with key stat_meme and value 30). (2) "
    "hun5 no longer stands still while using its melee attacks: the 0.3s wind-up and the swing now move at 60% "
    "speed instead (MELEE_MOVE_SPEED_FACTOR = 0.6), which is done by temporarily lowering bonus_speed (unit.gd "
    "adds it into get_move_speed) and is restored when the attack ends, when it is interrupted, and every frame "
    "in the idle state as a safety net, so the speed can never stay reduced. some characters and items created "
    "by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.12"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
