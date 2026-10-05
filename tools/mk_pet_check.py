# -*- coding: utf-8 -*-
"""把 mod 里的扩展脚本拷成 stub 版，供 gdcheck 项目做语法检查。"""
import io, os

SRC = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\extensions\pet_bonk_dog.gd"
DST = r"D:\DSH\_aitato_work\gdcheck_bromeme\meme\pet_bonk_dog_check.gd"

text = io.open(SRC, encoding="utf-8").read()
old = 'extends "res://entities/units/pet/bonk_dog/bonk_dog.gd"'
new = 'extends "res://stubs/pet_bonk_dog_stub.gd"'
assert old in text, "找不到 extends 行"
text = text.replace(old, new)
os.makedirs(os.path.dirname(DST), exist_ok=True)
io.open(DST, "w", encoding="utf-8", newline="\n").write(text)
print("写入", DST)
