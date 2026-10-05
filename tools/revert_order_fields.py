# -*- coding: utf-8 -*-
"""回滚 manifest 里没生效的 load_after / optional_dependencies，版本推到 2.30.1。"""
import io, json

p = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(p, encoding="utf-8"))
godot = d.setdefault("extra", {}).setdefault("godot", {})
if godot.get("load_after") == ["FengLiu-FengAddMods"]:
    godot["load_after"] = []
if godot.get("optional_dependencies") == ["FengLiu-FengAddMods"]:
    godot["optional_dependencies"] = []
d["version_number"] = "2.30.1"
add = ("2.30.1: the FengAddMods compatibility hook stays in (Bromeme detects FengLiu-FengAddMods and "
       "re-installs the item_parent_data extension it removes), but the manifest load-order tricks "
       "(load_after / optional_dependencies) turned out not to change the _init order, so they were "
       "reverted. Verified: with FengAddMods enabled the game still fails to compile 196 vanilla scripts "
       "regardless of who applies that extension, so the two mods are mutually incompatible as shipped.")
d["description"] = "some characters and items created by Brolab. " + add + " " + d["description"]
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
print("版本 ->", d["version_number"], "| load_after =", godot.get("load_after"), "| optional =", godot.get("optional_dependencies"))
