# -*- coding: utf-8 -*-
"""暴力尝试各种 key 哈希算法, 找出原版 .translation hash_table 里到底用的哪一种。"""
import struct, zlib

P = r"D:\DSH\Brotato_unpacked_1.1.15.4\resources\translations\translations.en.translation"
data = open(P, "rb").read()

KEYS = ["RANDOM_RECORD_TEXT", "WAVE", "PET", "ITEM", "CODEX_BOUGHT", "RANDOM",
        "BONK_DOG_NAME", "CHARACTER_MAGE", "CODEX_PRICE"]


def h_djb2(s, seed=5381):
    h = seed
    for c in s:
        h = ((h << 5) + h + ord(c)) & 0xFFFFFFFF
    return h


def h_djb2_xor(s, seed=5381):
    h = seed
    for c in s:
        h = (((h << 5) + h) ^ ord(c)) & 0xFFFFFFFF
    return h


def h_java(s, seed=0):
    h = seed
    for c in s:
        h = (h * 31 + ord(c)) & 0xFFFFFFFF
    return h


def h_sdbm(s, seed=0):
    h = seed
    for c in s:
        h = (ord(c) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF
    return h


def h_fnv1a(s, seed=2166136261):
    h = seed
    for c in s:
        h ^= ord(c)
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def h_fnv1(s, seed=2166136261):
    h = seed
    for c in s:
        h = (h * 16777619) & 0xFFFFFFFF
        h ^= ord(c)
    return h


def h_godot3(s, seed=5381):
    # Godot 3 String::hash(): h = (h << 5) - h + c   等价于 h*31 + c
    h = seed
    for c in s:
        h = ((h << 5) - h + ord(c)) & 0xFFFFFFFF
    return h


ALGOS = {
    "djb2_5381*33+c": h_djb2,
    "djb2_5381*33^c": h_djb2_xor,
    "godot3_5381*31+c": h_godot3,
    "java_0*31+c": h_java,
    "sdbm": h_sdbm,
    "fnv1a": h_fnv1a,
    "fnv1": h_fnv1,
}

# 文件里所有 4 字节小端值
present = set()
for i in range(0, len(data) - 4):
    present.add(struct.unpack_from("<I", data, i)[0])

print("distinct uint32 in file: %d" % len(present))
print()
for name, fn in ALGOS.items():
    hits = [k for k in KEYS if fn(k) in present]
    print("%-20s hits: %d/%d  %s" % (name, len(hits), len(KEYS), hits))
