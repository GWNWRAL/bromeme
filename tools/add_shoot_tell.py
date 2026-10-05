# -*- coding: utf-8 -*-
"""把"出招前播 shoot 动画"推广到所有 boss（用户要求模仿孙笑川冲刺前摇）。

孙笑川二阶段的冲刺前摇 = 原版 charging_attack_behavior 播的 `shoot` 动画：
    _parent._animation_player.playback_speed = attack_anim_speed
    _parent._animation_player.play(_parent.shoot_animation_name)   # "shoot"
而 mod 自己的出招代码从不播它 ⇒ 只有孙笑川显得有前摇。

做法：在每个 boss 的出招入口调用 _play_attack_tell()：播 shoot 动画，
动画结束后原版 enemy.gd 会自动回 idle。完全不碰 scale（用户已确认拉伸会造成体型突变）。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
ENTRIES = {
    "hun5.gd":         ["_fire_random_group", "_begin_melee_windup"],
    "panren.gd":       ["_start_next_action"],
    "sunxiaochuan.gd": ["_fire_letter", "_begin_dash"],
    "van.gd":          ["_fire_cooldown_fan", "_fire_arrow_volley", "_start_dash"],
    "wangyuan.gd":     ["_fire_all_smokes", "_start_new_leg"],
}

TELL = '''
# 出招提示：播原版 `shoot` 动画（孙笑川冲刺前摇就是它）。
# 动画播完由 enemy.gd 自动回 idle。**不碰 scale** —— 拉伸会与动画轨打架、导致体型突变。
func _play_attack_tell() -> void:
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	if is_playing_shoot_animation():
		return
	player.play(shoot_animation_name)
'''


def add_tell(s: str) -> str:
    if "func _play_attack_tell" in s:
        return s
    m = re.search(r'^func ', s, re.M)
    if not m:
        return s
    return s[:m.start()] + TELL.strip("\n") + "\n\n\n" + s[m.start():]


def add_call(s: str, fname: str) -> bool:
    m = re.search(r'^func %s\([^\n]*\)\s*->\s*void:\n' % re.escape(fname), s, re.M)
    if not m:
        return False
    after = s[m.end():m.end() + 200]
    if "_play_attack_tell()" in after:
        return False
    return True, s[:m.end()] + "\t_play_attack_tell()\n" + s[m.end():]


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in ENTRIES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        if not s.lstrip().startswith('extends "res://entities/units/enemies/boss/boss.gd"'):
            continue
        s = add_tell(s)
        n = 0
        for fn in ENTRIES[f]:
            r = add_call(s, fn)
            if isinstance(r, tuple):
                s = r[1]
                n += 1
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s 出招提示已挂: %d/%d" % (f, n, len(ENTRIES[f])))
print("完成")
