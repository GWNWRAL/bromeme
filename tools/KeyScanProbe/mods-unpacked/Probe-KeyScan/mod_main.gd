extends Node

# 一次性验证：炮塔重做后的效果列表 / 文案，以及原版灯笼光环是否真的在游戏里注册着。

const LOG := "TurretProbe"
const CHAR_ID := "character_brolab_pt_431"

const KEYS := [
	"EFFECT_KNOCKBACK_AURA",
	"EFFECT_KNOCKBACK_AURA_PLURAL",
	"EFFECT_KNOCKBACK",
	"EFFECT_INSTANT_GOLD_ATTRACTING",
	"EFFECT_INCREASE_STAT_GAINS",
	"STAT_DAMAGE",
	"STAT_PERCENT_DAMAGE",
	"STAT_ATTACK_SPEED",
]


func _ready() -> void:
	yield(get_tree().create_timer(45), "timeout")
	_run()


func _run() -> void:
	ModLoaderLog.info("=== turret probe start ===", LOG)

	for k in KEYS:
		ModLoaderLog.info("tr(%-32s) = '%s'" % [k, str(tr(k))], LOG)

	if ProgressData != null:
		ModLoaderLog.info("DLC abyssal_terrors active = %s"
				% str(ProgressData.is_dlc_available_and_active("abyssal_terrors")), LOG)

	var behaviors = EffectBehaviorService.player_effect_behaviors if EffectBehaviorService != null else null
	if behaviors == null:
		ModLoaderLog.info("EffectBehaviorService / player_effect_behaviors 不可用", LOG)
	else:
		var paths: Array = []
		for data in behaviors:
			if data == null:
				continue
			var scene = data.get("scene")
			var path := ""
			if scene != null:
				path = str(scene.resource_path)
			paths.append(path.get_file())
		ModLoaderLog.info("player_effect_behaviors(%d): %s" % [paths.size(), str(paths)], LOG)

	var isvc = get_node_or_null("/root/ItemService")
	if isvc == null:
		ModLoaderLog.info("ItemService missing", LOG)
		return

	var found = null
	for c in isvc.get("characters"):
		if c != null and is_instance_valid(c) and str(c.get("my_id")) == CHAR_ID:
			found = c
			break

	if found == null:
		ModLoaderLog.info("找不到角色 " + CHAR_ID, LOG)
		return

	ModLoaderLog.info("角色: %s | 名字='%s' | 效果数=%d" % [CHAR_ID, str(found.get("name")), found.effects.size()], LOG)
	for i in found.effects.size():
		var e = found.effects[i]
		if e == null:
			ModLoaderLog.info("  [%d] <null>" % i, LOG)
			continue
		ModLoaderLog.info("  [%d] key='%s' custom_key='%s' value=%s text='%s'"
				% [i, str(e.key), str(e.custom_key), str(e.value),
				   str(e.get_text(0, false)).replace("\n", " / ")], LOG)

	ModLoaderLog.info("--- 完整描述 ---", LOG)
	for line in str(found.get_effects_text(0)).split("\n"):
		ModLoaderLog.info("   " + str(line).substr(0, 120), LOG)

	ModLoaderLog.info("=== turret probe end ===", LOG)
