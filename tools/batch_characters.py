# -*- coding: utf-8 -*-
"""一批角色数值/效果改动（嘉豪 / 奶蛙 / 张雪峰 / 牢大 / 达芬奇 / 不死老表 / 鸡哥）。"""
import io, json, glob, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
CAKE = "res://items/all/cake/cake_effect_1.tres"
POWER = "res://items/all/power_generator/power_generator_effect_1.tres"
report = []


def load(p):
    return json.load(io.open(p, encoding="utf-8"))


def save(p, d):
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")


def find_by_name(name):
    for p in glob.glob(os.path.join(RES, "*.json")):
        try:
            d = load(p)
        except Exception:
            continue
        if str(d.get("name", "")) == name:
            return p, d
    return None, None


def add_effect(d, key, value, text=""):
    d["datas"].append({"base_resource_path": CAKE,
                       "changed_key_values": {"key": key, "value": value, "text_key": text,
                                              "custom_key": "", "storage_method": 0, "effect_sign": 0}})


def ck(x):
    return x.get("changed_key_values", {})


# 1) 嘉豪 / 奶蛙：meme值 +30
for who in ("嘉豪", "奶蛙"):
    p, d = find_by_name(who)
    if d is None:
        report.append("!! 找不到角色 %s" % who)
        continue
    if not any(ck(x).get("key") == "stat_meme" and ck(x).get("value") == 30 for x in d["datas"]):
        add_effect(d, "stat_meme", 30)
        save(p, d)
        report.append("%s(%s): 加 stat_meme +30 → %d 条效果" % (who, d["my_id"], len(d["datas"])))

# 2) 奶蛙：道具价格 60% → 40%
p, d = find_by_name("奶蛙")
if d is not None:
    hit = False
    for x in d["datas"]:
        c = ck(x)
        if c.get("value") == 60 and "price" in str(c.get("key", "")):
            c["value"] = 40
            hit = True
    if hit:
        save(p, d)
        report.append("奶蛙: 道具价格 60% → 40%")
    else:
        report.append("!! 奶蛙: 没找到 value=60 的价格效果，dump=%s" % [ck(x).get("key") for x in d["datas"]])

# 3) 嘉豪：伤害 -25% → -15%
p, d = find_by_name("嘉豪")
if d is not None:
    hit = False
    for x in d["datas"]:
        c = ck(x)
        if c.get("key") == "stat_percent_damage" and c.get("value") == -25:
            c["value"] = -15
            hit = True
    if hit:
        save(p, d)
        report.append("嘉豪: 伤害 -25% → -15%")
    else:
        report.append("!! 嘉豪: 没找到 stat_percent_damage=-25，dump=%s" % [(ck(x).get("key"), ck(x).get("value")) for x in d["datas"]])

# 4) 张雪峰：+15 生命 → +20
p, d = find_by_name("张雪峰")
if d is not None:
    hit = False
    for x in d["datas"]:
        c = ck(x)
        if c.get("key") == "stat_max_hp" and c.get("value") == 15:
            c["value"] = 20
            hit = True
    if hit:
        save(p, d)
        report.append("张雪峰: 生命 +15 → +20")
    else:
        report.append("!! 张雪峰: 没找到 stat_max_hp=15，dump=%s" % [(ck(x).get("key"), ck(x).get("value")) for x in d["datas"]])

# 5) 牢大：删元素伤害+8%，改为「每 5 近战伤害 +1 远程伤害」
p, d = find_by_name("牢大")
if d is not None:
    before = len(d["datas"])
    kept = [x for x in d["datas"] if not (ck(x).get("key") == "stat_elemental_damage" and ck(x).get("value") == 8)]
    removed = before - len(kept)
    d["datas"] = kept
    d["datas"].append({"base_resource_path": POWER,
                       "changed_key_values": {"key": "stat_ranged_damage", "nb_stat_scaled": 5,
                                              "stat_scaled": "stat_melee_damage"}})
    save(p, d)
    report.append("牢大: 删元素伤害+8%%(%d 条) + 加「每5近战伤害→+1远程伤害」→ %d 条" % (removed, len(d["datas"])))
    report.append("     牢大现有 key 列表: %s" % [ck(x).get("key") for x in d["datas"]])

# 6) 达芬奇机器人：删除「护甲修改减少」那条
p, d = find_by_name("达芬奇机器人")
if d is not None:
    before = len(d["datas"])
    kept = []
    for x in d["datas"]:
        blob = json.dumps(ck(x), ensure_ascii=False)
        if "armor" in blob and ("stat_armor" in blob or "armor" in str(ck(x).get("stat_displayed", ""))):
            continue
        kept.append(x)
    if len(kept) != before:
        d["datas"] = kept
        save(p, d)
        report.append("达芬奇机器人: 删掉护甲相关效果 %d 条 → %d 条" % (before - len(kept), len(d["datas"])))
    else:
        report.append("!! 达芬奇: 没匹配到护甲条目，dump=%s" % [(ck(x).get("key"), ck(x).get("stat_displayed")) for x in d["datas"]])

# 7) 不死老表：武器数 2 → 4
p, d = find_by_name("不死老表")
if d is not None:
    hit = False
    for x in d["datas"]:
        if "multitasker_effect_1" in x["base_resource_path"] and ck(x).get("value") == 2:
            ck(x)["value"] = 4
            hit = True
    if hit:
        save(p, d)
        report.append("不死老表: 可装备武器 2 → 4")
    else:
        report.append("!! 不死老表: 没找到 multitasker value=2")

# 8) 鸡哥：dump 那 4 条易伤效果（先看再决定怎么改）
p, d = find_by_name("鸡哥")
if d is not None:
    out = []
    for x in d["datas"]:
        if "ice_cube" in x["base_resource_path"]:
            out.append({k: v for k, v in ck(x).items() if k in ("key", "value", "max_stacks", "max_procs", "text_key")})
    report.append("鸡哥(%s) ice_cube 条目: %s" % (d["my_id"], json.dumps(out, ensure_ascii=False)))

print("\n".join(report) if report else "没有任何改动")
