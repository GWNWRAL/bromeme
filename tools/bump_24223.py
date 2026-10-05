# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.23 + 顶部追加描述（修 main 扩展解析失败）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.23: fixed the main script extension failing to parse, which silently disabled everything it hooks. A "
    "function signature and its first body line had been merged onto one line "
    "(func _bromeme_is_character(...) -> bool:    var players = ...), so the file raised \"Unexpected indentation\" "
    "at line 408 and ModLoader installed the extension against Null instead of res://main.gd - visible only as "
    "\"Installing script extension: Null <- .../brolab_compat/extensions/main.gd\" in modloader.log. While that "
    "was broken the player-spawned hook never ran, so the challenger no longer forced a meme invasion every wave, "
    "and the card icon repair never ran either. The line is split again and the extension installs against "
    "res://main.gd. Standalone parse checks now cover the three extensions that are easy to break this way "
    "(main.gd, player_run_data.gd and the new card_item.gd), because a parse failure there is silent: the game "
    "still runs with the whole extension gone. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.23"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
