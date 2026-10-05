# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.24 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.24: fixed a native crash (Brotato.exe access violation 0xc0000005) caused by card items. The card item "
    "script from 2.42.22 called set_script() on an already instantiated Resource (the item is duplicated from a "
    "shared template), which rebuilds the script instance and can leave dangling references; the crash happened "
    "when the pick panel handed over a meme core card and the next shop transition ran the icon repair over "
    "ItemService.items, with no SCRIPT ERROR in the log because the fault is in the engine, not in GDScript. The "
    "script attachment is gone: card items are plain ItemData/UpgradeData again, and the icon source is persisted "
    "in a small side file (user://bromeme_card_icons.json, card item id to source card id) written when the card "
    "is handed out, so the icon is rebuilt from that record first, then from the id itself, then from the "
    "resources index. Balance: the Sun Xiaochuan letter volley fans out wider (LETTER_FLIGHT_FAN 0.12 to 0.22) and "
    "the traitor ninja teleports further (TELEPORT_BACK_DIST 260 to 360, +100). some characters and items created "
    "by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.24"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
