# -*- coding: utf-8 -*-
"""清掉删守卫时留下的孤立 `return`（两个 tab 缩进、且位于函数体开头）。"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        lines = io.open(p, encoding="utf-8").read().split("\n")
        # 找函数体开头（func 行之后的第一个非空非注释行）
        out = []
        i = 0
        removed = 0
        while i < len(lines):
            l = lines[i]
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            # func 行之后紧跟的孤立 return（\t\treturn）
            if l.startswith("func ") and nxt == "\t\treturn":
                out.append(l)
                i += 2
                removed += 1
                continue
            out.append(l)
            i += 1
        lines = out
        # 也清掉 "空行 + \t\treturn + 正常函数体" 这种（函数体首行是空行的情况）
        out = []
        i = 0
        while i < len(lines):
            l = lines[i]
            if l == "\t\treturn" and i + 1 < len(lines):
                # 向前找最近的非空行：若是 func 或空行块，就删
                j = i - 1
                while j >= 0 and lines[j].strip() == "":
                    j -= 1
                if j >= 0 and lines[j].startswith("func "):
                    i += 1
                    removed += 1
                    continue
            out.append(l)
            i += 1
        s = "\n".join(out)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-14s 清掉孤立 return: %d" % (f, removed))
print("完成")
