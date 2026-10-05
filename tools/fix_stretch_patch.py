# -*- coding: utf-8 -*-
"""stretch 提示 v3：改用**外层容器**做拉伸，彻底不碰 _sprite.scale。

原因：这些 boss 的缩放由 AnimationPlayer 的轨道驱动（代码里把轨道 scale 键
改成了 SPRITE_SCALE），动画每帧都会重写 _sprite.scale —— 直接改它既会被覆盖，
也可能把动画的当前值留成残余。

做法：把 _sprite 包进一个 Node2D 容器（StretchPatch），拉伸只改容器的 scale，
_sprite.scale 保持完全不动（动画爱怎么写就怎么写）。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

NEW_BLOCK = '''
# -----------------------------------------------------------------------------
#  攻击前摇的"身体拉伸"提示（本 mod 通用）
#
#  关键：**不碰 _sprite.scale**。这些 boss 的缩放由 AnimationPlayer 的轨道驱动，
#  动画每帧都会重写它；直接改会被覆盖、还可能留下残余值（曾导致整只 boss 变大）。
#  这里把 _sprite 包进一个 Node2D 容器，只拉伸容器 —— 动画管不到它。
# -----------------------------------------------------------------------------
var _stretch_t: float = 0.0
var _stretch_total: float = 0.0
var _stretch_dir: Vector2 = Vector2.RIGHT
var _stretch_patch: Node2D = null          # 外层容器（只对它做拉伸）


func _stretch_patch_setup() -> void:
	if _stretch_patch != null and is_instance_valid(_stretch_patch):
		return
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var parent := _sprite.get_parent()
	if parent == null:
		return
	var idx: int = _sprite.get_index()
	_stretch_patch = Node2D.new()
	_stretch_patch.name = "StretchPatch"
	parent.add_child(_stretch_patch)
	parent.move_child(_stretch_patch, idx)
	parent.remove_child(_sprite)
	_stretch_patch.add_child(_sprite)


func _stretch_overlay_live(dir := Vector2.ZERO, duration := 0.30) -> void:
	_stretch_patch_setup()
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


# 每帧末尾调用：没有前摇时什么都不做（容器保持 scale=1，等于没加）
func _stretch_overlay_tick(delta: float) -> void:
	if _stretch_t <= 0.0:
		return
	_stretch_t = max(0.0, _stretch_t - delta)
	if _stretch_patch == null or not is_instance_valid(_stretch_patch):
		return
	var k: float = sin(PI * (1.0 - _stretch_t / _stretch_total))
	var along: float = 1.0 + 0.35 * k
	var across: float = 1.0 - 0.22 * k
	var a: float = _stretch_dir.angle()
	var sx: float = abs(cos(a)) * along + abs(sin(a)) * across
	var sy: float = abs(sin(a)) * along + abs(cos(a)) * across
	_stretch_patch.scale = Vector2(sx, sy) if _stretch_t > 0.0 else Vector2.ONE
'''


def fix(path: str) -> bool:
    s = io.open(path, encoding="utf-8").read()
    if "func _stretch_overlay_tick" not in s:
        print("   没有旧 helper")
        return False

    # 删掉旧 helper 整块（从横向注释行到 tick 函数结束）
    start = s.find("# -----------------------------------------------------------------------------\n#  攻击前摇的\"身体拉伸\"提示")
    if start < 0:
        print("   未找到 helper 起点")
        return False
    tk = s.find("func _stretch_overlay_tick", start)
    m = re.search(r'\n\n\nfunc |\nfunc (?!_stretch)[a-z_]', s[tk:])
    end = tk + (m.start() if m else len(s) - tk)
    s = s[:start] + NEW_BLOCK.strip("\n") + "\n\n\n" + s[end:].lstrip("\n")

    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    return True


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        print("%-18s %s" % (f, "已换成容器方案" if fix(p) else "未改动"))
print("完成")
