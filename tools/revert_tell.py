# -*- coding: utf-8 -*-
"""彻底移除出招前摇的所有改动，恢复 boss 出招逻辑。

清掉的东西（历次迭代的残留）：
  · _play_attack_tell / _play_attack_tell_armed / _play_attack_tell_begin/end
  · _tell_arm / _tell_body_* / _tell_ready / _stretch_* 整个 helper 块
  · 入口里的各种守卫行与 tell 调用
  · 出招入口被拆成的 body 函数（合并回入口）
保留：SPRITE_SCALE 相关（_patch_scale_animations 遍历全部动画）—— 那是真实的 bug 修复。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")


def clean(s: str) -> str:
    # 1) 把 _tell_body_<name> 合并回 <name>（如果之前被拆过）
    def merge(m):
        orig = m.group(1)
        params = m.group(2)
        body_name = "_tell_body_" + orig
        # 找 body 函数块
        bm = re.search(r'^func %s\(%s\)\s*->\s*void:\n((?:\t.*\n|\n)*)' % (
            re.escape(body_name), re.escape(params)), s, re.M)
        if not bm:
            return m.group(0)
        body = bm.group(1)
        new = "func %s(%s) -> void:\n%s" % (orig, params, body)
        return new
    return s


def clean_file(path: str) -> None:
    s = io.open(path, encoding="utf-8").read()

    # A) 若被拆成 arm/body：把 body 合并回入口，并删除 arm 包装
    for m in list(re.finditer(r'func ([a-z_]+)\(([^)]*)\)\s*->\s*void:\n\t_tell_arm\("[^"]*", \[[^\]]*\]\)\n(?:\t_tell_ready\(\)\n\treturn\n)?', s)):
        fname = m.group(1)
        params = m.group(2)
        body_name = "_tell_body_" + fname
        bm = re.search(r'func %s\(%s\)\s*->\s*void:\n((?:\t.*\n|\n)*?)(?=\nfunc |\Z)' % (
            re.escape(body_name), re.escape(params)), s)
        if not bm:
            continue
        replacement = "func %s(%s) -> void:\n%s" % (fname, params, bm.group(1))
        # 先替换入口块，再删掉 body 定义块
        s = s[:m.start()] + replacement + s[m.end():]
        bm2 = re.search(r'\n*func %s\(%s\)\s*->\s*void:\n((?:\t.*\n|\n)*?)(?=\nfunc |\Z)' % (
            re.escape(body_name), re.escape(params)), s)
        if bm2:
            s = s[:bm2.start()] + "\n" + s[bm2.end():]

    # B) 删除所有守卫行 / tell 调用行
    for pat in (
        r'\n[ \t]*if not _play_attack_tell_end\(\):\n[ \t]*return\n[ \t]*_play_attack_tell_begin\("[^"]*", \[[^\]]*\]\)',
        r'\n[ \t]*if _play_attack_tell_armed\(\):\n[ \t]*return',
        r'\n[ \t]*_play_attack_tell\(\)',
        r'\n[ \t]*_play_attack_tell_begin\([^\n]*\)',
        r'\n[ \t]*_tell_arm\([^\n]*\)',
        r'\n[ \t]*_tell_ready\(\)\n[ \t]*return',
        r'\n[ \t]*_stretch_overlay_tick\(delta\)',
        r'\n[ \t]*_stretch_overlay_live\([^\n]*\)',
        r'\n[ \t]*_stretch_patch_setup\(\)',
    ):
        s = re.sub(pat, '', s)

    # C) 删除 helper 块（横向注释 + _stretch_/_tell_/_play_attack_tell 定义）
    changed = True
    while changed:
        changed = False
        m = re.search(
            r'\n# -{60,}\n#  (?:攻击前摇|出招前摇)[^\n]*\n(?:.*\n)*?'
            r'(?=\n\n\nfunc (?!_stretch|_tell|_play_attack_tell)[a-z_]|\Z)', s)
        if m:
            s = s[:m.start()] + "\n" + s[m.end():]
            changed = True
    # 兜底：逐个删掉 helper 函数定义
    for name in ("_stretch_patch_setup", "_stretch_overlay_live", "_stretch_overlay_tick",
                 "_tell_arm", "_tell_ready", "_play_attack_tell",
                 "_play_attack_tell_armed", "_play_attack_tell_begin",
                 "_play_attack_tell_end"):
        while True:
            m = re.search(r'\nfunc %s\([^)]*\)[^\n]*:\n((?:\t.*\n|\n)*?)(?=\nfunc |\n# |\Z)' % re.escape(name), s)
            if not m:
                break
            s = s[:m.start()] + "\n" + s[m.end():]

    # D) 删除 helper 的 var/const
    for pat in (
        r'\nvar _stretch_t[^\n]*', r'\nvar _stretch_total[^\n]*', r'\nvar _stretch_dir[^\n]*',
        r'\nvar _stretch_base[^\n]*', r'\nvar _stretch_has_base[^\n]*', r'\nvar _stretch_patch[^\n]*',
        r'\nvar _tell_pending[^\n]*', r'\nvar _tell_frames[^\n]*', r'\nvar _tell_armed[^\n]*',
        r'\nconst BROMEME_TELL_ANIM[^\n]*', r'\nconst BROMEME_TELL_SPEED[^\n]*',
        r'\nconst BROMEME_TELL_MIN_FRAMES[^\n]*',
    ):
        s = re.sub(pat, '', s)

    s = re.sub(r'\n{4,}', '\n\n\n', s)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        clean_file(p)
        s = io.open(p, encoding="utf-8").read()
        print("%-18s 残留 tell=%d stretch=%d body=%d 行数=%d" % (
            f, s.count("_tell"), s.count("_stretch"), s.count("_tell_body_"),
            len(s.split("\n"))))
print("完成")
