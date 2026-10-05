# -*- coding: utf-8 -*-
"""魂5：攻击后有 30% 概率**无后摇**直接衔接下一次攻击（下一次仍带前摇）。

后摇 = 收招后设置的 _attack_timer（IDLE 里等它倒数完才出下一招）。
所以这里按概率把它清零 → 下一帧 _update_idle 立刻挑下一招，
而下一招仍会走 _br_tell_arm（照常播 shoot 前摇）。

只清计时，不改状态机推进（_st 仍正常回 IDLE），因此不会破坏各招自身的收尾。
"""
import io, os, time, shutil

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\hun5"
HUN5 = os.path.join(ROOT, "hun5.gd")

# 备份
bak = r"D:\DSH\_aitato_work\hun5_backup_" + time.strftime("%m%d_%H%M%S")
os.makedirs(bak, exist_ok=True)
shutil.copy2(HUN5, os.path.join(bak, "hun5.gd"))
print("备份到", bak)

s = io.open(HUN5, encoding="utf-8").read()

HELPER = '''
# =============================================================================
#  攻击后 30% 概率"无后摇接招"
#
#  后摇 = 收招时设置的 _attack_timer（IDLE 里等它倒数完才出下一招）。
#  命中概率时把它清零 → 下一帧 _update_idle 立刻挑下一招；
#  下一招依旧走 _br_tell_arm（照常播 shoot 前摇），符合"有前摇、无后摇"。
#  只清计时、不动 _st，所以各招自己的收尾逻辑不受影响。
# =============================================================================
const CHAIN_ATTACK_CHANCE: float = 0.30


func _chain_next_attack() -> void:
	if randf() >= CHAIN_ATTACK_CHANCE:
		return
	_attack_timer = 0.0
	ModLoaderLog.info("魂5：无后摇接招（%.0f%% 触发）" % (CHAIN_ATTACK_CHANCE * 100.0), "bromeme")
'''

# 1) 插入 helper（放在第一个 func 之前）
if "func _chain_next_attack" not in s:
    import re
    m = re.search(r'^func ', s, re.M)
    s = s[:m.start()] + HELPER.strip("\n") + "\n\n\n" + s[m.start():]
    print("helper 已插入")

# 2) 接入各收招点
POINTS = [
    # _update_blade 收招
    ("\t\t_st = St.IDLE\n\t\t_attack_timer = _p1_delay()\n\t\tif not _phase2 and randf() < PHASE1_DASH_CHANCE:",
     "\t\t_st = St.IDLE\n\t\t_attack_timer = _p1_delay()\n\t\t_chain_next_attack()\n\t\tif not _phase2 and randf() < PHASE1_DASH_CHANCE:"),
    # _end_weapon 收招
    ("\t_st = St.IDLE\n\tif _phase2:\n\t\t_attack_timer = P2_ATTACK_INTERVAL\n\telse:\n\t\t_attack_timer = _p1_delay()\n\n\n# ---",
     "\t_st = St.IDLE\n\tif _phase2:\n\t\t_attack_timer = P2_ATTACK_INTERVAL\n\telse:\n\t\t_attack_timer = _p1_delay()\n\t_chain_next_attack()\n\n\n# ---"),
    # _update_displace 收招
    ("\t\t_st = St.IDLE\n\t\t_attack_timer = min(_attack_timer, 0.8)",
     "\t\t_st = St.IDLE\n\t\t_attack_timer = min(_attack_timer, 0.8)\n\t\t_chain_next_attack()"),
]

for old, new in POINTS:
    if old in s:
        s = s.replace(old, new, 1)
        print("  已接入一处收招点")
    else:
        print("  !! 未匹配:", old.strip().split("\n")[0][:60])

# 3) _update_dash / _end_dash_behavior 的收招点（同形两处）
dash_old = ("\t\t_st = St.IDLE\n\t\tif _phase2:\n\t\t\t_attack_timer = P2_ATTACK_INTERVAL\n\t\telse:\n\t\t\t_attack_timer = _p1_delay()")
cnt = s.count(dash_old)
if cnt > 0:
    dash_new = dash_old + "\n\t\t_chain_next_attack()"
    s = s.replace(dash_old, dash_new)
    print("  已接入 %d 处（_update_dash / _end_dash_behavior）" % cnt)
else:
    print("  !! 未匹配冲刺收招点")

io.open(HUN5, "w", encoding="utf-8", newline="\n").write(s)
print("完成，_chain_next_attack 出现次数:", s.count("_chain_next_attack()"))
