# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.8 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.8: two meme items reworked. Quantum meme now turns every item in your inventory into another item of "
    "the same tier (it used to change one random item into a random item of any tier), then additionally grants "
    "1 to 8 extra items and +25 meme value; the replacement pool is the shop pool, and an item whose tier has no "
    "other entry in the pool is left untouched instead of vanishing. Sell meme keeps recycling everything at "
    "100% of its price and now also grants +25 harvesting and +35 meme value. Both effect texts were updated in "
    "zh/en/ja/ko/ru, and the shop pool used by these effects is now cached (the quantum meme matches every owned "
    "item against its tier, which would otherwise rescan the whole pool per item). Tier pools measured in game: "
    "tier0 113, tier1 135, tier2 144, tier3 93 items. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.8"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
