# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.13 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.13: sell meme also gives +5 to every primary stat (on top of the 100% gold recycle, +25 harvesting and "
    "+35 meme value). It walks Utils.get_primary_stat_keys() - the same range the entropy and sacrifice memes use "
    "- and skips the kill-counter stats through the shared bromeme_stat_skipped helper, so no counter is touched. "
    "Because stat_meme is itself flagged as a primary stat, that +5 lands on meme value as well, so sell meme "
    "ends up granting +40 meme value in total; say the word if you want memes excluded from this +5. The effect "
    "text was updated in zh/en/ja/ko/ru. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.13"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
