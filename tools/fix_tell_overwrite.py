# -*- coding: utf-8 -*-
"""修 `_br_tell_arm`：已有挂起的招就**拒绝**新 arm，不再互相覆盖。

之前的实现会把 _br_tell_pending 覆盖成最新那一招 —— 孙笑川这种
"弹幕(每2.26s) 与 冲刺 交替排前摇"的 boss，后一招会把前一招挤掉，
于是冲刺（或弹幕）被吞。

另外：boss 是对象池复用的，respawn 时要清掉挂起，避免复活后立刻打出上一只遗留的招。
"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

OLD = '''	# ⚠️ 去重：入口（如 van 的 DASH 分支、冷却分支）会被每帧调用。
	#    若已经在排这一招的前摇，就不要再 play() —— 重播会让动画永远停在第 0 帧。
	if not _br_tell_pending.empty() and String(_br_tell_pending[0]) == body_name:
		return'''

NEW = '''	# ⚠️ 一次只排一个前摇：
	#    · 同一招被每帧重复调用 → 直接忽略（重播会让动画永远停在第 0 帧）
	#    · **别的招**在前摇期间来抢 → 也拒绝，否则会被覆盖掉（表现为"某一招被吞"）
	#      被拒的招会在下一轮循环自然重试。
	if not _br_tell_pending.empty():
		return'''

for f in FILES:
    p = os.path.join(ROOT, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    if OLD in s:
        s = s.replace(OLD, NEW)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-14s arm 改为'拒绝覆盖'" % f)
    else:
        print("%-14s !! 未匹配" % f)

# 复位时清空挂起（各 boss 的 _reset_meme_state 里）
RESET_ANCHOR = "func _reset_meme_state() -> void:\n"
ADD = "\t_br_tell_pending = []\n"
for f in FILES:
    p = os.path.join(ROOT, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    if "_reset_meme_state" not in s:
        print("%-14s 无 _reset_meme_state，跳过" % f)
        continue
    if "_br_tell_pending = []" in s.split("func _reset_meme_state")[1][:400]:
        print("%-14s 已清空过" % f)
        continue
    i = s.find(RESET_ANCHOR)
    s = s[:i + len(RESET_ANCHOR)] + ADD + s[i + len(RESET_ANCHOR):]
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("%-14s respawn 时清空挂起" % f)
print("完成")
