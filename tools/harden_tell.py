# -*- coding: utf-8 -*-
"""前摇系统加固：被拒的招改为"延迟重试"，绝不丢弃。

现状问题：
  · `_br_tell_arm` 在前摇进行中会**直接拒绝**新招 → 那一招永久丢失
    （孙笑川的冲刺就是这样被弹幕抢掉；万的 `_dashing` 已提前置位，更会脱节）。
改法：
  · 被拒时记到 `_br_tell_deferred`
  · 当前前摇结束（shoot 回调）后，若仍有被拒的招，**立刻为它开下一段前摇**
  ⇒ 招可能被延后，但**永远不会丢**。
"""
import io, os, shutil, time

root = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

bak = r"D:\DSH\_aitato_work\tell_backup_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
for f in FILES:
    shutil.copy2(os.path.join(root, f[:-3], f), os.path.join(bak, f))
print("备份到", bak)

# ---- 1) 变量：加 _br_tell_deferred ----
OLD_VAR = "var _br_tell_pending: Array = []       # [body 方法名, 参数数组]"
NEW_VAR = ("var _br_tell_pending: Array = []       # [body 方法名, 参数数组]\n"
           "var _br_tell_deferred: Array = []      # 被拒而延迟重试的招")
OLD_VAR2 = "var _br_tell_pending: Array = []"
assert OLD_VAR2

# ---- 2) 拒绝分支：改为记入延迟队列 ----
OLD_REJECT = '''	if not _br_tell_pending.empty():
		return'''
NEW_REJECT = '''	if not _br_tell_pending.empty():
		# 前摇进行中：不丢弃，记下来等当前前摇结束后立刻补上（避免"某一招被吞"）
		_br_tell_deferred = [body_name, args]
		return'''

# ---- 3) shoot 回调：执行挂起后，若还有延迟的招就立刻为它开前摇 ----
OLD_SHOOT = '''	_br_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)'''
NEW_SHOOT = '''	_br_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)
	# 前摇期间被拒的招：现在立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():
		var d_name: String = String(_br_tell_deferred[0])
		var d_args: Array = _br_tell_deferred[1]
		_br_tell_deferred = []
		_br_tell_arm(d_name, d_args)'''

for f in FILES:
    p = os.path.join(root, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    n = 0
    if OLD_VAR2 in s and "_br_tell_deferred" not in s:
        s = s.replace(OLD_VAR2, NEW_VAR.replace("var _br_tell_pending: Array = []", OLD_VAR2), 1)
        n += 1
    if OLD_REJECT in s:
        s = s.replace(OLD_REJECT, NEW_REJECT, 1)
        n += 1
    if OLD_SHOOT in s:
        s = s.replace(OLD_SHOOT, NEW_SHOOT, 1)
        n += 1
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("%-16s 改动 %d/3" % (f, n))
print("完成")
