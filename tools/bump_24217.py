# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.17 + 顶部追加描述（清理探针的那一版）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.17: cleanup release. The temporary diagnostics added while chasing the challenger invasion report are "
    "removed (the player-spawn invasion probe, the primary-stat name probe and the stat effect text probe), so "
    "the boot log is back to just the unlock diagnostics. No gameplay change: this build is 2.42.16 plus the "
    "meme core effect text fix (it now reads meme value +3 in zh/en/ja/ko/ru, the actual gain was already +3). "
    "The challenger report turned out to be the endless-wave bug fixed in 2.42.16. some characters and items "
    "created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.17"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
