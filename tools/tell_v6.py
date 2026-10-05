# -*- coding: utf-8 -*-
"""最终版前摇：arm/body/try 三段式。

之前的 armed 守卫把"放行"寄托在**下一次入口调用**上；但前摇期间 boss 的
状态可能已经推进（例如 van 的 _state 切换、冷却计时越过阈值），那一次调用
不再满足触发条件 ⇒ 这一招被吞掉（用户反馈"招被吞掉了"）。

现在改成**释放时直接执行**：
    {方法}_tell_arm(args)  → 播 shoot + 把 args 存起来
    {方法}_tell_body(args) → 真正出招（原方法体）
    {方法}_tell_try()      → true=前摇还没完(return) / false=刚释放(return)
释放的那一刻直接调用对应的 body，不依赖外部再调用一次。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

HELPER = '''
# -----------------------------------------------------------------------------
#  出招前摇：先播完 `shoot` 动画，再执行这一招（对齐原版两段式）
#
#  用法：把 {方法} 拆成三段
#     func {方法}_tell_arm(args...)  -> 播 shoot + 记住参数
#     func {方法}_tell_body(args...) -> 原来的方法体
#     func {方法}_tell_ready()       -> true: 前摇未结束(本帧 return)；false: 刚释放
#  释放时**直接调用 body**，不依赖外部再次调用入口 —— 避免前摇期间状态推进
#  导致这一招被吞掉。完全不碰 scale。
# -----------------------------------------------------------------------------
const BROMEME_TELL_ANIM: String = "shoot"
const BROMEME_TELL_SPEED: float = 1.7
const BROMEME_TELL_MIN_FRAMES: int = 8

var _tell_pending: Array = []        # [body 方法名, 参数数组]
var _tell_frames: int = 0


func _tell_arm(body_name: String, args: Array) -> void:
	_tell_pending = [body_name, args]
	_tell_frames = 0
	var player = get_node_or_null("AnimationPlayer")
	if player != null:
		player.playback_speed = BROMEME_TELL_SPEED
		player.play(BROMEME_TELL_ANIM)


func _tell_ready() -> bool:
	if _tell_pending.empty():
		return false
	_tell_frames += 1
	if _tell_frames < BROMEME_TELL_MIN_FRAMES:
		return true
	var player = get_node_or_null("AnimationPlayer")
	if player != null and player.current_animation == BROMEME_TELL_ANIM and player.is_playing():
		return true
	var body_name: String = String(_tell_pending[0])
	var args: Array = _tell_pending[1]
	_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)
	return false
'''


def strip_helpers(s: str) -> str:
    for marker in ("#  出招前摇：先播完 `shoot` 动画，再执行这一招（对齐原版两段式）",
                   "#  出招前摇：先播完 `shoot` 动画，再执行这一招（对齐原版）"):
        start = s.find("# -----------------------------------------------------------------------------\n" + marker)
        if start < 0:
            continue
        # 从 start 找到 helper 之后第一个真正的 boss 函数（init/_ready/_apply_boss_art）
        m = re.search(r'\n\n\n(func (?!_tell|_play_attack_tell)[a-z_]+)', s[start:])
        if not m:
            continue
        s = s[:start] + s[start + m.start() + 1:]
    return s


def fix_and_split(s: str) -> str:
    """把带 armed 守卫的入口函数拆成 arm / body / ready 三段。"""
    for m in list(re.finditer(r'^func ([a-z_]+)\(([^)]*)\)\s*->\s*void:\n\tif _play_attack_tell_armed\(\):\n\t\treturn\n',
                              s, re.M)):
        fname = m.group(1)
        params_raw = m.group(2).strip()
        entry_name = fname
        # 参数名列表
        argnames = []
        if params_raw:
            for part in params_raw.split(","):
                part = part.strip()
                if part:
                    argnames.append(part.split(":")[0].split("=")[0].strip())
        args_src = ", ".join(argnames)
        body_name = "_tell_body_" + fname

        # 该函数体范围
        rest = s[m.end():]
        nxt = re.search(r'\nfunc ', rest)
        body_end = m.end() + (nxt.start() if nxt else len(rest))
        body = s[m.end():body_end]

        replacement = (
            'func %s(%s) -> void:\n'
            '\t_tell_arm("%s", [%s])\n'
            '\n\n'
            'func %s(%s) -> void:\n'
            '%s'
        ) % (fname, params_raw, body_name, args_src, body_name, params_raw, body)

        s = s[:m.start()] + replacement + s[body_end:]

        # 在入口插入 ready 守卫（arm 之后）
        pat = re.compile(r'(func %s\([^)]*\)\s*->\s*void:\n\t_tell_arm\("[^"]*", \[[^\]]*\]\)\n)' % re.escape(fname))
        s = pat.sub(r'\1\t_tell_ready()\n\treturn\n', s, count=1)
    return s


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        s = fix_and_split(s)
        s = strip_helpers(s)
        m = re.search(r'^func ', s, re.M)
        s = s[:m.start()] + HELPER.strip("\n") + "\n\n\n" + s[m.start():]
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s arm=%d body=%d ready=%d" % (
            f, s.count("_tell_arm("), s.count("func _tell_body_"),
            s.count("_tell_ready()")))
print("完成")
