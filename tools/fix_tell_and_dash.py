# -*- coding: utf-8 -*-
"""修两处：

A) 通用：`_br_tell_arm` 加"已在排前摇就不重播"的守卫。
   否则入口被每帧调用时会不停 player.play("shoot") —— 动画永远停在第 0 帧，
   看起来就是"卡住/不出招"。

B) van 的冲刺：状态机的推进必须立刻发生，不能等动画回调。
   · `_start_dash()` 里立刻置 _dashing/_dash_timer/_dash_index/_state_timer（状态机推进）
   · body 只负责"真正甩出去"（charge 行为参数 + 二阶段侧射）
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

# ---------- A) 给 _br_tell_arm 加去重守卫 ----------
OLD_ARM = '''func _br_tell_arm(body_name: String, args: Array = []) -> void:
	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

NEW_ARM = '''func _br_tell_arm(body_name: String, args: Array = []) -> void:
	# ⚠️ 去重：入口（如 van 的 DASH 分支、冷却分支）会被每帧调用。
	#    若已经在排这一招的前摇，就不要再 play() —— 重播会让动画永远停在第 0 帧。
	if not _br_tell_pending.empty() and String(_br_tell_pending[0]) == body_name:
		return
	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

for f in FILES:
    p = os.path.join(ROOT, f[:-3], f)
    s = io.open(p, encoding="utf-8").read()
    if OLD_ARM in s:
        s = s.replace(OLD_ARM, NEW_ARM)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-14s A) arm 去重已加" % f)
    else:
        print("%-14s A) !! 未匹配" % f)

# ---------- B) van 的 _start_dash / body 拆分 ----------
VAN = os.path.join(ROOT, "van", "van.gd")
s = io.open(VAN, encoding="utf-8").read()

old_van = '''func _start_dash() -> void:
	_br_tell_arm("_br_tell_body__start_dash", [])


func _br_tell_body__start_dash() -> void:
	if _charge_behavior == null:
		return

	var duration: float = LONG_DASH if _dash_index >= 2 else SHORT_DASH
	var speed: float = DASH_SPEED * (LONG_DASH_SPEED_MULT if _dash_index >= 2 else SHORT_DASH_SPEED_MULT)
	_dashing = true
	_dash_timer = duration + DASH_CHAIN_GAP
	_state_timer = 0.0
	_dash_index += 1

	# 二阶段：起冲瞬间左右 30° 各三发
	if _phase2:
		_fire_side_bullets()

	_current_attack_behavior = _charge_behavior
	_charge_behavior.charge_duration = duration
	_charge_behavior.charge_speed = speed
	if _charge_behavior._unlock_move_timer != null:
		_charge_behavior._unlock_move_timer.wait_time = duration
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0'''

new_van = '''# 冲刺：**状态机推进必须立刻发生**（否则 _dashing 不置位、_state_timer 不清零，
# DASH 分支每帧成立 → 每帧重播前摇 → 永远冲不出去）。
# 所以这里先推进状态机并预排参数，前摇动画播完（shoot 回调）再真正甩出去。
func _start_dash() -> void:
	if _charge_behavior == null:
		return

	var duration: float = LONG_DASH if _dash_index >= 2 else SHORT_DASH
	var speed: float = DASH_SPEED * (LONG_DASH_SPEED_MULT if _dash_index >= 2 else SHORT_DASH_SPEED_MULT)

	# ① 立刻推进状态机
	_dashing = true
	_dash_timer = duration + DASH_CHAIN_GAP
	_state_timer = 0.0
	_dash_index += 1
	_current_attack_behavior = _charge_behavior

	# ② 参数先配好（前摇期间就在蓄力，视觉一致）
	_charge_behavior.charge_duration = duration
	_charge_behavior.charge_speed = speed
	if _charge_behavior._unlock_move_timer != null:
		_charge_behavior._unlock_move_timer.wait_time = duration

	# ③ 排前摇；动画 0.8s 后回调 shoot() → 执行 body 真正开冲
	_br_tell_arm("_br_tell_body__start_dash", [])


func _br_tell_body__start_dash() -> void:
	if _charge_behavior == null:
		return
	# 二阶段：起冲瞬间左右 30° 各三发
	if _phase2:
		_fire_side_bullets()
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0'''

if old_van in s:
    s = s.replace(old_van, new_van)
    io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
    print("van  B) 冲刺状态机已改为立刻推进")
else:
    print("van  B) !! 未匹配")
print("完成")
