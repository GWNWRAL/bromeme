# -*- coding: utf-8 -*-
"""orbpetcheck：给 content/pets/orb/orb_pet.gd 做解析检查。
stub 基类放独立文件（GDScript 的 extends 不能指向同文件内部类）。"""
import io, os, re

ROOT = r"D:\DSH\_aitato_work\orbpetcheck"
SRC = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\content\pets\orb\orb_pet.gd"

os.makedirs(os.path.join(ROOT, "tests"), exist_ok=True)

# 1) stub 基类（独立文件）
io.open(os.path.join(ROOT, "stub_pet.gd"), "w", encoding="utf-8", newline="\n").write(
'''extends Node2D
var player_index: int = 0
var dead: bool = false
var stats = null
func _ready() -> void: pass
func update_data(_e) -> void: pass
''')

# 2) 检查脚本：prelude（内部工具类）+ 源码（去掉 extends、换成 stub 基类）
PRELUDE = '''extends "res://stub_pet.gd"

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
	func get_scene_node(): return null

class _StubWeaponStatsArgs:
	pass

class _StubWeaponService:
	func init_melee_pet_stats(_a, _b, _c = null):
		return null

class _StubLog:
	func info(_a, _b = "") -> void: pass

var ModLoaderLog = _StubLog.new()
var WeaponServiceInitStatsArgs = _StubWeaponStatsArgs
var WeaponService = _StubWeaponService.new()
var Keys = _StubKeys.new()
var RunData = _StubRunData.new()
var Utils = _StubUtils.new()
var TakeDamageArgs = _StubDamageArgs

'''

src = io.open(SRC, encoding="utf-8").read()
src = re.sub(r'^extends Pet\n', '', src, count=1)
io.open(os.path.join(ROOT, "orb_pet_check.gd"), "w", encoding="utf-8", newline="\n").write(PRELUDE + src)

io.open(os.path.join(ROOT, "tests", "orb_pet_check.gd"), "w", encoding="utf-8", newline="\n").write(
'''extends SceneTree
func _init():
	var s = load("res://orb_pet_check.gd")
	if s == null:
		print("FAILED: orb_pet.gd")
		quit(1)
	else:
		print("OK: orb_pet.gd")
		quit(0)
''')

io.open(os.path.join(ROOT, "project.godot"), "w", encoding="utf-8", newline="\n").write(
'''[application]
config/name="orbpetcheck"
config/features=PoolStringArray("3.6")
''')

print("orbpetcheck 已生成（stub 基类独立文件）")
