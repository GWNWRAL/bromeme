# -*- coding: utf-8 -*-
"""孙笑川二阶段改为**显式动作队列**：前摇→发射→前摇→冲刺→前摇→…

之前的问题：弹幕每 2.26s 必然重排一次前摇，而冲刺要在"弹幕间隙"排前摇，
于是在冲刺排上之前总被弹幕抢掉（或反过来把自己排无限循环）→ 永远冲不出去。

改法：二阶段不再用"定时器 + 间隙"驱动，而是用一个队列严格串联：
    _action_queue = ["letter", "dash", "letter", "dash", ...]
每完成一个动作（前摇结束、effect 生效）就取下一个 → 顺序天然正确、永不互相抢占。
"""
import io, os, shutil, time

root = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

bak = r"D:\DSH\_aitato_work\queue_backup_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
for f in FILES:
    shutil.copy2(os.path.join(root, f[:-3], f), os.path.join(bak, f))
print("备份到", bak)

# ---------- 1) 通用：出招完成后调用 _br_tell_on_fired() 钩子 ----------
HOOK_DECL = '''

# 「这一招已经打出去了」的钩子（空实现）。需要"严格串联动作"的 boss 可覆写它，
# 用来立刻排下一招（见孙笑川二阶段的动作队列）。
func _br_tell_on_fired() -> void:
	pass
'''

OLD_FIRE_TAIL = '''	if has_method(body_name):
		callv(body_name, args)
	# 前摇期间被抢的招：立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():'''
NEW_FIRE_TAIL = '''	if has_method(body_name):
		callv(body_name, args)
	_br_tell_on_fired()
	# 前摇期间被抢的招：立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():'''

