# -*- coding: utf-8 -*-
"""看 FengLiu-FengAddMods（土豆随想）到底是什么 mod，以及开关它时日志里 item_parent_data 的差别。"""
import io, json, os, re, zipfile

zp = r"D:\Apps\steam\steamapps\workshop\content\1942280\3768330140\FengLiu-FengAddMods.zip"
zf = zipfile.ZipFile(zp)
names = zf.namelist()
print("=== 条目数", len(names))
for n in names:
    if n.endswith("manifest.json") and n.count("/") <= 2:
        print("---", n)
        print(zf.read(n).decode("utf-8", "replace")[:1200])
        break

print("\n=== 目录概览 ===")
tops = {}
for n in names:
    parts = n.split("/")
    key = "/".join(parts[:3]) if len(parts) > 3 else n
    tops[key] = tops.get(key, 0) + 1
for k in sorted(tops)[:45]:
    print("  %-70s %d" % (k, tops[k]))

print("\n=== 有没有加属性 / 角色 / 改波次结束流程 ===")
pat = re.compile(rb"stat_[a-z0-9_]+|character_[a-z0-9_]+|get_upgrades|show_options|_change_scene|install_script_extension")
hits = {}
for n in names:
    if not n.endswith((".gd", ".tres", ".json")):
        continue
    try:
        b = zf.read(n)
    except Exception:
        continue
    for m in pat.finditer(b):
        s = m.group().decode()
        if s.startswith("stat_") and len(s) < 8:
            continue
        hits.setdefault(s, set()).add(n.split("/")[-1])
for k in sorted(hits):
    if k.startswith(("get_upgrades", "show_options", "_change_scene", "install_script_extension")) or k.count("_") >= 1:
        print("  %-42s %s" % (k, sorted(hits[k])[:3]))

print("\n=== 两次启动日志里 item_parent_data 相关行 ===")
logs = r"$env:APPDATA\Brotato\logs"
