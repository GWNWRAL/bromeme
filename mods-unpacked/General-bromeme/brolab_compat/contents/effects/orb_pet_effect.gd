extends PetEffect

# =============================================================================
#  苍 / 赫 的宠物效果
#
#  伤害描述**照 Toys&Balls 的写法**（参考 items/buzz/buzz_effect.gd）：
#    1) 数值放在一个 MeleeWeaponStats 资源里（content/pets/orb/orb_weapon_stats.tres）
#       —— damage = 5，scaling_stats 用**字符串名**写：
#          [["stat_levels", 2.0], ["stat_melee_damage", 0.5],
#           ["stat_elemental_damage", 0.5], ["stat_meme", 0.5]]
#          （init_base_stats 内部走 Utils.convert_to_hash_array，会把字符串转成 hash）
#    2) get_args 里用 WeaponService 算出"当前实际伤害"和"缩放图标文本"，
#       直接返回 [伤害, 缩放文本] → 描述模板里的 {0}({1}) 由原版 Text 系统渲染
#
#  这样缩放文本自带属性小图标（等级/近战/元素/meme值），与卡皮巴拉/Toys&Balls 一致。
#
#  ⚠️ 不要用 json 的 effect_script 去 set_script()：对已实例化的 Resource 调
#     set_script 有悬空引用风险，曾引发原生访问违例崩溃。脚本一律写在 .tres 里。
# =============================================================================

export (Resource) var weapon_stats
export (bool) var pet_is_attract: bool = true


func get_args(player_index: int) -> Array:
	# 各效果的 .tres 已指到对应数值（苍 = orb_weapon_stats_cang.tres，赫 = orb_weapon_stats.tres），
	# 这里不再硬编码共用文件 —— 描述与实伤同源。
	if weapon_stats == null:
		return ["5", ""]

	var args := WeaponServiceInitStatsArgs.new()
	var current_stats = WeaponService.init_melee_pet_stats(weapon_stats, player_index, args)
	var scaling_text: String = WeaponService.get_scaling_stats_icon_text(current_stats.scaling_stats)
	return [str(current_stats.damage), scaling_text]


func serialize() -> Dictionary:
	var serialized = .serialize()
	if weapon_stats != null:
		serialized.weapon_stats = weapon_stats.serialize()
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	if serialized.has("weapon_stats"):
		var stats = MeleeWeaponStats.new()
		stats.deserialize_and_merge(serialized.weapon_stats)
		weapon_stats = stats
