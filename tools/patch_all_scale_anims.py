# -*- coding: utf-8 -*-
"""把每个 boss 的**所有**动画里 Sprite 的 scale 轨都钉成 SPRITE_SCALE。

原代码只处理了 ["death", "RESET"] 两条轨 ⇒ idle 等动画一播就把 _sprite.scale
拉回原始体型（1.0 附近），表现就是"boss 突然变大"。这里扩成"遍历所有动画"。
"""
import io, os

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies"
FILES = ("hun5.gd", "panren.gd", "sunxiaochuan.gd", "van.gd", "wangyuan.gd")

OLD = '	for anim_name in ["death", "RESET"]:'
NEW = '	for anim_name in player.get_animation_list():'

for dp, _, fs in os.walk(ROOT):
    for f in sorted(fs):
        if f not in FILES:
            continue
        p = os.path.join(dp, f)
        s = io.open(p, encoding="utf-8").read()
        if OLD not in s:
            print("%-18s !! 未找到锚点" % f)
            continue
        if NEW in s:
            print("%-18s 已改过" % f)
            continue
        s = s.replace(OLD, NEW, 1)
        # 补一句注释说明为什么遍历全部
        s = s.replace(
            NEW,
            "# ⚠️ 必须遍历**所有**动画：只改 death/RESET 的话，idle 等动画的 scale 轨\n"
            "\t# 仍是原始体型，一播就把 _sprite.scale 拉回去（表现为 boss 突然变大）。\n" + NEW,
            1)
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-18s 已改为遍历全部动画" % f)
print("完成")
