# -*- coding: utf-8 -*-
"""看那 4 个提到「反抗」的资源是什么（名字 / my_id / 效果来源）。"""
import io, json, os, glob

res = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
for p in sorted(glob.glob(os.path.join(res, "*.json"))):
    t = io.open(p, encoding="utf-8").read()
    if "反抗" not in t and "孙笑川" not in t:
        continue
    d = json.loads(t)
    print("=" * 60)
    print(os.path.basename(p), "| name =", d.get("name"), "| my_id =", d.get("my_id"),
          "| item_type =", d.get("item_type"), "| unlocked =", d.get("unlocked_by_default"))
    for i, data in enumerate(d.get("datas", [])):
        ck = data.get("changed_key_values", {})
        keys = {k: v for k, v in ck.items() if k in ("key", "text_key", "custom_key", "value", "storage_method")}
        print("   [%d] %s  %s" % (i, data.get("base_resource_path", "?").split("/")[-1], keys))
