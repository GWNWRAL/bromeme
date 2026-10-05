extends "res://entities/units/player/player.gd"

# =============================================================================
#  bromeme :: 炮塔（character_bromeme_pt_431）的"按下移动键"机制
#
#  角色效果里带下面任一标记时才生效，其它角色（含原版、其它 mod）完全不受影响：
#
#    custom_key = "bromeme_turret_move"    → 按下移动键时：护甲翻倍，且无法回复生命
#    custom_key = "bromeme_turret_iframe"  → 刚按下移动键时：0.25s 无敌（冷却 1s）
#
#  实现要点：
#   * "按下移动键"看的是 player 的 _current_movement（原始输入方向，见 unit.get_move_input()），
#     速度被 -100% 卡死时它照样非零，所以站桩炮塔也能触发。
#   * 护甲翻倍 = 把"当前护甲"原样加进 TempStats（vanilla 每波结束会 TempStats.reset()）；
#     "无法回复生命" = 把当前生命再生临时压成 0（松开移动键立刻还原）。
#   * 无敌直接启动 player 自带的 $InvincibilityTimer —— 原版 take_damage() 就是看它，
#     不需要另做伤害拦截；冷却用 OS.get_ticks_msec() 记时间戳。
#
#  击退光环不在这里：角色用的是原版灯笼那条 knockback_aura 效果，
#  由游戏自己的 knockback_aura_effect_behavior 处理（见 README）。
# =============================================================================

const MOVE_MARKER := "bromeme_turret_move"
const IFRAME_MARKER := "bromeme_turret_iframe"

const IFRAME_DURATION := 0.25
const IFRAME_COOLDOWN_MS := 1000

var _brt_move_enabled := false
var _brt_iframe_enabled := false
var _brt_active := false

var _brt_moving := false
var _brt_armor_bonus := 0
var _brt_regen_penalty := 0
var _brt_last_iframe_ms := -IFRAME_COOLDOWN_MS
var _brt_logged := false


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)
	_brt_refresh()


func _brt_refresh() -> void:
	_brt_move_enabled = false
	_brt_iframe_enabled = false

	var character = RunData.get_player_character(player_index)
	if character == null:
		return

	for effect in character.effects:
		if effect == null or not is_instance_valid(effect):
			continue
		if effect.custom_key == MOVE_MARKER:
			_brt_move_enabled = true
		elif effect.custom_key == IFRAME_MARKER:
			_brt_iframe_enabled = true

	_brt_active = _brt_move_enabled or _brt_iframe_enabled

	if _brt_active and not _brt_logged:
		_brt_logged = true
		ModLoaderLog.info("炮塔移动机制已启用（护甲翻倍=%s 移动无敌=%s）"
				% [str(_brt_move_enabled), str(_brt_iframe_enabled)], "bromeme")


func _physics_process(delta: float) -> void:
	._physics_process(delta)

	if not _brt_active:
		return

	if dead or cleaning_up or _pending_die:
		if _brt_moving:
			_brt_end_moving()
		return

	var moving: bool = _current_movement != Vector2.ZERO
	if moving and not _brt_moving:
		_brt_begin_moving()
	elif not moving and _brt_moving:
		_brt_end_moving()


# -----------------------------------------------------------------------------
#  按下移动键 / 松开移动键
# -----------------------------------------------------------------------------

func _brt_begin_moving() -> void:
	_brt_moving = true

	if _brt_move_enabled:
		_brt_apply_move_stats()
	if _brt_iframe_enabled:
		_brt_try_iframe()


func _brt_end_moving() -> void:
	_brt_moving = false
	_brt_clear_move_stats()


# 护甲翻倍 + 生命再生归零。两者都记在 TempStats 上，松开时按同样的数值移除。
func _brt_apply_move_stats() -> void:
	var changed := false

	_brt_armor_bonus = int(Utils.get_stat(Keys.stat_armor_hash, player_index))
	if _brt_armor_bonus > 0:
		TempStats.add_stat(Keys.stat_armor_hash, _brt_armor_bonus, player_index)
		changed = true

	_brt_regen_penalty = int(Utils.get_stat(Keys.stat_hp_regeneration_hash, player_index))
	if _brt_regen_penalty > 0:
		TempStats.add_stat(Keys.stat_hp_regeneration_hash, -_brt_regen_penalty, player_index)
		changed = true

	if changed:
		LinkedStats.reset_player(player_index)


func _brt_clear_move_stats() -> void:
	var changed := false

	if _brt_armor_bonus > 0:
		TempStats.remove_stat(Keys.stat_armor_hash, _brt_armor_bonus, player_index)
		_brt_armor_bonus = 0
		changed = true

	if _brt_regen_penalty > 0:
		TempStats.remove_stat(Keys.stat_hp_regeneration_hash, -_brt_regen_penalty, player_index)
		_brt_regen_penalty = 0
		changed = true

	if changed:
		LinkedStats.reset_player(player_index)


# 刚按下移动键的瞬间给 0.25s 无敌，距上次触发不足 1s 就不再触发。
func _brt_try_iframe() -> void:
	var now: int = OS.get_ticks_msec()
	if now - _brt_last_iframe_ms < IFRAME_COOLDOWN_MS:
		return

	_brt_last_iframe_ms = now
	if _invincibility_timer != null:
		_invincibility_timer.start(IFRAME_DURATION)


# 每波结束时 vanilla 会 TempStats.reset()（main.gd），所以这里只清自己的记账，
# 绝不能再 remove 一次 —— 否则会变成负护甲。
func on_room_cleanup() -> void:
	.on_room_cleanup()

	_brt_moving = false
	_brt_armor_bonus = 0
	_brt_regen_penalty = 0
