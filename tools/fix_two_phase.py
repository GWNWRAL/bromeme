# -*- coding: utf-8 -*-
"""修正两段式前摇：
  ① 保证前摇至少持续 N 帧（动画可能同帧播完，导致当帧就出招 = "同时触发"）；
  ② 守卫改一次性置位：只排一次，之后放行让原函数体执行。
     否则原函数里的"已触发"标志（如 van 的 _fan_fired、_state 切换）永远设不上
     → 每帧重播动画、扇形放不出、冲刺卡顿。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

NEW_HELPER = '''
# -----------------------------------------------------------------------------
#  出招前摇：先播完 `shoot` 动画，再执行这一招（对齐原版两段式）
#
#  守卫用法（插在出招入口函数体第一行）：
#      if _play_attack_tell_armed():
#          return
#  语义：本招"排过一次前摇"就返回 true 并放行，之后原函数体照常执行；
#       期间 shoot 播完才真正放行（至少 min 帧，避免动画同帧播完变成"同时触发"）。
#  完全不碰 scale。
# -----------------------------------------------------------------------------
const BROMEME_TELL_ANIM: String = "shoot"
const BROMEME_TELL_SPEED: float = 1.6       # 播快一点，前摇别太长
const BROMEME_TELL_MIN_FRAMES: int = 8      # 前摇最少持续帧数

var _tell_armed: bool = false
var _tell_frames: int = 0
var _tell_pending: Array = []               # [目标方法名, 参数数组]


func _play_attack_tell_armed() -> bool:
	if not _tell_armed:
		# 排一次前摇
		_tell_armed = true
		_tell_frames = 0
		var player = get_node_or_null("AnimationPlayer")
		if player != null:
			player.playback_speed = BROMEME_TELL_SPEED
			player.play(BROMEME_TELL_ANIM)
		return true

	# 前摇进行中：等动画播完（且至少 min 帧）
	_tell_frames += 1
	var player2 = get_node_or_null("AnimationPlayer")
	if _tell_frames < BROMEME_TELL_MIN_FRAMES:
		return true
	if player2 != null and player2.current_animation == BROMEME_TELL_ANIM and player2.is_playing():
		return true
	# 前摇结束 → 放行，让原函数体正常执行（包括它自己的"已触发"标志位）
	_tell_armed = false
	return false


# 给需要延后整段执行的场景用（当前未使用，保留）
func _play_attack_tell_begin(target: String, args: Array = []) -> void:
	_tell_pending = [target, args]


func _play_attack_tell_end() -> bool:
	if _tell_pending.empty():
		return true
	var target: String = String(_tell_pending[0])
	var args: Array = _tell_pending[1]
	_tell_pending = []
	if has_method(target):
		callv(target, args)
	return false
'''


def strip_tell_helper(s: str) -> str:
    start = s.find("# -----------------------------------------------------------------------------\n#  出招前摇：先播完 `shoot` 动画")
    if start < 0:
        return s
    end = s.find("func _play_attack_tell_end", start)
    if end < 0:
        return s
    m = re.search(r'\n\n\nfunc |\nfunc (?!_play_attack_tell)[a-z_]', s[end:])
    end2 = end + (m.start() if m else len(s) - end)
    return s[:start] + s[end2:].lstrip("\n")


def fix_guards(s: str) -> str:
    # 把三行守卫换成一行 armed 守卫
    pat = re.compile(
        r'\n[ \t]*if not _play_attack_tell_end\(\):\n'
        r'[ \t]*return\n'
        r'[ \t]*_play_attack_tell_begin\("[^"]*", \[[^\]]*\]\)\n')
    return pat.sub('\n\tif _play_attack_tell_armed():\n\t\treturn\n', s)


def insert_helper(s: str) -> str:
    if "func _play_attack_tell_armed" in s:
        return s
    m = re.search(r'^func ', s, re.M)
    if not m:
        return s
    return s[:m.start()] + NEW_HELPER.strip("\n") + "\n\n\n" + s[m.start():]


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        s = fix_guards(s)
        s = strip_tell_helper(s)
        s = insert_helper(s)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s armed守卫=%d" % (f, s.count("if _play_attack_tell_armed()")))
print("完成")
