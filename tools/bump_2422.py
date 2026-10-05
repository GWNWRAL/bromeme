# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.2 + 顶部追加描述（只讲解锁这一项改动）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

# 把 2.42.1 那段一起并进这一版：2.42.1 的内容保留（它是上一版的真实记录），
# 但顶部换成本次唯一改动的说明。
HEAD = (
    "2.42.2: all mod items now show as unlocked in the codex. The json field unlocked_by_default no longer "
    "decides item.unlocked_by_default (that is always true now), so the 71 items that are meant to be obtained "
    "from the wave-end 4-choice panel, meme events or a character starting kit are no longer greyed out next to "
    "the 24 shop items. Nothing else was changed on purpose: can_be_looted and the shop pool work exactly as "
    "before, because the shop was not part of this request. Log check: 解锁诊断：本 mod 道具 95 件（其中 "
    "unlocked_by_default 95 件），… 未在解锁表里的 0 件. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.2"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
