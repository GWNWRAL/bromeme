# -*- coding: utf-8 -*-
"""按原版机制重写：出招前摇 = 播原版 1 秒的 `shoot` 动画，0.8 秒处由动画的
method 轨调用 boss 自己的 `shoot()`，此时才真正出招。

原版证据（res://entities/units/enemies/attack_behaviors/shoot.tres）：
  · Animation:position  (0,-20)->(0,-32)->(0,-18)->(0,-24)   蓄力上下
  · Animation:scale     (1.1,0.9)->(0.8,1.2)->(1.2,0.8)->(1,1) 拉伸压扁
  · Animation/Sprite:self_modulate  0.6s 变红（预警）
  · method 轨 path="." : t=0 -> start_shoot()   t=0.8 -> shoot()
即：动画自己回调 boss 的 start_shoot()/shoot()。

我们的 boss 缺这两个方法 ⇒ 动画播了也没出手；而我们的出招代码是直接 spawn，
从不播动画 ⇒ 表现为"同时触发"。本次按原版补齐：

  入口(原函数) = _br_tell_arm("<body函数名>", [参数...])  → 播 shoot + 记住要出的招
  start_shoot() = 空（占位，原版在此时机做前摇收尾）
  shoot()       = 由动画在 0.8s 回调 → callv(记住的 body) → 原出招逻辑
  _br_tell_body_<名字> = 原来入口的函数体

注意：**完全不碰 scale**（动画自己会拉伸 Animation:scale，那只是位置/缩放轨，
是原版设计；_sprite.scale 由各 boss 的 SPRITE_SCALE 机制管理，两者互不干扰）。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

ENTRIES = {
    "hun5.gd":         ["_start_melee_attack", "_fire_random_group"],
    "panren.gd":       ["_start_next_action"],
    "sunxiaochuan.gd": ["_fire_letter", "_begin_dash"],
    "van.gd":          ["_fire_cooldown_fan", "_fire_arrow_volley", "_start_dash"],
    "wangyuan.gd":     ["_fire_all_smokes"],
}

HELPER = '''
# =============================================================================
#  出招前摇（对齐原版 enemy.gd / shoot.tres）
#
#  原版：play("shoot") → 动画 1 秒，method 轨在 t=0 调 start_shoot()、t=0.8 调 shoot()
#        → boss.shoot() → 攻击行为真正发射。所以"0.8 秒前摇"是动画自带的。
#  这里照抄：入口只 arm（播动画 + 记住这一招），shoot() 被动画回调时才执行。
# =============================================================================
const BR_TELL_ANIM: String = "shoot"

var _br_tell_pending: Array = []       # [body 方法名, 参数数组]


# 入口调用：播 shoot 并记住要出的招
func _br_tell_arm(body_name: String, args: Array = []) -> void:
	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)


# 原版在 t=0 由动画 method 轨调用（这里不需要额外动作，留作占位/兼容）
func start_shoot() -> void:
	pass


# 原版在 t=0.8 由动画 method 轨调用 → 这里真正出招
func shoot() -> void:
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)
'''


def insert_helper(s: str) -> str:
    if "func _br_tell_arm" in s:
        return s
    m = re.search(r'^func ', s, re.M)
    if not m:
        return s
    return s[:m.start()] + HELPER.strip("\n") + "\n\n\n" + s[m.start():]


def convert_entry(s: str, entry: str) -> str:
    """把入口函数改为 arm + 把原函数体搬到 _br_tell_body_<entry>。"""
    m = re.search(r'^func %s\(([^)]*)\)\s*->\s*void:\n' % re.escape(entry), s, re.M)
    if not m:
        print("   !! 未找到入口:", entry)
        return s
    params_raw = m.group(1).strip()
    argnames = []
    if params_raw:
        for part in params_raw.split(","):
            part = part.strip()
            if part:
                argnames.append(part.split(":")[0].split("=")[0].strip())
    args_src = ", ".join(argnames)
    body_name = "_br_tell_body_" + entry

    rest = s[m.end():]
    nxt = re.search(r'\nfunc ', rest)
    body_end = m.end() + (nxt.start() if nxt else len(rest))
    body = s[m.end():body_end]

    replacement = (
        'func %s(%s) -> void:\n'
        '\t_br_tell_arm("%s", [%s])\n'
        '\n\n'
        'func %s(%s) -> void:\n'
        '%s'
    ) % (entry, params_raw, body_name, args_src, body_name, params_raw, body)
    return s[:m.start()] + replacement + s[body_end:]


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in ENTRIES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        s = insert_helper(s)
        n = 0
        for entry in ENTRIES[f]:
            before = s
            s = convert_entry(s, entry)
            if s != before:
                n += 1
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s 改造入口 %d/%d" % (f, n, len(ENTRIES[f])))
print("完成")
