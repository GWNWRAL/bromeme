# -*- coding: utf-8 -*-
"""模拟 bromeme_half_display_name 的取名结果（对照修复前后的差别）。"""
def half(a, b):
    import math
    if not a: return b
    if not b: return a
    fl = int(math.ceil(len(a) / 2.0))
    bl = int(math.ceil(len(b) / 2.0))
    return a[:fl] + b[len(b) - bl:]

# 修复前：直接拿 name（原版/其它mod 是翻译键）
pairs_raw = [
    ("ITEM_ACID", "ITEM_BAT"),
    ("ITEM_SPINE_SWORD_IV", "ITEM_HEDGEHOG"),
    ("直升机", "肘"),
]
print("=== 修复前（在翻译键上切）===")
for a, b in pairs_raw:
    print("  %-22s + %-20s -> %s" % (a, b, half(a, b)))

# 修复后：先用 tr(name) 得到显示名，再切
trans = {
    "ITEM_ACID": "酸液", "ITEM_BAT": "棒球棍", "ITEM_HEDGEHOG": "刺猬",
    "ITEM_SPINE_SWORD_IV": "脊髓剑 IV", "直升机": "直升机", "肘": "肘",
}
pairs = [("ITEM_ACID", "ITEM_BAT"), ("ITEM_SPINE_SWORD_IV", "ITEM_HEDGEHOG"), ("直升机", "肘")]
print("=== 修复后（先取显示名再切）===")
for a, b in pairs:
    da, db = trans.get(a, a), trans.get(b, b)
    print("  %-22s + %-20s -> %s" % (da, db, half(da, db)))
