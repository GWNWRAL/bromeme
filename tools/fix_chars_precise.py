# -*- coding: utf-8 -*-
"""精确修正：回滚牢大（保持未改状态），改奶蛙价格、嘉豪伤害。"""
import io, json, os, shutil

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
BK = r"D:\DSH\_mod_backups\Bromeme-2.35.0-preRelease\resources"


def load(p):
    return json.load(io.open(p, encoding="utf-8"))


def save(p, d):
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")


def find(name):
    import glob
    for p in glob.glob(os.path.join(RES, "*.json")):
        d = load(p)
        if str(d.get("name", "")) == name:
            return p, d
    return None, None


# 1) 牢大：回滚成改动前的样子（那条「每5近战伤害+1远程伤害」先不加，等确认元素伤害+8%那条的定位）
p, d = find("牢大")
if d is not None:
    src = os.path.join(BK, os.path.basename(p))
    if os.path.isfile(src):
        shutil.copyfile(src, p)
        print("牢大: 已回滚（%s）" % os.path.basename(p))
    else:
        print("!! 牢大: 备份里没有这个文件，未回滚")

# 2) 奶蛙：mutant_effect_2 的 60 → 40（道具价格）
p, d = find("奶蛙")
if d is not None:
    hit = 0
    for x in d["datas"]:
        if "mutant_effect_2" in x["base_resource_path"] and x.get("changed_key_values", {}).get("value") == 60:
            x["changed_key_values"]["value"] = 40
            hit += 1
    save(p, d)
    print("奶蛙: 价格 60→40（命中 %d 条）" % hit)

# 3) 嘉豪：coffee_effect_2 的 -25 → -15（伤害）
p, d = find("嘉豪")
if d is not None:
    hit = 0
    for x in d["datas"]:
        if "coffee_effect_2" in x["base_resource_path"] and x.get("changed_key_values", {}).get("value") == -25:
            x["changed_key_values"]["value"] = -15
            hit += 1
    save(p, d)
    print("嘉豪: 伤害 -25→-15（命中 %d 条）" % hit)
