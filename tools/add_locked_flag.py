# -*- coding: utf-8 -*-
"""给 8 个 meme 面板专属道具的 json 加上 "locked": true。

配合代码：mod_main.gd 的 _build_item() / _fill_common() 现在会读这个字段，
   locked = true  ->  unlocked_by_default = false（图鉴锁定）
                     can_be_looted        = false（不进商店池，宝箱也抽不到）
"""
import io, json, os, shutil

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BAK = r"D:\DSH\_aitato_work\backup_before_meme_lock"
MEME_IDS = [
    "item_bromeme_meme_core",
    "item_bromeme_meme_chaos",
    "item_bromeme_meme_random",
    "item_bromeme_meme_sell",
    "item_bromeme_meme_entropy",
    "item_bromeme_meme_gambler",
    "item_bromeme_meme_quantum",
    "item_bromeme_meme_sacrifice",
]

os.makedirs(BAK, exist_ok=True)

files = {}
for p in sorted(os.listdir(RES)):
    if not p.endswith(".json") or p.startswith("_"):
        continue
    d = json.load(io.open(os.path.join(RES, p), encoding="utf-8"))
    if int(d.get("item_type", 1)) == 0:
        continue
    files[str(d.get("my_id"))] = p

touched = 0
for mid in MEME_IDS:
    fname = files.get(mid)
    if fname is None:
        print("!! 找不到 %s" % mid)
        continue
    p = os.path.join(RES, fname)
    d = json.load(io.open(p, encoding="utf-8"))
    if d.get("locked") is True:
        print("%-34s 已经是 locked" % mid)
        continue
    shutil.copy2(p, os.path.join(BAK, fname))
    # locked 放在 my_id 后面，读数时一眼能看到
    out = {}
    for k, v in d.items():
        out[k] = v
        if k == "my_id":
            out["locked"] = True
    if "locked" not in out:
        out["locked"] = True
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    touched += 1

print()
print("加了 locked 的文件数:", touched)
print("改后校验：")
for mid in MEME_IDS:
    fname = files[mid]
    d = json.load(io.open(os.path.join(RES, fname), encoding="utf-8"))
    keys = [ds.get("changed_key_values", {}).get("key") for ds in d.get("datas", [])]
    print("  %-34s locked=%-5s json_unlocked=%s effects=%s" % (
        mid, d.get("locked"), d.get("unlocked_by_default"), keys))
