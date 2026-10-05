# -*- coding: utf-8 -*-
"""在 WER 转储里找 UTF-16 字符串，确认这次闪退是不是同一个点
（player_projectile.gd 的 bounce() 调 _entity_spawner_ref.get_rand_enemy）。"""
import sys, re

path = sys.argv[1]
data = open(path, "rb").read()
print("dump: %s  %.1f MB" % (path, len(data) / 1048576.0))

# Godot 在 Windows 用 wchar_t(2 字节) 存字符串
def has_utf16(s):
    return data.find(s.encode("utf-16-le")) != -1

# ASCII 也扫一遍（有些缓冲区是 char）
def has_ascii(s):
    return data.find(s.encode("ascii")) != -1

NEEDLES = [
    "get_rand_enemy",
    "player_projectile.gd",
    "res://projectiles/player_projectile.gd",
    "_entity_spawner_ref",
    "bounce",
    "entity_spawner",
    "ItemService",
    "bounce_damage",
    "General_weapon",
    "item_brolab",
]

for n in NEEDLES:
    u = has_utf16(n)
    a = has_ascii(n)
    print("  %-46s utf16=%-5s ascii=%-5s" % (n, u, a))
