# -*- coding: utf-8 -*-
"""出招前摇改为两段式：先播完 shoot 动画，再执行这一招（对齐原版）。

入口函数体开头插入：
    if not _play_attack_tell_end():
        return
    _play_attack_tell_begin("<本函数名>", [<本函数的参数名...>])
原版机制（shooting_attack_behavior.gd:78-81 + enemy.gd:325）：
    play("shoot"); emit_signal("shot") → 动画结束才真正出招。
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

# 每个 boss 的出招入口（守卫插在函数体第一行）
ENTRIES = {
    "hun5.gd":         ["_start_melee_attack", "_fire_random_group"],
    "panren.gd":       ["_start_next_action"],
    "sunxiaochuan.gd": ["_fire_letter", "_begin_dash"],
    "van.gd":          ["_fire_cooldown_fan", "_fire_arrow_volley", "_start_dash"],
    "wangyuan.gd":     ["_fire_all_smokes"],
}

HELPER = '''
# -----------------------------------------------------------------------------
#  出招前摇：先播完 `shoot` 动画，再执行这一招（对齐原版两段式）
#
#  原版 shooting_attack_behavior 是 play("shoot") 之后由 animation_finished
#  才真正出招，所以这里有 begin/end 两段：
#     入口第一帧：end() 为真 → begin() 播 shoot + 把本招挂起，然后 return
#     后续每帧  ：shoot 还在播 → 继续挂起；播完 → end() 为真并 call 挂起的那一招
#  完全不碰 scale（拉伸会与动画轨打架 → 体型突变）。
# -----------------------------------------------------------------------------
const BROMEME_TELL_ANIM: String = "shoot"
const BROMEME_TELL_SPEED: float = 1.6      # 播快一点，前摇别太长

var _tell_pending: Array = []              # [目标方法名, 参数数组]


func _play_attack_tell_begin(target: String, args: Array = []) -> void:
	_tell_pending = [target, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	player.playback_speed = BROMEME_TELL_SPEED
	player.play(BROMEME_TELL_ANIM)


# true = 可以继续（没有挂起的招，或刚把挂起的招放出去）
func _play_attack_tell_end() -> bool:
	if _tell_pending.empty():
		return true
	var player = get_node_or_null("AnimationPlayer")
	if player != null and player.current_animation == BROMEME_TELL_ANIM and player.is_playing():
		return false
	var target: String = String(_tell_pending[0])
	var args: Array = _tell_pending[1]
	_tell_pending = []
	if has_method(target):
		callv(target, args)
	return false
'''


def strip_old_tell(s: str) -> str:
    s = re.sub(r'\n[ \t]*_play_attack_tell\(\)', '', s)
    s = re.sub(
        r'\n# 出招提示：播原版 `shoot` 动画（孙笑川冲刺前摇就是它）。\n'
        r'# 动画播完由 enemy\.gd 自动回 idle。\*\*不碰 scale\*\* —— 拉伸会与动画轨打架、导致体型突变。\n'
        r'func _play_attack_tell\(\) -> void:\n(?:.*\n)*?\n\n', '\n\n', s)
    return s


def insert_helper(s: str) -> str:
    if "func _play_attack_tell_begin" in s:
        return s
    m = re.search(r'^func ', s, re.M)
    if not m:
        return s
    return s[:m.start()] + HELPER.strip("\n") + "\n\n\n" + s[m.start():]


def insert_guard(s: str, entry: str) -> str:
    m = re.search(r'^func %s\(([^)]*)\)\s*->\s*void:\n' % re.escape(entry), s, re.M)
    if not m:
        print("   !! 未找到入口:", entry)
        return s
    raw = m.group(1).strip()
    argnames = []
    if raw:
        for part in raw.split(","):
            part = part.strip()
            if not part:
                continue
            # 形如 "kind: int" / "extra_rot: float = 0.0" → 取参数名
            name = part.split(":")[0].split("=")[0].strip()
            if name:
                argnames.append(name)
    args_src = ", ".join(argnames)
    guard = (
        "\tif not _play_attack_tell_end():\n"
        "\t\treturn\n"
        '\t_play_attack_tell_begin("%s", [%s])\n' % (entry, args_src)
    )
    return s[:m.end()] + guard + s[m.end():]


for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in ENTRIES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        s = strip_old_tell(s)
        s = insert_helper(s)
        n = 0
        for entry in ENTRIES[f]:
            before = s
            s = insert_guard(s, entry)
            if s != before:
                n += 1
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s 两段式守卫: %d/%d" % (f, n, len(ENTRIES[f])))
print("完成")
