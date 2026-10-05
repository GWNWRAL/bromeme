# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.16 + 顶部追加描述（8 件 meme 改为 no_loot）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.16: the 8 meme panel items (meme core, chaos, random, sell, entropy, gambler, quantum, sacrifice) are "
    "unlocked in the codex but can no longer be looted - the json now carries no_loot true, which is a separate "
    "switch from unlocked_by_default: unlocked_by_default is always true (codex shows them unlocked, as it does "
    "for every mod item) while can_be_looted becomes false, so they cannot enter the shop pool and item boxes "
    "use that same pool. The card panel still hands them out. Gambler meme wording is materials now and it also "
    "grants +30 meme value; the gambler logs every branch, including the case where you have 0 materials and "
    "nothing can change. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.16"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
