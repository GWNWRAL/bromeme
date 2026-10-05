# -*- coding: utf-8 -*-
"""确认冲刺行为的两步（start_shoot / shoot）到底有没有被调用 —— 那是真正把 boss 甩出去的地方。
若这两步没跑，就是"有前摇但不冲"的直接原因。"""
import io, os, shutil, time

SUN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\sunxiaochuan\sunxiaochuan.gd"
bak = r"D:\DSH\_aitato_work\sun_probe2_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
shutil.copy2(SUN, os.path.join(bak, "sunxiaochuan.gd"))
print("备份到", bak)

s = io.open(SUN, encoding="utf-8").read()

# 在冲刺 body 里显式调用两步，并记录前后速度/位置（用于判断有没有真的位移）
OLD = '''func _br_tell_body__begin_dash() -> void:
	ModLoaderLog.info("SDASH body 执行（前摇结束，真正开冲）", "bromeme")
	if _charge_behavior == null:
		return
	_dashing = true
	_dash_end_timer = float(_charge_behavior.charge_duration) + DASH_RECOVER
	_current_attack_behavior = _charge_behavior
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0'''

NEW = '''func _br_tell_body__begin_dash() -> void:
	ModLoaderLog.info("SDASH body 执行（前摇结束，真正开冲）", "bromeme")
	if _charge_behavior == null:
		return
	_dashing = true
	_dash_end_timer = float(_charge_behavior.charge_duration) + DASH_RECOVER
	_current_attack_behavior = _charge_behavior
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0
	# 显式走原版动画回调里的两步，确保真正把 boss 甩出去
	var p0: Vector2 = global_position
	_charge_behavior.start_shoot()
	_charge_behavior.shoot()
	ModLoaderLog.info("SDASH 已调 start_shoot/shoot：bonus_speed=%.0f move_locked=%s can_move=%s _current_movement=%s pos=%s" % [
			bonus_speed, str(_move_locked), str(_can_move), str(_current_movement), str(p0)], "bromeme")'''

if OLD in s:
    s = s.replace(OLD, NEW, 1)
    print("冲刺 body 已加显式两步 + 状态探针")
else:
    print("!! 未匹配")

# 冲刺结束记录位移
OLD2 = '''func _end_dash() -> void:
	_dashing = false'''
NEW2 = '''func _end_dash() -> void:
	ModLoaderLog.info("SDASH 冲刺结束：bonus_speed=%.0f move_locked=%s 位置=%s" % [
			bonus_speed, str(_move_locked), str(global_position)], "bromeme")
	_dashing = false'''
if OLD2 in s:
    s = s.replace(OLD2, NEW2, 1)
    print("_end_dash 已加位移探针")

io.open(SUN, "w", encoding="utf-8", newline="\n").write(s)
print("SDASH 探针数:", s.count("SDASH"))
