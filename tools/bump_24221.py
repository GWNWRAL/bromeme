# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.21 + 顶部追加描述（卡道具读档后补回贴图）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.21: card items keep their icon after a save reload. 2.42.19 restored the card items themselves but they "
    "came back without a picture, because a Texture cannot be serialized into the save and the rebuilt item had a "
    "null icon. The card id encodes its source (item_bromeme_pick_<kind>_<tag>, where tag is the source item id "
    "for swap/exclusive/mix/character cards and stat_a>stat_b for job cards), so on load the mod now derives the "
    "source again and re-runs the same watermark step that created the icon in the first place. Note the id "
    "contains its prefix twice (the card is bromeme_pick|job|tag, and turning it into an item prepends "
    "item_bromeme_pick_ and replaces the pipes with underscores), so both are stripped. If a source cannot be "
    "resolved the mod logs one line naming the item instead of staying silent. some characters and items created "
    "by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.21"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