for f in FILES:
    p = os.path.join(root, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    done = []
    if "_br_tell_on_fired" not in s:
        if OLD_FIRE_TAIL in s:
            s = s.replace(OLD_FIRE_TAIL, NEW_FIRE_TAIL, 1); done.append("call")
        # 插入空实现（放在 _br_tell_watchdog 之后）
        anchor = "func _br_tell_watchdog() -> void:"
        i = s.find(anchor)
        if i > 0:
            j = s.find("\n\n\n", i)
            if j < 0:
                j = s.find("\n\nfunc ", i)
            s = s[:j] + HOOK_DECL + s[j:]
            done.append("decl")
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("%-16s 钩子: %s" % (f, ",".join(done) if done else "已存在"))

# ---------- 2) 孙笑川：动作队列 ----------
SUN = os.path.join(root, "sunxiaochuan", "sunxiaochuan.gd")
s = io.open(SUN, encoding="utf-8").read()

# 2a) 二阶段定时器分支 → 只在一阶段用定时器；二阶段由队列驱动
OLD_TIMING = '''	_volley_timer += delta
	if _volley_timer >= VOLLEY_INTERVAL:
		_volley_timer = 0.0
		_fire_letter()
		if _phase2:
			# 弹幕打完，留一点间隙给冲刺
			_dash_pending = true
			_dash_timer = DASH_DELAY
			ModLoaderLog.info("SDASH 弹幕打完，%.2fs 后冲刺" % DASH_DELAY, "bromeme")

	if _dash_pending:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dash_pending = false
			_begin_dash()
	elif _dashing:
		_dash_end_timer -= delta
		if _dash_end_timer <= 0.0:
			_end_dash()'''

NEW_TIMING = '''	# 一阶段：定时器驱动弹幕
	if not _phase2:
		_volley_timer += delta
		if _volley_timer >= VOLLEY_INTERVAL:
			_volley_timer = 0.0
			_fire_letter()
		return

	# 二阶段：由动作队列严格串联（前摇→发射→前摇→冲刺→前摇→…）
	if _dashing:
		_dash_end_timer -= delta
		if _dash_end_timer <= 0.0:
			_end_dash()
		return
	if _dash_gap > 0.0:
		# 冲刺后的一点点收招间隙，然后接下一轮
		_dash_gap -= delta
		if _dash_gap <= 0.0:
			_begin_dash()
		return
	if not _acting and _action_queue.empty():
		_action_queue.append("letter")
		_action_queue.append("dash")
	if not _acting and not _action_queue.empty():
		_start_next_action()'''

if OLD_TIMING in s:
    s = s.replace(OLD_TIMING, NEW_TIMING, 1)
    print("孙笑川：二阶段改为队列驱动")
else:
    print("!! 孙笑川定时器分支未匹配")

# 2b) 队列与动作函数（插在 _enter_phase2 之前）
QUEUE_CODE = '''
# =============================================================================
#  二阶段动作队列：严格串联"前摇 → 发射"与"前摇 → 冲刺"
#
#  为什么需要它：弹幕每 2.26s 必然重排一次前摇，而冲刺只能在前摇间隙排，
#  于是冲刺总被弹幕抢掉（或被自己的补位逻辑锁住）→ 永远冲不出去。
#  改成队列后每完成一个动作才取下一个，顺序天然正确。
# =============================================================================
const DASH_GAP: float = 0.35

var _action_queue: Array = []
var _acting: bool = false
var _dash_gap: float = 0.0


func _start_next_action() -> void:
	if _action_queue.empty():
		return
	var act: String = String(_action_queue.pop_front())
	_acting = true
	ModLoaderLog.info("SDASH 队列动作：%s（剩余=%d）" % [act, _action_queue.size()], "bromeme")
	if act == "dash":
		_br_tell_arm("_br_tell_body__begin_dash", [])
	else:
		_br_tell_arm("_br_tell_body__fire_letter", [])


# 前摇结束、这一招已打出去 → 立刻排下一个动作
func _br_tell_on_fired() -> void:
	if not _acting:
		return
	if _dashing:
		# 冲刺类：等 _end_dash 处理，不在这里排下一个
		return
	_acting = false
	if _phase2 and not _action_queue.empty():
		_start_next_action()
'''

i = s.find("func _enter_phase2() -> void:")
if i > 0 and "_action_queue" not in s:
    s = s[:i] + QUEUE_CODE.strip("\n") + "\n\n\n" + s[i:]
    print("孙笑川：队列代码已插入")
else:
    print("!! 孙笑川队列未插入（可能已存在）")

# 2c) _enter_phase2 里初始化队列
OLD_ENTER = '''	ModLoaderLog.info("孙笑川进入二阶段：弹幕间隙会冲刺", "bromeme")'''
NEW_ENTER = '''	_action_queue = ["letter", "dash"]
	_acting = false
	_dash_gap = 0.0
	ModLoaderLog.info("孙笑川进入二阶段：动作队列驱动（弹幕/冲刺交替）", "bromeme")'''
if OLD_ENTER in s:
    s = s.replace(OLD_ENTER, NEW_ENTER, 1)
    print("孙笑川：_enter_phase2 初始化队列")

# 2d) _end_dash 里：接下一轮（先间隙再冲刺）
OLD_END = '''func _end_dash() -> void:
	_dashing = false
	_current_attack_behavior = _letter_behavior'''
NEW_END = '''func _end_dash() -> void:
	_dashing = false
	_acting = false
	_current_attack_behavior = _letter_behavior
	# 冲刺结束 → 排队先打一轮弹幕，再冲刺
	if _phase2:
		_action_queue.append("letter")
		_action_queue.append("dash")
		_dash_gap = DASH_GAP'''
if OLD_END in s:
    s = s.replace(OLD_END, NEW_END, 1)
    print("孙笑川：_end_dash 已接续队列")

# 2e) 重生清空队列
OLD_RESET = '''func _reset_meme_state() -> void:
	_br_tell_pending = []
	_br_tell_deferred = []'''
NEW_RESET = OLD_RESET + '''
	_action_queue = []
	_acting = false
	_dash_gap = 0.0'''
if OLD_RESET in s:
    s = s.replace(OLD_RESET, NEW_RESET, 1)
    print("孙笑川：重生清空队列")

io.open(SUN, "w", encoding="utf-8", newline="\n").write(s)
print("完成")
