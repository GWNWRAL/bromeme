# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.20 + 顶部追加描述（本轮 3 项调整）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.20: three balance changes. (1) The job-change card no longer hands out the extra random buff it used to "
    "append after the convert - it now only removes the source stat and adds the converted target stat. (2) Van "
    "waits 1 second longer after his three-dash chain (COOLDOWN 2.0 to 3.0), so his dash cycle is 2 short plus 1 "
    "long dash, then 3 seconds of cooldown. (3) The traitor ninja (panren) dashes 25 percent slower (DASH_SPEED "
    "1250 to 937.5); his dash distance is speed times time, so each dash covers 25 percent less ground. both "
    "enemy scripts were parse-checked with a standalone harness. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.20"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
