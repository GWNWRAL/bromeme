# -*- coding: utf-8 -*-
"""验证“翻译池顺序 = 按 Godot 字符串 hash 排序”，并据此定位某个中文名对应的英文 id。

Godot 3 的 String::hash() 就是 djb2：h = h*33 + c，初值 5381。
"""
import re, sys, struct

sys.path.insert(0, r"D:\DSH\_aitato_work")
from pck_tool import parse  # noqa: E402

PCK = r"D:\Apps\steam\steamapps\common\Brotato\Brotato.pck"
ZH = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.zh.translation"


def djb2(s):
    h = 5381
    for ch in s.encode("utf-8"):
        h = ((h << 5) + h) + ch
        h &= 0xFFFFFFFF
    return h


def zh_pool():
    d = open(ZH, "rb").read()
    out = []
    start = 0
    while True:
        i = d.find(b"\x00", start)
        if i < 0:
            break
        seg = d[start:i]
        start = i + 1
        if not seg:
            continue
        try:
            s = seg.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if s and all(ord(c) >= 32 for c in s) and any("\u4e00" <= c <= "\u9fff" for c in s):
            out.append(s)
    return out


def main():
    pool = zh_pool()
    pos = {s: i for i, s in enumerate(pool)}
    print("zh 含中文条目 %d" % len(pool))

    # 已知锚点：中文 -> 候选 key
    anchors = {
        "小刀": ["WEAPON_KNIFE", "weapon_knife", "ITEM_KNIFE", "Knife"],
        "扳手": ["WEAPON_WRENCH", "weapon_wrench", "ITEM_WRENCH", "Wrench"],
        "火把": ["WEAPON_TORCH", "weapon_torch"],
        "手枪": ["WEAPON_PISTOL", "weapon_pistol"],
        "冲锋枪": ["WEAPON_SMG", "weapon_smg"],
        "石头": ["WEAPON_ROCK", "weapon_rock"],
        "医生": ["DOCTOR", "doctor", "CHARACTER_DOCTOR"],
        "法师": ["MAGE", "mage", "CHARACTER_MAGE"],
    }
    for name, keys in anchors.items():
        if name not in pos:
            print("%-6s 不在池中" % name)
            continue
        idx = pos[name]
        info = ", ".join("%s=%d" % (k, djb2(k)) for k in keys)
        print("%-6s idx=%-5d  %s" % (name, idx, info))
        for k in keys:
            print("        %-22s hash=%-11d mod37=%d" % (k, djb2(k), djb2(k) % 37))


if __name__ == "__main__":
    main()
