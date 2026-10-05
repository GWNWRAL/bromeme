# -*- coding: utf-8 -*-
"""修正 stretch 提示：改为"基础缩放 × 拉伸系数"。

之前的实现把 _sprite.scale 绝对设成 (1,1) 附近，抹掉了各 boss 的 SPRITE_SCALE
（0.23~1.125），导致整个 boss 变大。现在：
  · 起手时记录当时的 _sprite.scale 作为基准
  · 前摇期间 = 基准 × 拉伸系数
  · 前摇结束还原成基准
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

NEW_VARS = '''var _stretch_t: float = 0.0
var _stretch_total: float = 0.0
var _stretch_dir: Vector2 = Vector2.RIGHT
var _stretch_base: Vector2 = Vector2.ONE          # 基准缩放（起手时记录）
var _stretch_active: bool = false
'''

NEW_LIVE = '''func _stretch_overlay_live(dir := Vector2.ZERO, duration := 0.30) -> void:
	if is_instance_valid(_sprite):
		_stretch_base = _sprite.scale
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
	_stretch_active = true
'''

NEW_TICK = '''func _stretch_overlay_tick(delta: float) -> void:
	if not _stretch_active:
		return
	_stretch_t = max(0.0, _stretch_t - delta)
	# ⚠️ 必须是"_stretch_base × 系数"，不能用 (1,1) 当基准：
	#    各 boss 的 SPRITE_SCALE 是 0.23~1.125，直接设 (1,1) 会把它们放大 2~4 倍。
	var k: float = sin(PI * (1.0 - _stretch_t / _stretch_total))
	var along: float = 1.0 + 0.35 * k
	var across: float = 1.0 - 0.22 * k
	var a: float = _stretch_dir.angle()
	var sx: float = abs(cos(a)) * along + abs(sin(a)) * across
	var sy: float = abs(sin(a)) * along + abs(cos(a)) * across
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2(_stretch_base.x * sx, _stretch_base.y * sy)
	if _stretch_t <= 0.0:
		_stretch_active = false
		if is_instance_valid(_sprite):
			_sprite.scale = _stretch_base
'''


def fix(path: str) -> bool:
    s = io.open(path, encoding="utf-8").read()
    if "_stretch_overlay_tick" not in s:
        return False
    orig = s

    # 1) 变量块
    s = re.sub(
        r'var _stretch_t: float = 0\.0\nvar _stretch_total: float = 0\.0\nvar _stretch_dir: Vector2 = Vector2\.RIGHT\n',
        NEW_VARS, s)

    # 2) _stretch_overlay_live
    s = re.sub(r'func _stretch_overlay_live\(dir := Vector2\.ZERO, duration := 0\.30\) -> void:\n(?:.*\n)*?\n\n', NEW_LIVE + "\n", s)

    # 3) _stretch_overlay_tick
    s = re.sub(r'func _stretch_overlay_tick\(delta: float\) -> void:\n(?:.*\n)*?(?=\n\nfunc |\Z)', NEW_TICK + "\n", s)

    if s != orig:
        io.open(path, "w", encoding="utf-8", newline="\n").write(s)
        return True
    return False


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd"):
            continue
        p = os.path.join(dp, f)
        print("%-18s %s" % (f, "已修正" if fix(p) else "未改动"))
print("完成")
