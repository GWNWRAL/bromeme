# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.6 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.6: two fixes for the expanded card pool. (1) Fusion card names are readable again: vanilla and other "
    "mods items store a translation key in their name field (ITEM_ACID, ITEM_SPINE_SWORD_IV, ...), and the "
    "half-and-half naming was slicing that key, so the card showed things like ITEM_SPINEEDGEHOG. Names are now "
    "resolved first (same as vanilla get_name_text -> tr(name), and through it for our own items too). (2) The "
    "random draw card (the one that puts 3-4 effects on a card) and the job-change cards random buff used to "
    "read every item in the game, including this mods 24 non-shop items and other mods hidden content, so "
    "non-sellable items kept appearing. Both now take their effects from the shop pool only (the same "
    "ItemService._tiers_data ITEMS pool the shop and the fusion pool use). Measured: 485 shop items, 0 of them "
    "with can_be_looted false. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.6"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
