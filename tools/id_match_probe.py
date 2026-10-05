# -*- coding: utf-8 -*-
"""严格对照 user://brolab 的 my_id 与 resources 的 my_id，各种匹配规则各命中多少。"""
import io, json, os, glob, collections

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BRO = os.path.join(os.environ["APPDATA"], "Brotato", "brolab")


def load(d):
    out = {}
    for p in glob.glob(os.path.join(d, "*.json")):
        if os.path.basename(p).startswith("_"):
            continue
        try:
            dd = json.load(io.open(p, encoding="utf-8"))
        except Exception:
            continue
        mid = str(dd.get("my_id", ""))
        if mid:
            out[os.path.basename(p)] = (mid, dd)
    return out


res = load(RES)
bro = load(BRO)
res_ids = {v[0] for v in res.values()}
bro_ids = {v[0] for v in bro.values()}

print("resources %d 个 my_id / brolab %d 个 my_id" % (len(res_ids), len(bro_ids)))
print()

# 规则1 完全相同
print("规则1 完全相同:", len(res_ids & bro_ids), sorted(res_ids & bro_ids)[:10])

# 规则2 去掉 brolab/bromeme 前缀后相同
def strip(m):
    for pre in ("item_brolab_", "character_brolab_", "item_bromeme_", "character_bromeme_"):
        if m.startswith(pre):
            return m[len(pre):]
    return m

ra = {strip(m): m for m in res_ids}
ba = {strip(m): m for m in bro_ids}
print("规则2 去前缀后相同:", len(set(ra) & set(ba)))
for k in sorted(set(ra) & set(ba))[:20]:
    print("     %-24s brolab=%s  resources=%s" % (k, ba[k], ra[k]))

# 规则3 去掉最后的数字后缀（即只比名字主体）
def body(m):
    parts = m.split("_")
    if parts and parts[-1].isdigit():
        parts = parts[:-1]
    return "_".join(parts)

rb = {body(m): m for m in res_ids}
bb = {body(m): m for m in bro_ids}
print("规则3 去后缀后相同:", len(set(rb) & set(bb)))
for k in sorted(set(rb) & set(bb))[:20]:
    print("     %-24s brolab=%s  resources=%s" % (k, bb[k], rb[k]))

# 规则4 去前缀 + 去后缀
rc = {body(strip(m)): m for m in res_ids}
bc = {body(strip(m)): m for m in bro_ids}
print("规则4 去前缀+去后缀后相同:", len(set(rc) & set(bc)))
for k in sorted(set(rc) & set(bc))[:30]:
    print("     %-22s brolab=%s  resources=%s" % (k, bc[k], rc[k]))

print()
print("=== brolab 前 20 个 id ===")
for m in sorted(bro_ids)[:20]:
    print("   ", m)
print("=== resources 前 20 个 id ===")
for m in sorted(res_ids)[:20]:
    print("   ", m)
