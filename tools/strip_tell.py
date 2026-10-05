# -*- coding: utf-8 -*-
"""保守剥掉 tell/stretch 相关代码：只做显式字符串定位与逐行删除，不用贪婪正则。

步骤：
  1) 删除 helper 块（从横向注释横幅到块尾标记 "func init(" 之前的空行）
  2) 逐行删除所有守卫/tell/stretch 调用行
  3) 删除 helper 的 var/const 行
"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

DROP_LINE_SUBSTR = (
    "_play_attack_tell", "_stretch_overlay", "_stretch_patch_setup",
    "_tell_arm", "_tell_ready",
)

DROP_VAR_PREFIX = (
    "var _stretch_t", "var _stretch_total", "var _stretch_dir",
    "var _stretch_base", "var _stretch_has_base", "var _stretch_patch",
    "var _tell_pending", "var _tell_frames", "var _tell_armed",
    "const BROMEME_TELL_ANIM", "const BROMEME_TELL_SPEED", "const BROMEME_TELL_MIN_FRAMES",
)


def strip_helper_block(s: str) -> str:
    """删掉从 '# ---...' 横幅开始、包含 _stretch / _tell 定义的整块。"""
    lines = s.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # 定位横幅 + 下一行是"攻击前摇/出招前摇"说明
        if line.startswith("# ----") and i + 1 < len(lines) and (
                "前摇" in lines[i + 1] or "身体拉伸" in lines[i + 1]):
            # 一直跳到块尾（下一个真正的 func，且不含 helper 名）
            j = i
            while j < len(lines):
                l = lines[j]
                if l.startswith("func "):
                    name = l[5:].split("(")[0]
                    if name not in ("_stretch_patch_setup", "_stretch_overlay_live",
                                    "_stretch_overlay_tick", "_tell_arm", "_tell_ready",
                                    "_play_attack_tell", "_play_attack_tell_armed",
                                    "_play_attack_tell_begin", "_play_attack_tell_end"):
                        break
                j += 1
            i = j
            continue
        out.append(line)
        i += 1
    return "\n".join(out)


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        before = len(s.split("\n"))

        s = strip_helper_block(s)

        lines = []
        for line in s.split("\n"):
            st = line.strip()
            if any(k in st for k in DROP_LINE_SUBSTR):
                continue
            if any(st.startswith(k) for k in DROP_VAR_PREFIX):
                continue
            lines.append(line)
        s = "\n".join(lines)

        # 收掉 3 个以上连续空行
        while "\n\n\n\n" in s:
            s = s.replace("\n\n\n\n", "\n\n\n")

        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        after = len(s.split("\n"))
        left = [l.strip()[:70] for l in s.split("\n")
                if any(k in l for k in ("_tell", "_stretch", "_play_attack_tell"))]
        print("%-14s %4d -> %4d 行  残留=%d" % (f, before, after, len(left)))
        for l in left[:5]:
            print("      ", l)
print("完成")
