# -*- coding: utf-8 -*-
"""在 DLC 的翻译资源里，用已知对照把中英序列对齐，从而查出某个中文名的英文名。"""
import sys

DLC_ZH = r"D:\DSH\_crash_analysis\pck_dlc\dlcs\dlc_1\translations\translations.zh.translation"
DLC_EN = r"D:\DSH\_crash_analysis\pck_dlc\dlcs\dlc_1\translations\translations.en.translation"

KNOWN = {
    "尖牙": "Sharp Tooth",
    "镰刀": "Sickle",
    "尖刺盾": "Spiky Shield",
    "利爪": "Claw",
    "骑枪": "Jousting Lance",
    "三叉戟": "Trident",
    "扳手": "Wrench",
    "小刀": "Knife",
    "长矛": "Spear",
    "螺丝刀": "Screwdriver",
    "火把": "Torch",
}


def segs(path, ascii_only):
    data = open(path, "rb").read()
    out = []
    start = 0
    while True:
        i = data.find(b"\x00", start)
        if i < 0:
            break
        seg = data[start:i]
        start = i + 1
        if not seg:
            continue
        try:
            s = seg.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if not s or any(ord(c) < 32 for c in s) or not any(c.isalpha() for c in s):
            continue
        if ascii_only and any(ord(c) > 126 for c in s):
            continue
        out.append(s)
    return out


def main():
    zh = segs(DLC_ZH, False)
    en = segs(DLC_EN, True)
    print("DLC zh segs %d / en segs %d" % (len(zh), len(en)))

    zpos = {s: i for i, s in enumerate(zh)}
    epos = {s: i for i, s in enumerate(en)}
    pairs = [(zpos[k], epos[v]) for k, v in KNOWN.items() if k in zpos and v in epos]
    print("已知对照命中 %d 组:" % len(pairs))
    for (zi, ei), (k, v) in zip(pairs, [(k, v) for k, v in KNOWN.items() if k in zpos and v in epos]):
        print("   %-8s zh_idx=%-5d %-16s en_idx=%-5d  shift=%d" % (k, zi, v, ei, zi - ei))

    if len(sys.argv) > 1:
        for q in sys.argv[1:]:
            for i, s in enumerate(zh):
                if s == q or q in s:
                    print("%-10s zh_idx=%-5d" % (s, i))


if __name__ == "__main__":
    main()
