# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.19 + 顶部追加描述（修复 SL/退出重进丢奖励道具）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.19: fixed the meme reward items (the cards turned into items by the 4-pick panel: fusion, modified, "
    "job-change and the meme items) disappearing after a save reload or a game restart. Root cause: card items "
    "are generated at runtime and were only appended to ItemService.items in memory. Vanilla rebuilds each saved "
    "player item by looking its saved my_id up in ItemService.items and SILENTLY DROPS anything it cannot find "
    "(player_run_data.gd:177), so once the process ended that runtime entry was gone and every card item was lost "
    "on the next load. A save file comparison proves the item was written correctly (backups at 00:08:01 and "
    "00:08:38 contain it, the save written after the reload at 00:09:22 does not), so only the load side was "
    "broken. Fix: a new script extension on progress_data_loader_v3.gd runs before deserialization, reads the "
    "card items out of the save, rebuilds each one as an UpgradeData and registers it into ItemService.items "
    "(merging the saved name and effects back in), so the vanilla lookup by my_id succeeds again. The temporary "
    "diagnostics are removed. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.19"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
