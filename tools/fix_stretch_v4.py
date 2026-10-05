# -*- coding: utf-8 -*-
"""stretch 提示 v4：改成"记录基准 + 每帧重算"，与 mod 自己的 _scale_patched 机制一致。

为什么要这样：
  · 原版把出手前拉伸烘焙在 shoot 动画的 scale 轨里（enemy.gd 的 shoot 动画 + 结束回 idle）；
  · 这个 mod 的 boss 因为"动画资源全游戏共享、不能改"，采用了 _scale_patched：
      能改就改动画轨；改不了就**每帧重设** _sprite.scale = SPRITE_SCALE；
  · 所以拉伸必须**每帧重算**（放在 _physics_process 最后，覆盖动画与重设），
    并且以"动画/重设给出的基准值"为底，不能自己造基准。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

NEW_BLOCK = '''
# -----------------------------------------------------------------------------
#  攻击前摇的"身体拉伸"提示（本 mod 通用）
#
#  做法对齐原版（原版把拉伸烘焙在 shoot 动画的 scale 轨里，出手时播、结束回 idle）
#  与 mod 自己的 _scale_patched 机制（改不了共享动画轨就每帧重设 SPRITE_SCALE）：
#    · 攻击前记录当时的 _sprite.scale 作为基准
#    · 前摇期间每帧 _sprite.scale = 基准 × 拉伸系数（放在 _physics_process 最后，
#      覆盖动画轨和 _scale_patched 的重设）
#    · 前摇结束还原成基准
#  形态：沿线拉长、垂直压扁，且**面积守恒**（看到的是"拉长"而不是"变大"）。
# -----------------------------------------------------------------------------
var _stretch_t: float = 0.0
var _stretch_total: float = 0.0
var _stretch_dir: Vector2 = Vector2.RIGHT
var _stretch_base: Vector2 = Vector2.ONE
var _stretch_has_base: bool = false


func _stretch_overlay_live(dir := Vector2.ZERO, duration := 0.30) -> void:
	if is_instance_valid(_sprite):
		_stretch_base = _sprite.scale
		_stretch_has_base = true
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


# 每帧末尾调用：没有前摇时什么都不做（不动 _sprite.scale）
func _stretch_overlay_tick(delta: float) -> void:
	if _stretch_t <= 0.0:
		return
	if _stretch_has_base and not is_instance_valid(_sprite):
		return
	_stretch_t = max(0.0, _stretch_t - delta)
	if not _stretch_has_base or not is_instance_valid(_sprite):
		return
	if _stretch_t <= 0.0:
		# 前摇走完：还原基准
		_sprite.scale = _stretch_base
		return
	var k: float = sin(PI * (1.0 - _stretch_t / _stretch_total))
	# 面积守恒：沿线拉长多少，垂直就压扁多少
	var along: float = 1.0 + 0.18 * k
	var across: float = 1.0 / along
	var a: float = _stretch_dir.angle()
	var sx: float = abs(cos(a)) * along + abs(sin(a)) * across
	var sy: float = abs(sin(a)) * along + abs(cos(a)) * across
	_sprite.scale = Vector2(_stretch_base.x * sx, _stretch_base.y * sy)
'''


def fix(path: str) -> bool:
    s = io.open(path, encoding="utf-8").read()
    if "func _stretch_overlay_tick" not in s:
        print("   没有旧 helper")
        return False
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
        print("%-18s %s" % (f, "已改为基准×系数" if fix(p) else "未改动"))
print("完成")
