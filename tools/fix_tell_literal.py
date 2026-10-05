# -*- coding: utf-8 -*-
"""把 _play_attack_tell 里的 shoot_animation_name 换成字面量 "shoot"。

原因：`shoot_animation_name` 是 enemy.gd 上的成员，而各 boss 的脚本里
（在静态检查的环境下）解析期看不到基类成员；"shoot" 就是原版默认值，直接用更稳。
"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"

OLD = '''	var anim: String = shoot_animation_name
	if anim == "":
		anim = "shoot"
	player.play(anim)'''
NEW = '''	# 原版 enemy.gd 的 shoot_animation_name 默认就是 "shoot"
	player.play("shoot")'''

for name in ("hun5", "panren", "sunxiaochuan", "van", "wangyuan"):
    p = os.path.join(ROOT, name, name + ".gd")
    s = io.open(p, encoding="utf-8").read()
    if OLD in s:
        s = s.replace(OLD, NEW)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("已改", name)
    else:
        print("未匹配", name)
print("完成")
