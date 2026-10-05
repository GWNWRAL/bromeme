# -*- coding: utf-8 -*-
"""van 的冲刺改为直接驱动 charging_attack_behavior（不再依赖"行为自己播动画"）。

原版冲刺链路（charging_attack_behavior.gd）：
    physics_process: _current_cd<=0 且距离在范围内 → play("shoot")
    动画 method 轨: t=0 start_shoot() → _can_move=false、mass 调整、set_target()
                    t=0.8 shoot()      → bonus_speed=charge_speed、_current_movement=方向、
                                          _unlock_move_timer.start()  ← 真正冲出去
问题：van 自己也要播前摇 shoot，而行为也会播一次 → 互相打断 → 冲刺不触发。

改法：沿用 van 原有的状态机（_dashing / _dash_timer / 三连冲），
前摇播完（我们的 shoot() 回调）后**直接**依次调用
    _charge_behavior.start_shoot()
    _charge_behavior.shoot()
由行为自己完成加速与解锁，**不再让行为的 physics_process 插手**。
"""
import io, os

VAN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\van\van.gd"
s = io.open(VAN, encoding="utf-8").read()

old = '''func _br_tell_body__start_dash() -> void:
	ModLoaderLog.info("VDASH body 执行（前摇结束，真正开冲）", "bromeme")
	if _charge_behavior == null:
		return
	# 二阶段：起冲瞬间左右 30° 各三发
	if _phase2:
		_fire_side_bullets()
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0'''

new = '''func _br_tell_body__start_dash() -> void:
	ModLoaderLog.info("VDASH body 执行（前摇结束，真正开冲）", "bromeme")
	if _charge_behavior == null:
		return
	# 二阶段：起冲瞬间左右 30° 各三发
	if _phase2:
		_fire_side_bullets()

	# 直接驱动冲刺行为（对齐原版动画回调里的 start_shoot()/shoot() 两步）。
	# 不复用它的 physics_process —— 那个会自己 play("shoot")，和我们的前摇打架。
	_charge_behavior.reset()
	_charge_behavior.start_shoot()      # _can_move=false、mass 调整、set_target()
	_charge_behavior.shoot()            # bonus_speed=charge_speed、方向、解锁计时开始
	# 冲刺期间不要让行为再自己触发一次
	_charge_behavior._current_cd = 1.0e9'''

if old in s:
    s = s.replace(old, new)
    io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
    print("van 冲刺已改为直接驱动 charging_attack_behavior")
else:
    print("!! 未匹配，检查当前 body 内容")
print("当前 VDASH 探针数:", s.count("VDASH"))
