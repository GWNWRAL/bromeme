# -*- coding: utf-8 -*-
"""前摇系统最终修正：
  A) "同一招重复调用"与"不同招被抢占"要区分开 —— 否则会自己排自己、无限循环
     （孙笑川冲刺就是这样永远轮不到 body 执行）
  B) 加看门狗：前摇帧数超上限就强制出招，堵死"动画没回调 → 永久卡住"
"""
import io, os, shutil, time

root = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

bak = r"D:\DSH\_aitato_work\tell2_backup_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
for f in FILES:
    shutil.copy2(os.path.join(root, f[:-3], f), os.path.join(bak, f))
print("备份到", bak)

# ---- A) 拒绝分支：区分同一招 / 不同招 ----
REJECT_OLD = '''	if not _br_tell_pending.empty():
		# 前摇进行中：不丢弃，记下来等当前前摇结束后立刻补上（避免"某一招被吞"）
		_br_tell_deferred = [body_name, args]
		return'''

REJECT_OLD_SUN = '''	if not _br_tell_pending.empty():
		ModLoaderLog.info("SDASH arm 被拒：%s（当前挂起=%s）" % [body_name, str(_br_tell_pending[0])], "bromeme")
		# 不丢弃：记下来，等当前前摇结束后立刻补上（否则冲刺会被弹幕抢掉而永久丢失）
		_br_tell_deferred = [body_name, args]
		return'''

REJECT_NEW = '''	if not _br_tell_pending.empty():
		if String(_br_tell_pending[0]) == body_name:
			# 同一招：只是入口被重复调用（例如每帧都成立），直接忽略
			return
		# 不同招在前摇期间来抢：不丢弃，记下来等当前前摇结束后补上
		_br_tell_deferred = [body_name, args]
		return'''

REJECT_NEW_SUN = '''	if not _br_tell_pending.empty():
		ModLoaderLog.info("SDASH arm 被拒：%s（当前挂起=%s）" % [body_name, str(_br_tell_pending[0])], "bromeme")
		if String(_br_tell_pending[0]) == body_name:
			# 同一招：入口被重复调用，直接忽略
			return
		# 不同招来抢：记下来等当前前摇结束后补上
		_br_tell_deferred = [body_name, args]
		return'''

# ---- B) 看门狗：_br_tell_arm 记帧数，shoot 回调清零，提供 _br_tell_watchdog() ----
ARM_TAIL_OLD = '''	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

ARM_TAIL_OLD_SUN = '''	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	ModLoaderLog.info("SDASH arm=%s anim=%s" % [body_name, str(player.current_animation)], "bromeme")
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

ARM_TAIL_NEW = '''	_br_tell_pending = [body_name, args]
	_tell_watch_frames = 0
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		_br_tell_fire_pending()
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

WATCHDOG = '''

# 看门狗帧数：shoot 动画 1 秒（含 0.8s 方法轨），60fps 下留足余量。
# 万一动画没播到方法轨（被打断 / 播放器异常），这里强制出招，避免永久卡住。
const BR_TELL_WATCHDOG_FRAMES: int = 120

var _tell_watch_frames: int = 0


# 每帧由 boss 的 _physics_process 调用
func _br_tell_watchdog() -> void:
	if _br_tell_pending.empty():
		return
	_tell_watch_frames += 1
	if _tell_watch_frames >= BR_TELL_WATCHDOG_FRAMES:
		_br_tell_fire_pending()


# 真正执行挂起的那一招（shoot 回调与看门狗共用）
func _br_tell_fire_pending() -> void:
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
	_tell_watch_frames = 0
	if has_method(body_name):
		callv(body_name, args)
	# 前摇期间被抢的招：立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():
		var d_name: String = String(_br_tell_deferred[0])
		var d_args: Array = _br_tell_deferred[1]
		_br_tell_deferred = []
		_br_tell_arm(d_name, d_args)
'''

SHOOT_OLD = '''func shoot() -> void:
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)
	# 前摇期间被拒的招：现在立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():
		var d_name: String = String(_br_tell_deferred[0])
		var d_args: Array = _br_tell_deferred[1]
		_br_tell_deferred = []
		_br_tell_arm(d_name, d_args)'''

SHOOT_OLD_SUN = '''func shoot() -> void:
	ModLoaderLog.info("SDASH shoot() 回调 pending=%s" % str(_br_tell_pending), "bromeme")
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
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
    done = []

    if REJECT_OLD in s:
        s = s.replace(REJECT_OLD, REJECT_NEW, 1); done.append("A")
    elif REJECT_OLD_SUN in s:
        s = s.replace(REJECT_OLD_SUN, REJECT_NEW_SUN, 1); done.append("A")

    if ARM_TAIL_OLD in s:
        s = s.replace(ARM_TAIL_OLD, ARM_TAIL_NEW, 1); done.append("B1")
    elif ARM_TAIL_OLD_SUN in s:
        s = s.replace(ARM_TAIL_OLD_SUN, ARM_TAIL_NEW, 1); done.append("B1")

    if SHOOT_OLD in s:
        s = s.replace(SHOOT_OLD, 'func shoot() -> void:\n\t_br_tell_fire_pending()', 1); done.append("B2")
    elif SHOOT_OLD_SUN in s:
        s = s.replace(SHOOT_OLD_SUN,
                      'func shoot() -> void:\n'
                      '\tModLoaderLog.info("SDASH shoot() 回调 pending=%s" % str(_br_tell_pending), "bromeme")\n'
                      '\t_br_tell_fire_pending()', 1)
        done.append("B2")

    if "_br_tell_watchdog" not in s and "func start_shoot" in s:
        i = s.find("\n# 原版在 t=0 由动画 method 轨调用")
        if i > 0:
            s = s[:i] + WATCHDOG + s[i:]
            done.append("B3")

    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("%-16s 完成: %s" % (f, ",".join(done)))

# 各 boss 的 _physics_process 里调看门狗
WATCH_CALL = "\t_br_tell_watchdog()\n"
for f in FILES:
    p = os.path.join(root, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    if "_br_tell_watchdog()" in s and s.count("_br_tell_watchdog()") > 1:
        print("%-16s 看门狗调用已存在" % f); continue
    anchor = "func _physics_process(delta: float) -> void:\n\t._physics_process(delta)\n"
    if anchor in s:
        s = s.replace(anchor, anchor + WATCH_CALL, 1)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-16s 看门狗已接入 _physics_process" % f)
    else:
        print("%-16s !! 未找到 _physics_process" % f)
print("完成")
