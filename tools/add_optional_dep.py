# -*- coding: utf-8 -*-
"""把 FengLiu-FengAddMods 放进 optional_dependencies（缺失不报错），强制它先于我们初始化。"""
import io, json

p = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(p, encoding="utf-8"))
godot = d.setdefault("extra", {}).setdefault("godot", {})
od = godot.get("optional_dependencies") or []
if "FengLiu-FengAddMods" not in od:
    od.append("FengLiu-FengAddMods")
godot["optional_dependencies"] = od
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
print("optional_dependencies =", od)
