# -*- coding: utf-8 -*-
"""给本 mod 的 boss 加"攻击前身体拉伸"提示（第四轮：挂在每招入口函数体内）。

规则：只插在"每招只进一次"的入口函数体第一行 ⇒ 每招恰好触发一次拉伸。
拉伸是**叠加式**的：前摇期间在 boss 自己每帧重设的 scale 之上再乘系数。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

# 每个 boss 的"每招入口"（每次出招只经过一次）
ENTRIES = {
    "hun5.gd":         ["_fire_random_group", "_begin_melee_windup"],
    "panren.gd":       ["_start_next_action"],
    "sunxiaochuan.gd": ["_fire_letter", "_begin_dash"],
    "van.gd":          ["_fire_cooldown_fan", "_fire_arrow_volley", "_start_dash"],
    "wangyuan.gd":     ["_fire_all_smokes", "_start_new_leg"],
}

HELPER = '''# -----------------------------------------------------------------------------
#  攻击前摇的"身体拉伸"提示（本 mod 通用）
#
#  叠加式：各 boss 每帧会重设 _sprite.scale，所以这里只在前摇那几帧覆盖它，
#  沿线方向拉长、垂直方向压扁（经典蓄力动作）。前摇走完自动不再干预。
#  _dir 不传则用"朝向玩家"的方向。
# -----------------------------------------------------------------------------
var _stretch_t: float = 0.0
var _stretch_total: float = 0.0
var _stretch_dir: Vector2 = Vector2.RIGHT


func _stretch_overlay_live(dir := Vector2.ZERO, duration := 0.30) -> void:
	if dir != Vector2.ZERO:
		_stretch_dir = dir
	elif is_instance_valid(current_target):
		_stretch_dir = (current_target.global_position - global_position).normalized()
	else:
		_stretch_dir = Vector2.RIGHT
	if _stretch_dir == Vector2.ZERO:
		_stretch_dir = Vector2.RIGHT
	_stretch_total = max(0.05, duration)
	_stretch_t = _stretch_total


# 每帧末尾调用：没有前摇时什么都不做
func _stretch_overlay_tick(delta: float) -> void:
	if _stretch_t <= 0.0:
		return
	_stretch_t = max(0.0, _stretch_t - delta)
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var k: float = sin(PI * (1.0 - _stretch_t / _stretch_total))
	var along: float = 1.0 + 0.35 * k
	var across: float = 1.0 - 0.22 * k
	var a: float = _stretch_dir.angle()
	var sx: float = abs(cos(a)) * along + abs(sin(a)) * across
	var sy: float = abs(sin(a)) * along + abs(cos(a)) * across
	_sprite.scale = Vector2(sx, sy)
'''


def insert_helper(s: str) -> str:
    if "func _stretch_overlay_tick" in s:
        return s
    m = re.search(r'^func ', s, re.M)
    if not m:
        return s
    return s[:m.start()] + HELPER + "\n\n" + s[m.start():]


def insert_tick(s: str) -> str:
    if "_stretch_overlay_tick(delta)" in s:
        return s
    m = re.search(r'^func _physics_process\(delta: float\) -> void:\n', s, re.M)
    if not m:
        print("   !! 无 _physics_process")
        return s
    rest = s[m.end():]
    nxt = re.search(r'\nfunc ', rest)
    end = m.end() + (nxt.start() if nxt else len(rest))
    return s[:end] + "\n\t_stretch_overlay_tick(delta)\n" + s[end:]


def insert_entry_call(s: str, fname: str) -> str:
    """在该函数体第一行插入拉伸提示。"""
    m = re.search(r'^func %s\([^\n]*\)\s*->\s*void:\n' % re.escape(fname), s, re.M)
    if not m:
        print("   !! 未找到函数:", fname)
        return s
    body = s[m.end():]
    # 函数体第一行要缩进一级
    return s[:m.end()] + "\t_stretch_overlay_live(Vector2.ZERO, 0.30)\n" + s[m.end():]


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in ENTRIES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        if not s.lstrip().startswith('extends "res://entities/units/enemies/boss/boss.gd"'):
            print("跳过（不是 boss 脚本）:", f)
            continue
        s = insert_helper(s)
        s = insert_tick(s)
        n = 0
        for fn in ENTRIES[f]:
            new = insert_entry_call(s, fn)
            if new != s:
                n += 1
            s = new
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s 入口已挂: %d/%d" % (f, n, len(ENTRIES[f])))
print("完成")
