# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.16 + 顶部追加描述（本轮 5 项）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.16: five changes. (1) Fixed meme invasions never happening past wave 20: the check bailed out with "
    "wave > nb_of_waves, which is the vanilla guard meant for consumable drops in endless mode - meme invasions "
    "are a mod mechanic and now keep rolling in endless waves. (2) Fixed the meme reward items (fusion / modified "
    "/ job-change cards turned into items, and the meme items) disappearing after a save reload: vanilla rebuilds "
    "player items by looking the saved my_id up in ItemService.items and silently DROPS anything it cannot find "
    "(player_run_data.gd:177), and the card items were runtime-only with a generated id. Card items now get a "
    "stable unique id (repeats of the same card get _2 / _3 suffixes) and are registered into ItemService.items "
    "with unlocked_by_default false and can_be_looted false, so they are findable on load and still never appear "
    "in the shop or in item boxes. (3) Meme core now grants +3 meme value per shop purchase instead of +1. "
    "(4) The invasion chance curve is now y = 1 - exp(-(max(x,0)/100)^0.9) (1 point 1.6 percent, 9 points 10.8 "
    "percent, 100 points 63.2 percent) in both the roll and the stat info line. (5) The pick panel reroll costs "
    "another half of what it was (REROLL_PRICE_FACTOR 0.5 to 0.25), so wave 1 costs 4 and wave 10 costs 52. "
    "some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.16"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
