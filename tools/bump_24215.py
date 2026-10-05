# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.15 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.15: four things. (1) Gambler meme now says materials instead of gold in all five languages - the games "
    "currency variable is player_data.gold but the Chinese UI calls it 材料 (the hoarder achievement reads "
    "get_player_gold), so this is wording only. (2) Gambler meme also grants +30 meme value. (3) The gambler is "
    "not broken, but doubling or wiping 0 materials does nothing, so it now writes an explicit log line instead "
    "of returning silently, and every branch logs the before/after amounts - if you still see it do nothing while "
    "you have materials, send me that log line. (4) The 8 meme panel items (meme core, chaos, random, sell, "
    "entropy, gambler, quantum, sacrifice) are locked now: the json carries locked true, which sets "
    "unlocked_by_default false (codex shows them locked) and can_be_looted false (so they cannot appear in the "
    "shop pool, and item boxes use that same pool), while the card panel still hands them out normally. A guard "
    "was added to the shop-transition re-unlock helper so it can never push these back into the unlocked table. "
    "some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.15"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
