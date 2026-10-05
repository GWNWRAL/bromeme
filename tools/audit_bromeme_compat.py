# -*- coding: utf-8 -*-
"""审计 bromeme 的 5 个 BroLab 兼容效果：找出 key / custom_key 跟 player_run_data 扩展
   注册的名字对不上的条目 —— 那些在 apply() 里会 <null>.append()，直接触发
   0xC0000005 @ 0x1F8D28A。
"""
import json, os, glob

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
COMPAT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\brolab_compat"

REGISTERED = {
    "brolab_effect_receive_item_at_wave",
    "brolab_effect_receive_stat_at_wave",
    "brolab_effect_midas_hand",
    "brolab_stats_end_of_wave_after_wave",
    "brolab_effect_convert_stats_at_wave",
}

# 效果脚本 -> 从数据里取哪个字段当 RunData 的 key
EFFECT_FIELD = {
    "receive_items_at_wave.gd": ("key", "key"),
    "receive_stat_at_wave.gd": ("key", "key"),
    "effect_midas_hand.gd": ("key", "key"),
    "convert_stats_at_wave.gd": ("custom_key", "custom_key"),
    "stats_end_of_wave_after_wave.gd": ("hardcoded", "brolab_stats_end_of_wave_after_wave"),
}

print("=== brolab_compat 目录 ===")
for dp, dn, fn in os.walk(COMPAT):
    for f in fn:
        if f.endswith(".tres"):
            print("   ", os.path.join(dp, f).replace(COMPAT, "brolab_compat"))

print("\n=== 用到兼容效果的 json 条目 ===")
problems = []
for p in sorted(glob.glob(os.path.join(RES, "*.json"))):
    if os.path.basename(p).startswith("_"):
        continue
    d = json.load(open(p, encoding="utf-8"))
    for i, e in enumerate(d.get("datas", [])):
        base = e.get("base_resource_path", "")
        name = base.split("/")[-1]
        if name not in EFFECT_FIELD:
            continue
        field, fallback = EFFECT_FIELD[name]
        ckv = e.get("changed_key_values", {}) or {}
        if field == "hardcoded":
            value = fallback
        else:
            value = ckv.get(field, fallback if field == "key" else "")
        ok = value in REGISTERED
        line = "%-16s %-14s [%d] %-30s %s=%r %s" % (
            os.path.basename(p), d.get("name", "?"), i, name, field, value,
            "OK" if ok else "!!!!! 未注册 -> apply() 会对 null 调 append")
        print(line)
        if not ok:
            problems.append((os.path.basename(p), d.get("name"), d.get("my_id"), i, name, field, value, ckv))

print("\n=== 有问题的 %d 条 ===" % len(problems))
for pr in problems:
    print("   %s (%s / %s) entry#%d %s  %s=%r  changed=%s" % (
        pr[0], pr[1], pr[2], pr[3], pr[4], pr[5], pr[6], json.dumps(pr[7], ensure_ascii=False)))
