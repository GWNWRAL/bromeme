# -*- coding: utf-8 -*-
"""对比 user://brolab（旧 id）与本 mod resources（新 id）的完整 id 列表。"""
import json, glob, os, collections

B = os.path.join(os.environ["APPDATA"], "Brotato", "brolab")
RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"


def load(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return None


old = {}
for p in glob.glob(os.path.join(B, "*.json")):
    d = load(p)
    if d:
        old[os.path.basename(p)] = d

new = {}
for p in glob.glob(os.path.join(RES, "*.json")):
    if os.path.basename(p).startswith("_"):
        continue
    d = load(p)
    if d:
        new[os.path.basename(p)] = d

print("brolab %d 个 / resources %d 个" % (len(old), len(new)))
print()

old_ids = {str(d.get("my_id", "")) for d in old.values() if d.get("my_id")}
new_ids = {str(d.get("my_id", "")) for d in new.values() if d.get("my_id")}

print("=== 完全相同 my_id 的个数:", len(old_ids & new_ids))
if old_ids & new_ids:
    print(sorted(old_ids & new_ids)[:20])

# 去掉前缀后比较
def strip_prefix(mid):
    for pre in ("item_brolab_", "item_bromeme_", "character_brolab_", "character_bromeme_"):
        if mid.startswith(pre):
            return mid[len(pre):]
    return mid

old_s = {strip_prefix(m): m for m in old_ids}
new_s = {strip_prefix(m): m for m in new_ids}
both = sorted(set(old_s) & set(new_s))
print()
print("=== 去前缀后相同的个数:", len(both))
for k in both[:40]:
    print("   %-22s  brolab=%-26s resources=%s" % (k, old_s[k], new_s[k]))

print()
print("=== brolab 拥有、resources 没有的（去前缀）:", len(set(old_s) - set(new_s)))
print("=== resources 拥有、brolab 没有的（去前缀）:", len(set(new_s) - set(old_s)))

print()
print("=== brolab 全部 id（按数字后缀排序，前 60）===")
suf = []
for m in sorted(old_ids):
    parts = m.split("_")
    try:
        n = int(parts[-1])
    except Exception:
        n = -1
    suf.append((n, m))
for n, m in sorted(suf)[:60]:
    print("   %-30s suffix=%s" % (m, n))

print()
print("=== resources 全部 id（按数字后缀排序，前 60）===")
suf2 = []
for m in sorted(new_ids):
    parts = m.split("_")
    try:
        n = int(parts[-1])
    except Exception:
        n = -1
    suf2.append((n, m))
for n, m in sorted(suf2)[:60]:
    print("   %-30s suffix=%s" % (m, n))
