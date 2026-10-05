# -*- coding: utf-8 -*-
"""孙笑川冲刺链路插桩（对称于万的 VDASH 探针，前缀 SDASH）。"""
import io, os, shutil, time

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\sunxiaochuan"
F = os.path.join(ROOT, "sunxiaochuan.gd")

bak = r"D:\DSH\_aitato_work\sun_backup_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
shutil.copy2(F, os.path.join(bak, "sunxiaochuan.gd"))
print("备份到", bak)

s = io.open(F, encoding="utf-8").read()

# 1) arm：记录每次排前摇
s = s.replace(
    '\t_br_tell_pending = [body_name, args]\n\tvar player = get_node_or_null("AnimationPlayer")\n\tif player == null:\n\t\treturn\n\tplayer.playback_speed = 1.0\n\tplayer.play(BR_TELL_ANIM)',
    '\t_br_tell_pending = [body_name, args]\n'
    '\tvar player = get_node_or_null("AnimationPlayer")\n'
    '\tif player == null:\n\t\treturn\n'
    '\tModLoaderLog.info("SDASH arm=%s anim=%s" % [body_name, str(player.current_animation)], "bromeme")\n'
    "\tplayer.playback_speed = 1.0\n\tplayer.play(BR_TELL_ANIM)", 1)

# 2) arm 被拒（说明有别的招在演前摇）
s = s.replace(
    "\tif not _br_tell_pending.empty():\n\t\treturn",
    '\tif not _br_tell_pending.empty():\n'
    '\t\tModLoaderLog.info("SDASH arm 被拒：%s（当前挂起=%s）" % [body_name, str(_br_tell_pending[0])], "bromeme")\n'
    "\t\treturn", 1)

# 3) shoot 回调
s = s.replace(
    "func shoot() -> void:\n\tif _br_tell_pending.empty():\n\t\treturn",
    'func shoot() -> void:\n'
    '\tModLoaderLog.info("SDASH shoot() 回调 pending=%s" % str(_br_tell_pending), "bromeme")\n'
    "\tif _br_tell_pending.empty():\n\t\treturn", 1)

# 4) _begin_dash / body
s = s.replace(
    "func _begin_dash() -> void:\n\t_br_tell_arm(\"_br_tell_body__begin_dash\", [])",
    'func _begin_dash() -> void:\n'
    '\tModLoaderLog.info("SDASH 调_begin_dash phase2=%s dashing=%s charging=%s" % [_phase2, str(_dashing), str(_charge_behavior != null)], "bromeme")\n'
    '\t_br_tell_arm("_br_tell_body__begin_dash", [])', 1)
s = s.replace(
    "func _br_tell_body__begin_dash() -> void:\n\tif _charge_behavior == null:\n\t\treturn",
    'func _br_tell_body__begin_dash() -> void:\n'
    '\tModLoaderLog.info("SDASH body 执行（前摇结束，真正开冲）", "bromeme")\n'
    "\tif _charge_behavior == null:\n\t\treturn", 1)

# 5) 进入二阶段时的冲刺调度
s = s.replace(
    '\t\t\t_dash_pending = true\n\t\t\t_dash_timer = DASH_DELAY',
    '\t\t\t_dash_pending = true\n\t\t\t_dash_timer = DASH_DELAY\n'
    '\t\t\tModLoaderLog.info("SDASH 弹幕打完，%.2fs 后冲刺" % DASH_DELAY, "bromeme")', 1)

# 6) 每 60 帧状态快照
s = s.replace(
    "func _physics_process(delta: float) -> void:\n\t._physics_process(delta)",
    'var _sprobe_tick: int = 0\n\n\nfunc _physics_process(delta: float) -> void:\n\t._physics_process(delta)\n'
    '\t_sprobe_tick += 1\n'
    '\tif _sprobe_tick % 60 == 0:\n'
    '\t\tvar _vp2 = get_node_or_null("AnimationPlayer")\n'
    '\t\tModLoaderLog.info("SDASH 状态 phase2=%s dash_pending=%s dashing=%s dash_t=%0.2f end_t=%0.2f anim=%s" % [\n'
    '\t\t\t\t_phase2, _dash_pending, _dashing, _dash_timer, _dash_end_timer,\n'
    '\t\t\t\tstr(_vp2.current_animation) if _vp2 != null else "-"], "bromeme")', 1)

io.open(F, "w", encoding="utf-8", newline="\n").write(s)
print("SDASH 探针数:", s.count("SDASH"))
