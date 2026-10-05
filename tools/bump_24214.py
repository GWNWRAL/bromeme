# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.14 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.14: the meme pick panel reroll costs half as much (REROLL_PRICE_FACTOR = 0.5, applied to the final "
    "price so every wave and every reroll inside the panel is exactly halved). The formula is still "
    "(5 + 10*wave) * (1 + wave*0.1) with the x1.25 escalation per reroll, so wave 1 now costs 8, wave 5 costs "
    "41 and wave 10 costs 105 for the first reroll. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.14"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
