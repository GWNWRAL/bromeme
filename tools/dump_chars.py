# -*- coding: utf-8 -*-
"""把这几个角色每条效果的基础资源 + 覆盖值打出来，好精确定位要改/要删的那条。"""
import io, json, glob, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
for who in ("奶蛙", "嘉豪", "张雪峰", "达芬奇机器人", "牢大", "丁真"):
    for p in glob.glob(os.path.join(RES, "*.json")):
        try:
            d = json.load(io.open(p, encoding="utf-8"))
        except Exception:
            continue
        if str(d.get("name", "")) != who:
            continue
        print("=" * 64)
        print("%s  %s" % (who, d.get("my_id")))
        for i, x in enumerate(d.get("datas", [])):
            c = x.get("changed_key_values", {})
            shown = {k: v for k, v in c.items() if k in ("key", "value", "custom_key", "text_key", "stat_displayed", "nb_stat_scaled", "stat_scaled")}
            print("  [%d] %-26s %s" % (i, x["base_resource_path"].split("/")[-1], json.dumps(shown, ensure_ascii=False)))
