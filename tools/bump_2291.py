# -*- coding: utf-8 -*-
"""2.29.1：换属性后的效果文本自带 {0} 占位符，避免别的 mod 属性翻译无占位符导致看不到数值。"""
import io, json

p = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(p, encoding="utf-8"))
d["version_number"] = "2.29.1"
add = ("2.29.1: a swapped stat effect now carries an explicit \"{0} <stat name>\" text instead of "
       "relying on the stat translation key - stats added by other mods have no {0} placeholder in "
       "their translation, so a modified card showed the stat name with no visible amount.")
d["description"] = "some characters and items created by Brolab. " + add + " " + d["description"]
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
print("版本 ->", d["version_number"])
