# -*- coding: utf-8 -*-
"""找出 GDScript 缩进不一致的行（简单启发式：同一函数内缩进跳变异常）。"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        lines = io.open(p, encoding="utf-8").read().split("\n")
        print("##", f)
        for i, l in enumerate(lines):
            if not l.strip():
                continue
            st = l.lstrip("\t")
            if " " in st[:1] and st[:1] == " ":
                print("   %4d [空格缩进] %r" % (i + 1, l[:90]))
            # 顶层 func 后紧跟的函数体，若某行缩进为 1 且上一非空行也是 1，忽略
        # 检查每个 func 内部是否有跨级缩进（tab 数骤降又不为 0）
        in_func = False
        prev = 0
        for i, l in enumerate(lines):
            if not l.strip():
                continue
            tabs = len(l) - len(l.lstrip("\t"))
            if l.startswith("func "):
                in_func = True
                prev = 0
                continue
            if in_func:
                if l.startswith("#"):
                    continue
                if tabs == 0:
                    in_func = False
                elif prev > 0 and tabs > prev + 1:
                    print("   %4d [缩进跳变 %d->%d] %r" % (i + 1, prev, tabs, l[:90]))
                prev = tabs
print("完成")
