# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.5 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.5: the fusion / modified card pool now covers every item that can be sold in the shop - vanilla items "
    "and other mods items included - instead of only this mods 71 shop items. The pool is read straight from "
    "ItemService._tiers_data (the pool vanilla init_unlocked_pool builds), so it uses exactly the same rules as "
    "the shop: can_be_looted, unlocked, max_nb != 0, and it never contains weapons, consumables or characters. "
    "Measured in game: 485 items total, 71 of them from this mod. The 24 non-shop items of this mod (4-choice "
    "exclusives, meme event items, the research line, character starting kit items) stay out of the pool. Note "
    "that fusing or modifying an item that can be taken more than once means the card can no longer be taken "
    "again once you hold max_nb of it. A 组合池 log line reports the pool size whenever the panel opens. some "
    "characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.5"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
