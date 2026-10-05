# -*- coding: utf-8 -*-
"""看 main.tscn 里 UI 节点的直接子节点顺序（决定同级 Control 的绘制先后）。"""
import io, re

t = io.open(r"D:\DSH\Brotato_unpacked_1.1.15.4\main.tscn", encoding="utf-8", errors="replace").read()
idx = 0
for m in re.finditer(r'\[node name="([^"]+)"(?: type="[^"]+")? parent="([^"]*)"', t):
    name, parent = m.group(1), m.group(2)
    if parent == "UI":
        print("%2d  %s" % (idx, name))
    idx += 1
