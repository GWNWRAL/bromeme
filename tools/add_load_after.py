# -*- coding: utf-8 -*-
"""给 manifest 加 load_after: FengLiu-FengAddMods，让我们的 _init 排在它的阻断之后。"""
import io, json

p = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(p, encoding="utf-8"))
godot = d.setdefault("extra", {}).setdefault("godot", {})
la = godot.get("load_after") or []
if "FengLiu-FengAddMods" not in la:
    la.append("FengLiu-FengAddMods")
godot["load_after"] = la
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
print("load_after =", la)
print("version =", d["version_number"])
