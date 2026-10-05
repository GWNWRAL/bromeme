# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.10 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.10: the hun5 melee attacks (the sickle thrust, the sickle swing and the sword swing/slash) now stand "
    "still while attacking and got a 0.5s wind-up (MELEE_WINDUP_TIME). Before this the weapon swings chased the "
    "player while swinging, and there was no wind-up at all. Now every one of those three attacks locks the boss "
    "in place for the whole action (movement is held down with _can_move=false + _move_locked=true + "
    "_current_movement=0, so the charge/keep-away behaviours cannot move it either) and plays a 0.5s wind-up "
    "first: the sickle stops at its start angle and the spell blade stays home, and the 180-degree spike fan of "
    "the sword attack is now released when the wind-up ends instead of at the same instant the attack starts. "
    "The blade hitbox is pulled back home during the wind-up too, so the wind-up itself cannot hurt you, and the "
    "sword sprite fades correctly again after a re-swing. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.10"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
