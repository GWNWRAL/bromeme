# -*- coding: utf-8 -*-
"""审计 bromeme 内容里"把物品 id 当翻译键用"的地方。

原版 Effect.get_args() 会做 tr(key.to_upper())，也就是说只要某个效果的 key
指向一个物品 id，这个 id 的全大写形式必须是一个已注册的翻译键，否则描述里
会直接显示成 key（截图里的 ITEM_BROLAB_YAN_262 就是这么来的）。
"""
import json, os, glob

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"

# 原版物品 id 集合（从解包目录里拿）
VANILLA = set()
for p in glob.glob(r"D:\DSH\Brotato_unpacked_1.1.15.4\items\**\*.tres", recursive=True):
    try:
        txt = open(p, encoding="utf-8", errors="ignore").read()
    except Exception:
        continue
    for line in txt.splitlines():
        line = line.strip()
        if line.startswith("my_id = ") and '"' in line:
            VANILLA.add(line.split('"')[1])
            break

owns = {}
json_files = sorted(glob.glob(os.path.join(RES, "*.json")))
for p in json_files:
    if os.path.basename(p).startswith("_"):
        continue
    try:
        v = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print("BAD JSON", p, e)
        continue
    owns[v.get("my_id", "?")] = (os.path.basename(p), v.get("name", ""))

print("bromeme 自己定义的内容: %d 个" % len(owns))
print("其中物品: %d" % sum(1 for k, _ in owns.items() if k.startswith("item_")))
print()

refs = []
for p in json_files:
    if os.path.basename(p).startswith("_"):
        continue
    v = json.load(open(p, encoding="utf-8"))
    for d in v.get("datas", []):
        ckv = d.get("changed_key_values", {}) or {}
        key = ckv.get("key")
        if isinstance(key, str) and key.startswith("item_"):
            refs.append((v.get("my_id"), v.get("name"), key, d.get("base_resource_path", "")))

print("=== 被 key 引用的物品 id (%d 处) ===" % len(refs))
broken = [r for r in refs if r[2] not in VANILLA]
for src_id, src_name, key, base in refs:
    kind = "原版(有翻译)" if key in VANILLA else ("bromeme自己的" if key in owns else "未知")
    if kind != "原版(有翻译)":
        print("  %-28s (%-6s) -> %-28s  [%s]" % (src_id, src_name, key, kind))
print("  需要补翻译的引用: %d 处" % len(broken))

# 顺带看看所有 changed_key_values 里出现过哪些字段
fields = {}
for p in json_files:
    if os.path.basename(p).startswith("_"):
        continue
    v = json.load(open(p, encoding="utf-8"))
    for d in v.get("datas", []):
        for k in (d.get("changed_key_values", {}) or {}):
            fields[k] = fields.get(k, 0) + 1
print("\n=== changed_key_values 用到的字段 ===")
for k, n in sorted(fields.items(), key=lambda x: -x[1]):
    print("   %-28s %d" % (k, n))
