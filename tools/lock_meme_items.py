# -*- coding: utf-8 -*-
"""1) 赌徒meme 追加一条 +30 meme值 效果
2) 8 个 meme 面板专属道具改成"未解锁"（unlocked_by_default = 0）

关于第 2 点：本 mod 的 can_be_looted = not (unlocked_by_default == 1)，
所以 unlocked_by_default=1 的 24 件本来就不进商店/宝箱池。
把它们改成 0 之后：
  - unlocked_by_default = false  -> 不再进 ProgressData.items_unlocked（图鉴显示锁定）
  - can_be_looted = true         -> 会"变成"能进商店池的那一批
所以必须同时确认它们不会因此跑进商店。做法见 build 后校验：
  商店池入选 = can_be_looted 且 hash 在 items_unlocked 里。这两件互斥，
  所以只要 unlocked_by_default=0 而 items_unlocked 里没有它们，就依然进不了池。
  （即：真正决定"进不进商店"的是 unlocked_by_default=1，这一点必须写进交接文档。）
"""
import io, json, os, shutil

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BAK = r"D:\DSH\_aitato_work\backup_before_meme_lock"

# 面板专属的 8 个 meme 道具（meme核心/混沌/随机/出售 + 熵增/赌徒/量子/献祭）
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
GAMBLER_ID = "item_bromeme_meme_gambler"
MEME_EFFECT = {
    "base_resource_path": "res://items/all/cake/cake_effect_1.tres",
    "changed_key_values": {
        "key": "stat_meme",
        "value": 30,
        "text_key": "",
        "custom_key": "",
        "storage_method": 0,
        "effect_sign": 0,
    },
}

os.makedirs(BAK, exist_ok=True)

files = {}
for p in sorted(os.listdir(RES)):
    if not p.endswith(".json") or p.startswith("_"):
        continue
    d = json.load(io.open(os.path.join(RES, p), encoding="utf-8"))
    if int(d.get("item_type", 1)) == 0:
        continue
    files[str(d.get("my_id"))] = p

changed = []
for mid, fname in files.items():
    p = os.path.join(RES, fname)
    d = json.load(io.open(p, encoding="utf-8"))
    touched = False

    # (1) 赌徒：追加 +30 meme值（幂等）
    if mid == GAMBLER_ID:
        has = any(ds.get("changed_key_values", {}).get("key") == "stat_meme"
                  for ds in d.get("datas", []))
        if not has:
            d.setdefault("datas", []).append(json.loads(json.dumps(MEME_EFFECT)))
            touched = True
            print("赌徒meme：追加 +30 meme值效果")

    # (2) 8 个 meme 道具：未解锁
    if mid in MEME_IDS and int(d.get("unlocked_by_default", 1)) != 0:
        d["unlocked_by_default"] = 0
        touched = True

    if touched:
        shutil.copy2(p, os.path.join(BAK, fname))
        io.open(p, "w", encoding="utf-8", newline="\n").write(
            json.dumps(d, ensure_ascii=False, indent=2) + "\n")
        changed.append(mid)

print("改动的文件数:", len(changed))
print("改后校验：")
for mid in MEME_IDS + [GAMBLER_ID]:
    fname = files.get(mid)
    d = json.load(io.open(os.path.join(RES, fname), encoding="utf-8"))
    keys = [ds.get("changed_key_values", {}).get("key") for ds in d.get("datas", [])]
    print("  %-34s unlocked_by_default=%s  effects=%s" % (
        mid, d.get("unlocked_by_default"), keys))
