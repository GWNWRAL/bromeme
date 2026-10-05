# -*- coding: utf-8 -*-
"""补完 van：它的 arm/shoot 里有 VDASH 探针日志，文本与其它 boss 不同。"""
import io

VAN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\van\van.gd"
s = io.open(VAN, encoding="utf-8").read()

# B1: arm 尾部
OLD_ARM = '''	_br_tell_pending = [body_name, args]
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	ModLoaderLog.info("VDASH arm=%s 播shoot（anim=%s）" % [body_name, str(player.current_animation)], "bromeme")
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''
NEW_ARM = '''	_br_tell_pending = [body_name, args]
	_tell_watch_frames = 0
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		_br_tell_fire_pending()
		return
	ModLoaderLog.info("VDASH arm=%s 播shoot（anim=%s）" % [body_name, str(player.current_animation)], "bromeme")
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)'''

# B2: shoot 改为共用 fire_pending
OLD_SHOOT = '''func shoot() -> void:
	ModLoaderLog.info("VDASH shoot() 回调触发 pending=%s" % str(_br_tell_pending), "bromeme")
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
	if has_method(body_name):
		callv(body_name, args)
	# 前摇期间被拒的招：现在立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():
		var d_name: String = String(_br_tell_deferred[0])
		var d_args: Array = _br_tell_deferred[1]
		_br_tell_deferred = []
		_br_tell_arm(d_name, d_args)'''
NEW_SHOOT = '''func shoot() -> void:
	ModLoaderLog.info("VDASH shoot() 回调触发 pending=%s" % str(_br_tell_pending), "bromeme")
	_br_tell_fire_pending()'''

n = 0
if OLD_ARM in s:
    s = s.replace(OLD_ARM, NEW_ARM, 1); n += 1; print("B1 arm 尾部已补")
else:
    print("!! B1 未匹配")
if OLD_SHOOT in s:
    s = s.replace(OLD_SHOOT, NEW_SHOOT, 1); n += 1; print("B2 shoot 已改为共用")
else:
    print("!! B2 未匹配")

io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
print("van 补完 %d/2" % n)
