# -*- coding: utf-8 -*-
"""
判断原版翻译表里到底注册了哪些 key。

游戏用的 .translation 是 PHashTranslation(二进制, key 被哈希掉, 明文 key 不存在),
所以只能自己算 Godot 3 的 String::hash 再去文件里找。

Godot 3: uint32_t String::hash() { uint32 h=5381; for each char: h = h*33 + c; }
(PHashTranslation 的 hash_table 就是这些 uint32 的数组)
"""
import os, struct, sys

GAME = r"D:\DSH\Brotato_unpacked_1.1.15.4\resources\translations\translations.en.translation"


def djb2(s):
    h = 5381
    for ch in s:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFF
    return h


def djb2_wide(s):
    """Godot 的 CharType 在 Windows 上是 4 字节, 但数值相同; 这里对每个字符按 utf-16/32 码点取值"""
    h = 5381
    for ch in s:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFF
    return h


data = open(GAME, "rb").read()
print("file      : %s (%d bytes)" % (os.path.basename(GAME), len(data)))
print("magic     : %r" % data[:4])

# 收集文件里所有 4 字节小端值与其偏移
vals = {}
for i in range(0, len(data) - 4):
    v = struct.unpack_from("<I", data, i)[0]
    vals.setdefault(v, []).append(i)

TESTS = [
    # (字符串, 期望)
    ("BONK_DOG_NAME", True),
    ("CHARACTER_MAGE", True),
    ("CHARACTER_WELL_ROUNDED", True),
    ("RANDOM", True),
    ("PET", True),
    ("ITEM", True),
    ("damage", True),
    ("stat_damage", True),
    ("BONK_DOG_BEHAVIOUR_DESCRIPTION", True),
    ("TOYS_BALLS_WEAPON_BASKETBALL", False),
    ("AITATO_EFFECT_SLEEP", False),
    ("ZZZ_THIS_KEY_DOES_NOT_EXIST_1234", False),
    ("MADEUP_CONTROL_KEY_987654", False),
]

print()
print("%-40s %-12s %-6s %s" % ("string", "djb2", "found", "offsets(前3)"))
print("-" * 90)
for s, expect in TESTS:
    h = djb2(s)
    offs = vals.get(h, [])
    print("%-40s %-12d %-6s %s" % (s, h, "YES" if offs else "no",
                                   [hex(o) for o in offs[:3]]))
