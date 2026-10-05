# -*- coding: utf-8 -*-
"""核对各 boss：排前摇被拒后，是否有"一次性标志"已经置位 → 该招会永久丢失。"""
import io, os, re

root = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

for n in ("hun5", "panren", "sunxiaochuan", "van", "wangyuan"):
    p = os.path.join(root, n, n + ".gd")
    L = io.open(p, encoding="utf-8").read().split("\n")
    print("##", n)
    print("  --- 入口（arm 调用点）---")
    for i, l in enumerate(L, 1):
        if "_br_tell_arm(" in l and "func " not in l:
            m = re.search(r'_br_tell_arm\("([^"]+)"', l)
            print("    第%4d行  body=%s" % (i, m.group(1) if m else "?"))
    print("  --- body 函数体前 3 行有效语句 ---")
    for i, l in enumerate(L, 1):
        if l.startswith("func _br_tell_body_"):
            name = l.strip()[5:]
            stmts = []
            j = i
            while j < len(L) and len(stmts) < 4:
                t = L[j].strip()
                if t and not t.startswith("#") and not t.startswith("func"):
                    stmts.append(t[:60])
                j += 1
            print("     %-44s -> %s" % (name[:44], " ; ".join(stmts[:3])))
    print()
