extends Node

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


# =============================================================================
#  苍 / 赫 的效果：把「持续伤害」按
#      5 + 200%等级 + 50%meme值 + 50%近战伤害 + 50%元素伤害
#  动态算出来，作为 {0}；{1} 是缩放说明文字。
#
#  注：50%近战伤害 / 50%元素伤害 指"取该属性数值的 50%"（与原版宠物
#  scaling_stats 里 [stat, 0.5] 的含义一致）。
# =============================================================================

const BASE_DAMAGE: float = 5.0
const PER_LEVEL: float = 2.0       # 200% 等级
const PER_MEME: float = 0.5        # 50% meme值
const PER_MELEE: float = 0.5       # 50% 近战伤害
const PER_ELEMENTAL: float = 0.5   # 50% 元素伤害

const MEME_STAT: String = "stat_meme"
const MELEE_STAT: String = "stat_melee_damage"
const ELEMENTAL_STAT: String = "stat_elemental_damage"


func get_args(player_index: int) -> Array:
	var level: float = float(RunData.get_player_level(player_index))
	var meme: float = float(Utils.get_stat(Keys.generate_hash(MEME_STAT), player_index))
	var melee: float = float(Utils.get_stat(Keys.generate_hash(MELEE_STAT), player_index))
	var elemental: float = float(Utils.get_stat(Keys.generate_hash(ELEMENTAL_STAT), player_index))

	var damage: int = int(round(BASE_DAMAGE \
			+ PER_LEVEL * level \
			+ PER_MELEE * melee \
			+ PER_ELEMENTAL * elemental \
			+ PER_MEME * meme))

	var scaling_text: String = "200%%%s+50%%%s+50%%%s+50%%%s" % [
			"等级", _stat_label(MEME_STAT), _stat_label(MELEE_STAT), _stat_label(ELEMENTAL_STAT)]
	return [str(damage), scaling_text]


# 属性显示名（取不到翻译就退回属性 key）
func _stat_label(stat_key: String) -> String:
	var shown: String = String(tr(stat_key.to_upper()))
	if shown == "" or shown == stat_key.to_upper():
		return stat_key
	return shown
