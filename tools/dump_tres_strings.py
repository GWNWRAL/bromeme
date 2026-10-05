# -*- coding: utf-8 -*-
"""把二进制 .tres 里的可打印字符串抽出来，用来判断这个 effect 改的是什么。"""
import os, re, sys

D = r"D:\DSH\_crash_analysis\effects\items"


def strings(path):
    d = open(path, "rb").read()
    out = []
    for m in re.finditer(rb"[ -~]{3,}", d):
        out.append(m.group(0).decode("ascii"))
    return out


for root, _, files in os.walk(D):
    for fn in sorted(files):
        if not fn.endswith(".tres"):
            continue
        p = os.path.join(root, fn)
        toks = strings(p)
        print("== %s" % fn)
        print("   " + " | ".join(toks[:26]))
