# -*- coding: utf-8 -*-
"""orbcheck：用文本替换法给苍/赫脚本做解析检查（不依赖 autoload）。"""
import io, os, re

ROOT = r"D:\DSH\_aitato_work\orbcheck"
MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"

PRELUDE = '''extends Node

class _StubDamageArgs:
	var from_player_index: int = 0
	var from = null
	func _init(_i: int = 0, _h = null) -> void:
		from_player_index = _i

class _StubKeys:
	var empty_hash: int = 0
	func generate_hash(_s: String) -> int: return 0

class _StubRunData:
	var players_data = []
	func get_player_level(_i: int) -> int: return 1
	func get_player_count() -> int: return 1

class _StubUtils:
	func get_stat(_h: int, _i: int) -> float: return 0.0

var Keys = _StubKeys.new()
var RunData = _StubRunData.new()
var Utils = _StubUtils.new()
var TakeDamageArgs = _StubDamageArgs

'''


def make_check(src_path: str, dst_name: str, add_prelude: bool = True, extra_fix=None) -> None:
    src = io.open(src_path, encoding="utf-8").read()
    # 去掉 extends，改成自包含脚本
    src = re.sub(r'^extends [^\n]*\n', '', src, count=1)
    if extra_fix:
        src = extra_fix(src)
    body = PRELUDE + src if add_prelude else src
    io.open(os.path.join(ROOT, dst_name), "w", encoding="utf-8", newline="\n").write(body)


# orb_pet_effect.gd：需要 tr/Keys/RunData/Utils
make_check(os.path.join(MOD, r"brolab_compat\contents\effects\orb_pet_effect.gd"),
           "orb_effect_check.gd")

# bromeme_orbs.gd：额外需要 Image/ImageTexture（引擎自带）、take_damage（走动态调用）
make_check(os.path.join(MOD, r"meme\orbs\bromeme_orbs.gd"),
           "orbs_check.gd")

print("orbcheck 检查脚本已生成（文本替换法）")
