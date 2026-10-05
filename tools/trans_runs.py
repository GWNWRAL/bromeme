# -*- coding: utf-8 -*-
"""按“可打印字符连续段”抽取翻译池，验证中英能否按顺序对齐。"""
import re, sys

BASE_ZH = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.zh.translation"
BASE_EN = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.en.translation"


def runs(path, pat, minlen=2):
    data = open(path, "rb").read()
    out = []
    for m in re.finditer(pat, data):
        s = m.group(0).decode("utf-8", "ignore")
        if len(s) >= minlen:
            out.append((m.start(), s))
    return out


def main():
    zh = runs(BASE_ZH, re.compile(rb"(?:[\xe4-\xe9][\x80-\xbf]{2}|[A-Za-z0-9 '\-\.\+%/&\(\)]){2,}"), 2)
    en = runs(BASE_EN, re.compile(rb"[A-Za-z][A-Za-z0-9 '\-\.\+%/&\(\)]{1,}"), 2)
    print("zh runs %d / en runs %d" % (len(zh), len(en)))
    print("\n-- en 前 30 --")
    for i, (o, s) in enumerate(en[:30]):
        print("%5d %8d %s" % (i, o, s))
    print("\n-- zh 前 20 --")
    for i, (o, s) in enumerate(zh[:20]):
        print("%5d %8d %s" % (i, o, s))

    zi = {s: i for i, (o, s) in enumerate(zh)}
    ei = {s: i for i, (o, s) in enumerate(en)}
    print("\n-- 已知对照 --")
    for k, v in [("小刀", "Knife"), ("扳手", "Wrench"), ("长矛", "Spear"), ("螺丝刀", "Screwdriver"),
                 ("火把", "Torch"), ("医生", "Doctor"), ("法师", "Mage"), ("剑", "Sword")]:
        a, b = zi.get(k), ei.get(v)
        print("   %-8s zh=%-6s %-14s en=%-6s shift=%s" % (k, a, v, b, (a - b) if (a is not None and b is not None) else "-"))


if __name__ == "__main__":
    main()
