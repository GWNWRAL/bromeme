# -*- coding: utf-8 -*-
"""给 van 插桩：跟踪 冲刺状态机 + 前摇动画是否真的播完（shoot 回调是否触发）。"""
import io, os, re

VAN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\van\van.gd"
s = io.open(VAN, encoding="utf-8").read()

# 1) _start_dash 入口
s = s.replace(
    "func _start_dash() -> void:\n\tif _charge_behavior == null:\n\t\treturn",
    'func _start_dash() -> void:\n'
    '\tModLoaderLog.info("VDASH 调_start_dash idx=%d charging=%s dashing=%s" % [_dash_index, str(_charge_behavior != null), str(_dashing)], "bromeme")\n'
    "\tif _charge_behavior == null:\n\t\treturn", 1)

# 2) body
s = s.replace(
    "func _br_tell_body__start_dash() -> void:\n\tif _charge_behavior == null:\n\t\treturn",
    'func _br_tell_body__start_dash() -> void:\n'
    '\tModLoaderLog.info("VDASH body 执行（前摇结束，真正开冲）", "bromeme")\n'
    "\tif _charge_behavior == null:\n\t\treturn", 1)

# 3) _finish_dash
s = s.replace(
    "func _finish_dash() -> void:\n\t_dashing = false",
    'func _finish_dash() -> void:\n'
    '\tModLoaderLog.info("VDASH finish idx=%d" % _dash_index, "bromeme")\n'
    "\t_dashing = false", 1)

# 4) 通用 arm：记录每次 arm 与 pending
s = s.replace(
    "\t_br_tell_pending = [body_name, args]\n\tvar player = get_node_or_null(\"AnimationPlayer\")\n\tif player == null:\n\t\treturn\n\tplayer.playback_speed = 1.0\n\tplayer.play(BR_TELL_ANIM)",
    '\t_br_tell_pending = [body_name, args]\n'
    '\tvar player = get_node_or_null("AnimationPlayer")\n'
    '\tif player == null:\n\t\treturn\n'
    '\tModLoaderLog.info("VDASH arm=%s 播shoot（anim=%s）" % [body_name, str(player.current_animation)], "bromeme")\n'
    "\tplayer.playback_speed = 1.0\n\tplayer.play(BR_TELL_ANIM)", 1)

# 5) shoot 回调
s = s.replace(
    "func shoot() -> void:\n\tif _br_tell_pending.empty():\n\t\treturn",
    'func shoot() -> void:\n'
    '\tModLoaderLog.info("VDASH shoot() 回调触发 pending=%s" % str(_br_tell_pending), "bromeme")\n'
    "\tif _br_tell_pending.empty():\n\t\treturn", 1)

# 6) 每 60 帧打印一次冲刺相关状态（从 _physics_process 末尾）
s = s.replace(
    "func _physics_process(delta: float) -> void:\n\t._physics_process(delta)",
    'var _vprobe_tick: int = 0\n\n\nfunc _physics_process(delta: float) -> void:\n\t._physics_process(delta)\n'
    '\t_vprobe_tick += 1\n'
    '\tif _vprobe_tick % 60 == 0:\n'
    '\t\tvar _vp = get_node_or_null("AnimationPlayer")\n'
    '\t\tModLoaderLog.info("VDASH 状态 state=%d idx=%d dashing=%s dash_t=%0.2f st_t=%0.2f anim=%s" % [\n'
    '\t\t\t\t_state, _dash_index, str(_dashing), _dash_timer, _state_timer,\n'
    '\t\t\t\tstr(_vp.current_animation) if _vp != null else "-"], "bromeme")', 1)

io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
print("已插桩 VDASH 探针数:", s.count("VDASH"))
