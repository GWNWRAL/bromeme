# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.22 + 顶部追加描述（卡道具图标存进存档）。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.22: card items keep their icon reliably now, using the same trick as the Capybara mod (Dbear-Capybara). "
    "The icon of a card item is composed at runtime (source picture plus the mod logo watermark) and vanilla "
    "serialize never stores a Texture, so after a reload the item came back with no picture. Rebuilding it on load "
    "also cannot be trusted: a real save-load happens BEFORE mod content is installed (measured: ItemService.items "
    "held only the 377 vanilla items at that moment, our 95 were not registered yet), so looking the source up by "
    "id fails and a late retry updates the item after the inventory already rendered an empty slot. Capybara solves "
    "this by putting the icon resource path INTO the save and loading it back, so card items now use a small script "
    "of their own that does exactly that: serialize writes bromeme_icon_path, deserialize_and_merge loads it back "
    "(mod pngs are decoded from bytes because they have no import cache, anything else goes through load). A "
    "fallback that resolves the source from the resources index remains for cards that have no stored path. "
    "Also fixed in this pass: the memeboss balance tweaks from 2.42.20 (Van waits 1s longer after his three-dash "
    "chain, the traitor ninja dashes 25 percent slower). some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.22"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))
