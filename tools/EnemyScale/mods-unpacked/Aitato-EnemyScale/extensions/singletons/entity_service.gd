extends "res://singletons/entity_service.gd"

# =============================================================================
# Aitato :: EnemyScale - 敌人属性的**指数级(复利)**成长
#
# 原版把敌人强度算在这些入口里:
#     res://singletons/entity_service.gd
#         get_final_enemy_health(from_value, percent_modifier) -> int
#         get_final_enemy_damage(from_value, percent_modifier) -> int
#         get_final_enemy_speed(from_value, effects_factor, percent_modifier) -> int
#
# 三者都在最后把一堆倍率(难度 / 诅咒 / 无尽 / 玩家属性...)乘到基础值上,并且把
# 中间结果缓存在 factor_cache 里;main.gd 每波开始时调用 EntityService.reset_cache()
# 清空缓存。所以:
#   * 在"最终返回值"上再乘一个因子,就等于再叠加一层全局倍率;
#   * reset_cache() 每波都跑,是读取当前波数的天然时机。
#
# 本扩展只做一件事:把最终结果乘上
#
#     第 N 波倍率 = (1 + 每波增长率) ^ N
#
# **注意这里是乘方,不是 1 + N * 增长率。**
# 复利意味着每波在前一波的基础上再涨,而不是每波加同一个固定量:
#
#     每波 +5%        第 1 波 x1.05
#                     第 2 波 x1.1025   (而不是线性的 x1.10)
#                     第 3 波 x1.157625 (而不是线性的 x1.15)
#                     第 20 波 x2.653    (线性只有 x2.00)
#                     第 40 波 x7.040    (线性只有 x3.00)
#
# 默认 5% / 5% / 0%(速度默认关闭,因为改了会明显改变手感),三个值都通过
# manifest.json 的 config_schema 暴露到游戏内 Mod Options 的滑杆上。
# =============================================================================

const ES_MOD_ID := "Aitato-EnemyScale"
const ES_LOG_NAME := "Aitato-EnemyScale"

# 超过这个波数就不再叠加,避免无限模式里数值失去意义。
const ES_MAX_SCALE_WAVE := 200

# 增长率上限,防止配置被写坏后把一局游戏变成不可玩(1.0 = 每波翻倍)。
const ES_MAX_GROWTH := 1.0

# 倍率上限。极端配置(每波 +100%)下 (1+1)^200 = 1.6e60,直接把这种浮点转成
# int 会溢出;这里封顶到一个明确、可预期的值,同时也让"配置写错"不会变成
# 未定义行为。
const ES_MAX_FACTOR := 1000000.0

const ES_DEFAULT_HP_GROWTH := 0.05
const ES_DEFAULT_DAMAGE_GROWTH := 0.05
const ES_DEFAULT_SPEED_GROWTH := 0.0


var es_hp_per_wave: float = ES_DEFAULT_HP_GROWTH
var es_damage_per_wave: float = ES_DEFAULT_DAMAGE_GROWTH
var es_speed_per_wave: float = ES_DEFAULT_SPEED_GROWTH

# 只为日志去重(见 reset_cache)。
var _es_last_log_key: String = ""


func _ready() -> void:
	es_load_config()
	# Mod Options 是另一个 autoload,延后一帧再连它的信号,确保它已经就绪。
	call_deferred("es_connect_mod_options")
	ModLoaderLog.info("config loaded: hp=%s%% damage=%s%% speed=%s%% per wave" % [
		str(round(es_hp_per_wave * 100.0)),
		str(round(es_damage_per_wave * 100.0)),
		str(round(es_speed_per_wave * 100.0))
	], ES_LOG_NAME)


# -----------------------------------------------------------------------------
# 倍率计算
# -----------------------------------------------------------------------------

# (1 + 增长率) ^ 波数  —— 复利核心。
func es_factor(growth_per_wave: float, wave: int) -> float:
	var growth: float = clamp(growth_per_wave, 0.0, ES_MAX_GROWTH)
	if growth <= 0.0:
		return 1.0

	# 波数 0(选人界面 / 商店)不放大;上限防止极端配置下溢出。
	var n: int = int(clamp(wave, 0, ES_MAX_SCALE_WAVE))
	if n <= 0:
		return 1.0

	return min(ES_MAX_FACTOR, pow(1.0 + growth, float(n)))


func es_hp_factor() -> float:
	return es_factor(es_hp_per_wave, RunData.current_wave)


func es_damage_factor() -> float:
	return es_factor(es_damage_per_wave, RunData.current_wave)


