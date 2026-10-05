# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.18 + 顶部追加描述（修转职卡的 %% 与丢数值）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.18: fixed the job-change (and swap) cards showing other mods stats wrong, and simplified the job card "
    "explain line. Two symptoms, one cause - other mods stat translations differ from vanilla ones. (1) The name "
    "and the explain line showed a double percent sign, e.g. 转职：%%暴击率 -> 时光: the card built those strings "
    "from tr(stat_key) and that mods translation already contains a % sign, while vanilla Text.text adds another "
    "one on the effect rows. Stat labels used in card names and in the explain line now go through "
    "bromeme_stat_label, which strips the percent sign so it is added exactly once (on the effect rows). (2) The "
    "effect rows lost their number, e.g. -3 %%暴击率 and +2 %%生命窃取 instead of a value plus name: those mods "
    "stats are neither in keys_needing_operator nor do their translations carry a {0} placeholder. All stat "
    "effect rows built by the job card, the swap card and the extra random buff now go through "
    "_bromeme_fix_stat_effect_text, which only rewrites a row when it would otherwise render without a number, so "
    "vanilla stat rows are untouched. (3) The job card explain line now only shows this rolls own ratio, e.g. "
    "转职：全部 暴击率 -> 时光（本次 1:1.85）, without the base value ratio and the -50 to +100 percent range. "
    "The temporary stat-table diagnostics are removed again. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.18"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
