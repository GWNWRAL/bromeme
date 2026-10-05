# -*- coding: utf-8 -*-
"""清理临时诊断代码：van 的 VAN探针 + mod_main 里的击退探针。"""
import io, os, re

VAN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\van\van.gd"
MOD_MAIN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\mod_main.gd"

# 1) van：删掉三条探针
s = io.open(VAN, encoding="utf-8").read()
before = s.count("VAN探针")
s = re.sub(r'\n[ \t]*ModLoaderLog\.info\("VAN探针[^\n]*\n(?:[ \t]*[^\n]*\n)*?[ \t]*"bromeme"\)', '', s)
s = re.sub(r'\n[ \t]*ModLoaderLog\.info\("VAN探针[^\n]*"bromeme"\)', '', s)
s = re.sub(r'\n[ \t]*elif _dash_index > 0 and _state_timer > 0\.5:\n', '\n', s)
io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
print("van: VAN探针 %d -> %d" % (before, s.count("VAN探针")))

# 2) mod_main：删掉击退探针
s2 = io.open(MOD_MAIN, encoding="utf-8").read()
b2 = s2.count("击退探针")
s2 = re.sub(r'\n[ \t]*# 临时探针（查完删除）：确认效果资源真的加载到了\n[ \t]*if base_path\.find\("lantern"\) >= 0:\n[ \t]*ModLoaderLog\.info\("击退探针[^\n]*\n', '', s2)
io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s2)
print("mod_main: 击退探针 %d -> %d" % (b2, s2.count("击退探针")))
print("完成")
