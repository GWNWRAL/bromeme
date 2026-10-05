# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.7 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.7: the fusion card and the stat-swap cards (the plain swap card and the swap+fuse combo card) now "
    "hard-refuse any item that is not sold in the shop. They already only drew from the shop pool, so nothing "
    "changes in normal play - this is an explicit guard (bromeme_is_pickable -> item.can_be_looted) on top of "
    "the pool filter, so those three cards can never use one of the mods 24 non-shop items (4-choice exclusives, "
    "meme event items, the research line, character starting kit items) as material even if the pool logic "
    "changes later. The card builder also handles the refused case cleanly now: a refused card is skipped "
    "instead of being added as an empty card, pair cards cannot overflow the cursor, and two card types that "
    "could stop early without refilling the slot now fall through to the next card type. some characters and "
    "items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.7"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
