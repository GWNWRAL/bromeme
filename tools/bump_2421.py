# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 + 顶部追加英文流水账描述（不塞双引号/反斜杠）。"""
import io, json, os

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

old = d["description"]
HEAD = ("2.42.1: real fix for the mod items never showing up in the shop and looking locked. "
        "The json pipeline copied Brolabs parsing quirk can_be_looted = not int(unlocked_by_default) == 1, "
        "so all 24 shop items ended up with can_be_looted = false and init_unlocked_pool() skipped every one "
        "of them on its first line (if not item.can_be_looted: continue) - the pool really contained 0 mod "
        "items while the codex, which re-reads ProgressData.items_unlocked every time it opens, saw the 24 "
        "hashes fine and only greyed out the 71 items that are locked by design. can_be_looted now follows the "
        "json field (same direction), and the unlocked pool is rebuilt after the hashes are added instead of "
        "before. Verified in the log: the mod now puts 24 items into the shop pool (tier 1 5 / tier 2 8 / "
        "tier 3 11). some characters and items created by Brolab. ")

# 老描述里保留 2.42.0 那条，但把错误结论换掉
old = old.replace(
    "2.42.0: fix for the mod items never showing up in the shop - ProgressData loads from the save after our registration (and old saves still hold the pre-rename ids), so right before every shop transition the mod now re-adds its unlocked_by_default item hashes to ProgressData.items_unlocked and rebuilds the unlocked pool. ",
    "2.42.0: right before every shop transition the mod re-adds its unlocked_by_default item hashes to ProgressData.items_unlocked and rebuilds the unlocked pool (this turned out not to be the cause, see 2.42.1). ")

d["description"] = HEAD + old
d["version_number"] = "2.42.1"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

# 回读校验
check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 前 200 字:", check["description"][:200])
print("含双引号:", '"' in check["description"], " 含反斜杠:", "\\" in check["description"])
