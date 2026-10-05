# -*- coding: utf-8 -*-
"""两件事的离线核对：
1) 验证「JSON unlocked_by_default=1 => 不进商店」这个映射（用改名前后的两版备份对比代码）。
2) 算出 brolab 按 my_id 清理会命中哪些文件（不实际删除）。
"""
import io, json, os, glob

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BRO = os.path.join(os.environ["APPDATA"], "Brotato", "brolab")


def by_id(d):
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
            out[mid] = os.path.basename(p)
    return out


res = by_id(RES)
bro = by_id(BRO)

# ---- 1) 分组统计（按用户关心的 24 / 71）----
one = {m: f for m, f in res.items() if int(json.load(io.open(os.path.join(RES, f), encoding="utf-8")).get("unlocked_by_default", 1)) == 1}
zero = {m: f for m, f in res.items() if m not in one}
print("=== resources 分组 ===")
print("json=1（can_be_looted=false ⇒ 不进商店）: %d 件" % len(one))
print("json=0（can_be_looted=true  ⇒ 进商店）  : %d 件" % len(zero))
print()

# ---- 2) brolab 按 my_id 清理会命中哪些 ----
def legacy(mid):
    if "_bromeme_" in mid:
        return mid.replace("_bromeme_", "_brolab_", 1)
    return mid


exact, legacy_hit = [], []
for mid, f in bro.items():
    if mid in res:
        exact.append((f, mid))
    elif legacy(mid) in res:
        legacy_hit.append((f, mid, legacy(mid)))

print("=== brolab 清理演练（只看不删）===")
print("brolab 文件数: %d" % len(bro))
print("规则1 严格相同 my_id 命中: %d" % len(exact))
for f, m in exact:
    print("   %-22s %s" % (f, m))
print()
print("规则2 （额外）把 item_bromeme_X 换成 item_brolab_X 后命中: %d" % len(legacy_hit))
for f, m, l in legacy_hit[:20]:
    print("   %-22s %s  ->  %s" % (f, m, l))
print()
print("不命中（保留）: %d" % (len(bro) - len(exact) - len(legacy_hit)))
