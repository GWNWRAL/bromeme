# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.11 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.11: three fixes. (1) Quantum meme no longer swaps characters: vanilla keeps characters inside the item "
    "list, so the same-tier swap could turn one of your characters into an item - character_ entries are now "
    "skipped by the swap and by the 1-8 extra items. (2) Sell meme no longer eats worthless items and can never "
    "touch a character: it keeps every item whose value is 0 or less (selling those paid nothing, you just lost "
    "them) and the log now says how many were kept. (3) Fixed hun5 freezing in place after a melee attack: the "
    "cleanup that frees the leftover weapon sprite only restored _can_move, not _move_locked, so an interrupted "
    "weapon swing (or blade thrust) left _move_locked = true forever and unit.gd then returned a zero movement "
    "vector - the boss simply stopped moving. Both flags are restored now, the wind-up timer is cleared on "
    "interrupt, and the idle state resets both flags every frame as a safety net. Also the hun5 melee wind-up is "
    "0.3s instead of 0.5s (MELEE_WINDUP_TIME). some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.11"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
