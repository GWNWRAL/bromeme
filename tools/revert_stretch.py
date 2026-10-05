# -*- coding: utf-8 -*-
"""回滚 stretch 提示的所有插入（只删我自己加的行）。"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if not f.endswith(".gd") or f == "smoke.gd":
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        if "_stretch_overlay" not in s:
            continue
        orig = s

        # 1) 删掉我插入的调用行（整行，含缩进）
        s = re.sub(r'\n[ \t]*_stretch_overlay_live\(Vector2\.ZERO, 0\.30\)(?=\n)', '', s)

        # 2) 删掉 helper 块：从注释横幅到 _stretch_overlay_tick 函数结束
        start = s.find("# -----------------------------------------------------------------------------\n#  攻击前摇的\"身体拉伸\"提示")
        if start >= 0:
            tk = s.find("func _stretch_overlay_tick", start)
            if tk >= 0:
                # 函数体到下一个顶层 func 或文件尾
                m = re.search(r'\n(func |# ---)', s[tk:])
                end = tk + (m.start() + 1 if m else len(s) - tk)
                s = s[:start] + s[end:]

        # 3) 删掉 _physics_process 里的 tick 调用
        s = re.sub(r'\n[ \t]*_stretch_overlay_tick\(delta\)(?=\n)', '', s)

        s = re.sub(r'\n{4,}', '\n\n\n', s)
        if s != orig:
            io.open(p, "w", encoding="utf-8", newline="\n").write(s)
            print("已回滚:", f)

print("完成")
