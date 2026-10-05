# -*- coding: utf-8 -*-
"""把 8 个 meme 面板专属道具的 json 从 "locked": true 改成 "no_loot": true。

区别（代码 mod_main.gd 里的处理）：
  locked    -> unlocked_by_default = false（图鉴锁定）
  no_loot   -> unlocked_by_default = true（图鉴已解锁，用户最新要求）
               且 can_be_looted  = false（不进商店池 / 宝箱）
"""
import io, json, os, shutil

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BAK = r"D:\DSH\_aitato_work\backup_before_noloot"
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
    p = os.path.join(RES, fname)
    d = json.load(io.open(p, encoding="utf-8"))
    if d.get("no_loot") is True and "locked" not in d:
        print("%-34s 已经是 no_loot" % mid)
        continue
    shutil.copy2(p, os.path.join(BAK, fname))
    out = {}
    for k, v in d.items():
        if k == "locked":
            continue          # 丢掉旧的 locked
        out[k] = v
        if k == "my_id":
            out["no_loot"] = True
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    touched += 1

print()
print("改动文件数:", touched)
print("校验（代码规则：unlocked 恒 true；can_be_looted = not no_loot and not(json==1)）:")
bad = 0
for mid in MEME_IDS:
    d = json.load(io.open(os.path.join(RES, files[mid]), encoding="utf-8"))
    j = int(d.get("unlocked_by_default", 1))
    no_loot = d.get("no_loot") is True
    unlocked = True
    cbl = (not no_loot) and (not (j == 1))
    if cbl:
        bad += 1
    print("  %-34s no_loot=%-5s locked字段=%s -> unlocked=%-5s can_be_looted=%s" % (
        mid, no_loot, d.get("locked"), unlocked, cbl))
print("  错误（can_be_looted 应为 False）:", bad)
