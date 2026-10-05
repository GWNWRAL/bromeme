# -*- coding: utf-8 -*-
"""校验 hash 算法 + 统计本 mod 道具在解锁表里的真实命中情况。"""
import json, os, glob, io

def gd_hash(text):
    if text == "":
        return 5381
    h = 5381
    for ch in text:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFF
    return h - 0x100000000 if h >= 0x80000000 else h

SAVE = os.path.join(os.environ["APPDATA"], "Brotato", "76561198978820132", "save_v3_1.json")
s = json.load(io.open(SAVE, "r", encoding="utf-8"))
unlock = set(int(x) for x in s["items_unlocked"])
bought = set(int(k) for k in s["items_bought"].keys())
chars = set(int(x) for x in s["characters_unlocked"])

VANILLA = ["item_sad_tomato", "item_apple", "item_bat", "item_goat_skull", "item_hedgehog",
           "item_lens", "item_whetstone", "item_fertilizer", "item_piggy_bank",
           "item_stone_skin", "item_helmet", "item_crown", "item_medikit"]
print("=== 原版道具校验（我的 hash 算法是否可信）===")
ok = 0
for v in VANILLA:
    h = gd_hash(v)
    inn = h in unlock
    ok += 1 if inn else 0
    print("  %-22s hash=%-12d 在解锁表=%s 在购买表=%s" % (v, h, inn, h in bought))
print("  -> %d/%d 命中" % (ok, len(VANILLA)))

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
items = []
for p in sorted(glob.glob(os.path.join(MOD, "*.json"))):
    if os.path.basename(p).startswith("_"):
        continue
    d = json.load(io.open(p, "r", encoding="utf-8"))
    items.append((os.path.basename(p), d))

def show(pred, title, kind="item"):
    print("\n=== %s ===" % title)
    n_in = n_out = 0
    for name, d in items:
        if int(d.get("item_type", 1)) == 0:
            continue
        mid = str(d.get("my_id", ""))
        h = gd_hash(mid)
        pred_ok = pred(d)
        if not pred_ok:
            continue
        if h in unlock:
            n_in += 1
        else:
            n_out += 1
            print("   缺: %-40s hash=%-12d unlocked_by_default=%s price=%s" %
                  (mid, h, d.get("unlocked_by_default"), d.get("price")))
    print("  %s: 命中 %d / 缺失 %d" % (title, n_in, n_out))

show(lambda d: int(d.get("unlocked_by_default", 1)) != 0, "JSON unlocked_by_default=1（应进商店的 24 件）")
show(lambda d: int(d.get("unlocked_by_default", 1)) == 0, "JSON unlocked_by_default=0（设计上锁定的 71 件）")

# 角色
print("\n=== 角色 ===")
cin = cout = 0
for name, d in items:
    if int(d.get("item_type", 1)) != 0:
        continue
    mid = str(d.get("my_id", ""))
    h = gd_hash(mid)
    if h in chars:
        cin += 1
    else:
        cout += 1
        print("   缺: %-40s hash=%-12d" % (mid, h))
print("  角色命中 %d / 缺失 %d" % (cin, cout))
