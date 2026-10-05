# -*- coding: utf-8 -*-
"""把本 mod 的 my_id 用游戏同一算法(String.hash() = djb2, 32bit)算成 hash，
去存档 items_unlocked / items_bought 里比对；并把 Toys&Balls 的道具作为对照。"""
import json, os, glob, io

def gd_hash(text):
    if text == "":
        return 5381
    h = 5381
    for ch in text:
        c = ord(ch)
        # Godot 3 String.hash() 遍历 UTF-32 码点
        h = ((h << 5) + h + c) & 0xFFFFFFFF
    # 转成有符号 32 位（保存文件里是 int）
    if h >= 0x80000000:
        h -= 0x100000000
    return h

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SAVE_DIR = os.path.join(os.environ["APPDATA"], "Brotato")

# ---- 读我们的条目 ----
ours = []
for p in sorted(glob.glob(os.path.join(MOD, "resources", "*.json"))):
    if os.path.basename(p).startswith("_"):
        continue
    try:
        d = json.load(io.open(p, "r", encoding="utf-8"))
    except Exception as e:
        print("BAD JSON", p, e)
        continue
    ours.append((os.path.basename(p), d))

def is_char(d):
    return int(d.get("item_type", 1)) == 0

our_items = [(n, d) for n, d in ours if not is_char(d)]
our_chars = [(n, d) for n, d in ours if is_char(d)]
print("我们的条目: %d 道具 / %d 角色" % (len(our_items), len(our_chars)))

our_hashes = {}
for n, d in our_items:
    mid = str(d.get("my_id", ""))
    our_hashes[mid] = gd_hash(mid)

# ---- 读存档 ----
for save_name in ["save_v3_1.json", "save_v3_2.json"]:
    sp = os.path.join(SAVE_DIR, "76561198978820132", save_name)
    if not os.path.exists(sp):
        continue
    s = json.load(io.open(sp, "r", encoding="utf-8"))
    unlock = set(int(x) for x in s.get("items_unlocked", []))
    bought = set(int(k) for k in s.get("items_bought", {}).keys())
    miss_unlock = [(m, h) for m, h in our_hashes.items() if h not in unlock]
    hit_unlock = [(m, h) for m, h in our_hashes.items() if h in unlock]
    hit_bought = [(m, h) for m, h in our_hashes.items() if h in bought]
    print("\n=== %s ===" % save_name)
    print("  items_unlocked=%d  items_bought=%d" % (len(unlock), len(bought)))
    print("  本 mod 道具命中解锁表: %d / %d" % (len(hit_unlock), len(our_hashes)))
    print("  本 mod 道具命中购买表: %d / %d" % (len(hit_bought), len(our_hashes)))
    if miss_unlock:
        print("  未命中示例:")
        for m, h in miss_unlock[:8]:
            print("    %-40s hash=%d" % (m, h))
    # 角色
    ch_miss = [m for n, d in our_chars for m in [str(d.get("my_id", ""))]
               if gd_hash(m) not in set(int(x) for x in s.get("characters_unlocked", []))]
    print("  本 mod 角色未在 characters_unlocked: %d / %d" % (len(ch_miss), len(our_chars)))

# ---- Toys&Balls 对照 ----
print("\n=== Toys&Balls 对照 ===")
tb_json = None
for cand in [r"D:\DSH\_aitato_work\ToysBalls_build_v4\mods-unpacked\General-Toys_Balls",
             r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"]:
    if os.path.isdir(cand):
        tb_json = cand
        break
print("Toys&Balls 解包目录:", tb_json)
if tb_json:
    tres = glob.glob(os.path.join(tb_json, "content", "items", "*", "*_item_data.tres"))
    print("content/items/*/*_item_data.tres 数量:", len(tres))
    for t in tres[:3]:
        txt = io.open(t, "r", encoding="utf-8", errors="replace").read()
        mid = None
        for line in txt.splitlines():
            line = line.strip()
            if line.startswith("my_id ="):
                mid = line.split("=", 1)[1].strip().strip('"')
                break
        print("  %-28s my_id=%s" % (os.path.basename(t), mid))
        if mid:
            print("      hash=%d" % gd_hash(mid))
