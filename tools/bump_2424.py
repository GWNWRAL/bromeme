# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.4 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.4: the wave-end card pool is limited to shop items again. The mod has 95 items but only 71 of them are "
    "meant to show up in the shop (the other 24 are the 4-choice exclusives, the meme event items, the research "
    "line and the character starting kit ones). The pool used to be filtered by ProgressData.items_unlocked, "
    "which only happened to equal the 24 shop items before 2.42.2 and now equals all 95, so the fusion and "
    "modified cards had started combining the exclusive items too. The filter is now item.can_be_looted (the "
    "same condition the shop pool uses), so the pool is the intended 71 items again; a 组合池 log line reports "
    "the pool size whenever the panel opens. The codex still shows all 95 as unlocked. some characters and "
    "items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.4"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
