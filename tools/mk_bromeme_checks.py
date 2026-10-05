# -*- coding: utf-8 -*-
"""给 gdcheck 项目补 stub：把 mod 里的脚本改写成 stub 基类版本，方便语法检查。"""
import io, os

PAIRS = [
    (r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\extensions\item_service_bromeme.gd",
     "res://singletons/item_service.gd", "res://stubs/item_service_stub.gd",
     r"D:\DSH\_aitato_work\gdcheck_bromeme\meme\item_service_bromeme_check.gd"),
    (r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\extensions\pet_bonk_dog.gd",
     "res://entities/units/pet/bonk_dog/bonk_dog.gd", "res://stubs/pet_bonk_dog_stub.gd",
     r"D:\DSH\_aitato_work\gdcheck_bromeme\meme\pet_bonk_dog_check.gd"),
    (r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\extensions\ui\bromeme_pick_ui.gd",
     None, None,
     r"D:\DSH\_aitato_work\gdcheck_bromeme\meme\bromeme_pick_ui_check.gd"),
]

for src, old_base, new_base, dst in PAIRS:
    text = io.open(src, encoding="utf-8").read()
    if old_base is not None:
        old = 'extends "%s"' % old_base
        assert old in text, "找不到 extends: %s" % src
        text = text.replace(old, 'extends "%s"' % new_base, 1)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    io.open(dst, "w", encoding="utf-8", newline="\n").write(text)
    print("写入", dst)
