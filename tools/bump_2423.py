# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.3 + 顶部追加描述（brolab 清理已关闭）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.3: the mod no longer touches user://brolab. The startup cleanup that removed the 0.1.x json files this "
    "mod had copied into the BroLab folder is now disabled (BROLAB_CLEANUP_ENABLED = false), so the BroLab "
    "content library (hundreds of json files plus their icons) is left completely alone. some characters and "
    "items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.3"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