func es_speed_factor() -> float:
	return es_factor(es_speed_per_wave, RunData.current_wave)


# -----------------------------------------------------------------------------
# 应用倍率
#
# 先取原版结果,再乘本扩展的因子,最后取整 —— 与其它倍率(难度、诅咒、无尽)
# 是相乘关系,不会互相覆盖。
# -----------------------------------------------------------------------------

func get_final_enemy_health(from_value: int, percent_modifier: int = 0) -> int:
	var base: int = .get_final_enemy_health(from_value, percent_modifier)
	return round(base * es_hp_factor()) as int


func get_final_enemy_damage(from_value: float, percent_modifier: int = 0) -> int:
	var base: int = .get_final_enemy_damage(from_value, percent_modifier)
	return round(base * es_damage_factor()) as int


func get_final_enemy_speed(from_value: int, effects_factor: float, percent_modifier: int = 0) -> int:
	var base: int = .get_final_enemy_speed(from_value, effects_factor, percent_modifier)
	return round(base * es_speed_factor()) as int


# 原版每波开始时调用;顺便刷新一次配置并留一行可核对的日志。
#
# 注:扩展是被串成继承链的,链上若有别的模组也覆写了 reset_cache,本次覆写可能在
# 同一次调用里被走到两次 —— 于是这行日志会重复。下面用"波数+参数"去重,保证每波
# 只留一条记录。reset_cache() 本身是幂等的(只是清缓存),重复调用不影响数值。
func reset_cache() -> void:
	.reset_cache()
	es_load_config()

	var log_key := "%d|%.4f|%.4f|%.4f" % [
		RunData.current_wave, es_hp_per_wave, es_damage_per_wave, es_speed_per_wave
	]
	if log_key == _es_last_log_key:
		return
	_es_last_log_key = log_key

	ModLoaderLog.info("wave %d -> hp x%.4f, damage x%.4f, speed x%.4f (%s%% / %s%% / %s%% per wave, compounding)" % [
		RunData.current_wave,
		es_hp_factor(),
		es_damage_factor(),
		es_speed_factor(),
		str(round(es_hp_per_wave * 100.0)),
		str(round(es_damage_per_wave * 100.0)),
		str(round(es_speed_per_wave * 100.0))
	], ES_LOG_NAME)


# -----------------------------------------------------------------------------
# 配置(Mod Options)
#
# 走 modloader 的官方 ModLoaderConfig:manifest 里的 config_schema 负责在
# Mod Options 界面生成滑杆,dami-ModOptions 改动后发 setting_changed 信号,
# 这里即时生效并写回配置。
# -----------------------------------------------------------------------------

func es_load_config() -> void:
	var config = ModLoaderConfig.get_current_config(ES_MOD_ID)
	if config == null:
		config = ModLoaderConfig.get_default_config(ES_MOD_ID)
	if config == null:
		return

	es_hp_per_wave = float(config.data.get("hp_percent_per_wave", es_hp_per_wave))
	es_damage_per_wave = float(config.data.get("damage_percent_per_wave", es_damage_per_wave))
	es_speed_per_wave = float(config.data.get("speed_percent_per_wave", es_speed_per_wave))


func es_connect_mod_options() -> void:
	var iface = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
	if iface == null:
		return
	if not iface.is_connected("setting_changed", self, "es_on_setting_changed"):
		iface.connect("setting_changed", self, "es_on_setting_changed")


func es_on_setting_changed(setting_name: String, value, mod_name: String) -> void:
	if mod_name != ES_MOD_ID:
		return

	match setting_name:
		"hp_percent_per_wave":
			es_hp_per_wave = clamp(float(value), 0.0, ES_MAX_GROWTH)
		"damage_percent_per_wave":
			es_damage_per_wave = clamp(float(value), 0.0, ES_MAX_GROWTH)
		"speed_percent_per_wave":
			es_speed_per_wave = clamp(float(value), 0.0, ES_MAX_GROWTH)

	es_save_config()
	ModLoaderLog.info("config -> " + setting_name + " = " + str(value), ES_LOG_NAME)


func es_save_config() -> void:
	var data: Dictionary = {
		"hp_percent_per_wave": es_hp_per_wave,
		"damage_percent_per_wave": es_damage_per_wave,
		"speed_percent_per_wave": es_speed_per_wave,
	}

	var config = ModLoaderConfig.get_config(ES_MOD_ID, "current")
	if config == null:
		config = ModLoaderConfig.create_config(ES_MOD_ID, "current", data)
	else:
		config.data = data
		config = ModLoaderConfig.update_config(config)

	if config != null:
		ModLoaderConfig.set_current_config(config)
