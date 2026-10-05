# -*- coding: utf-8 -*-
"""从 harness 恢复 5 个 boss 脚本（harness 副本比被删坏的工程内文件完整）。"""
import io, os, shutil

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
SRC = r"D:\DSH\_aitato_work\enemycheck"

for n in ("hun5", "panren", "sunxiaochuan", "van", "wangyuan"):
    s = os.path.join(SRC, n + "_check.gd")
    d = os.path.join(ROOT, n, n + ".gd")
    if not os.path.isfile(s):
        print("!! 缺少 harness 副本:", s)
        continue
    shutil.copy2(s, d)
    txt = io.open(d, encoding="utf-8").read()
    print("%-14s 已恢复 %4d 行  tell=%d stretch=%d" % (
        n, len(txt.split("\n")), txt.count("_tell"), txt.count("_stretch")))
print("完成")
