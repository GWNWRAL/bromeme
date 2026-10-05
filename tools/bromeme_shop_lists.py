# -*- coding: utf-8 -*-
"""列出本 mod 95 件道具的：JSON unlocked_by_default / 最终 unlocked_by_default /
can_be_looted / 是否进商店，并按这两类分组打印。"""
import json, glob, os, io

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BROLAB_DIR = os.path.join(os.environ["APPDATA"], "Brotato", "brolab")

items = []
for p in sorted(glob.glob(os.path.join(RES, "*.json"))):
    if os.path.basename(p).startswith("_"):
        continue
    d = json.load(io.open(p, encoding="utf-8"))
    if int(d.get("item_type", 1)) == 0:
        continue  # 角色不算
    j = int(d.get("unlocked_by_default", 1))
    can_be_looted = not (j == 1)          # = 现在代码里的算法
    items.append({
        "file": os.path.basename(p),
        "id": str(d.get("my_id", "")),
        "name": str(d.get("name", "")),
        "key": j,
        "cbl": can_be_looted,
        "tier": int(d.get("tier", 0)),
        "price": int(d.get("price", 0)),
        "max_nb": int(d.get("max_nb", -1)),
        "tags": d.get("tags", []),
    })

shop = [x for x in items if x["cbl"]]
nosh = [x for x in items if not x["cbl"]]
print("道具合计 %d 件：进商店 %d 件 / 不进商店 %d 件" % (len(items), len(shop), len(nosh)))
print()

print("=" * 78)
print("【A】会出现在商店（JSON unlocked_by_default = 1 ⇒ can_be_looted = true）")
print("=" * 78)
for x in sorted(shop, key=lambda v: v["id"]):
    print("  %-34s %-14s tier%d 价%-5d max_nb=%-3d tags=%s" % (
        x["id"], x["name"], x["tier"], x["price"], x["max_nb"], ",".join(x["tags"])))
print()

print("=" * 78)
print("【B】不会出现在商店（JSON unlocked_by_default = 0 ⇒ can_be_looted = false）")
print("=" * 78)
for x in sorted(nosh, key=lambda v: v["id"]):
    print("  %-34s %-14s tier%d 价%-5d max_nb=%-3d tags=%s" % (
        x["id"], x["name"], x["tier"], x["price"], x["max_nb"], ",".join(x["tags"])))
print()

# 顺便统计 brolab 里现存文件的规模，供清理讨论
n_b = len(glob.glob(os.path.join(BROLAB_DIR, "*.json")))
print("参考：user://brolab 目前有 %d 个 json" % n_b)
