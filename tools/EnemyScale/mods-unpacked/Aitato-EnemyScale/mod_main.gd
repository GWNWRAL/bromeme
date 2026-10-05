extends Node

# =============================================================================
# Aitato :: EnemyScale
#
# 敌人生命 / 伤害 / 速度每波**指数级（复利）**增长。
#
# 与常见的线性做法不同,这里用的是乘方而不是乘法相加:
#
#     第 N 波倍率 = (1 + 每波增长率) ^ N
#
#   例:每波 +5%  ->  第 1 波 x1.05,第 2 波 x1.1025,第 3 波 x1.157625 ...
#   20 波约 x2.65,40 波约 x7.04(线性做法同样设置只有 x3.0 / x5.0)
#
# 三个数值(生命 / 伤害 / 速度)通过 manifest 的 config_schema 暴露,
# 在游戏内的 Mod Options 里以滑杆配置,默认 5% / 5% / 0%。
# =============================================================================

const MOD_ID := "Aitato-EnemyScale"
const MOD_DIR := "Aitato-EnemyScale/"
const LOG_NAME := "Aitato-EnemyScale"


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)

	var dir := ModLoaderMod.get_unpacked_dir() + MOD_DIR
	ModLoaderMod.install_script_extension(dir + "extensions/singletons/entity_service.gd")
