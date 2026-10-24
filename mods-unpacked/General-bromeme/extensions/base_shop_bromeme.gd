extends "res://ui/menus/shop/base_shop.gd"

# =============================================================================
#  bromeme - meme核心：每在商店买一件东西，meme值 +1
#
#  专属道具「meme核心」的效果是「每购买一个道具，meme值 +1」，这种持续效果
#  没法用一次性 Effect 表达，所以挂商店的购买钩子。
#  判断持有：直接看背包里有没有 meme核心 那件道具（动态道具的 my_id 里带着
#  源道具 id），不去查玩家效果字典 —— 那个字典里没有我们自定义的键，
#  以前用 APPEND_KEY 标记效果会在 apply 时访问到空值。
# =============================================================================

const CORE_ID_PART: String = "item_bromeme_meme_core"
const MEME_STAT_KEY: String = "stat_meme"
# 每买一件东西 meme值 +3（用户 2026-09-30 从 +1 改上来）
const MEME_CORE_GAIN: int = 3
const LOG_NAME: String = "bromeme"
# 只处理 duplicate_item（镜子）；沙漏/金鱼在别的入口，读档修复已覆盖
const DUP_KEY: String = "duplicate_item"


func buy_item(item_data, player_index: int) -> void:
	# 兜底：清掉"指向未持有道具"的 duplicate_item 记录。
	# 原版 buy_item 会 get_player_item(镜子id) 拿到 null 再 remove_item(null) ——
	# 轻则白嫖道具、重则崩溃。正常情况读档修复已清干净，这里只兜万一。
	_bromeme_guard_duplicate_effects(player_index)
	.buy_item(item_data, player_index)
	_bromeme_meme_core_gain(player_index)


func buy_weapon(item_data, player_index: int) -> void:
	.buy_weapon(item_data, player_index)
	_bromeme_meme_core_gain(player_index)


func _bromeme_guard_duplicate_effects(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	if effects == null:
		return
	var dup_hash: int = Keys.generate_hash(DUP_KEY)
	if not effects.has(dup_hash):
		return
	var arr = effects[dup_hash]
	if not (arr is Array) or arr.empty():
		return
	var out: Array = []
	var dropped: int = 0
	for entry in arr:
		if entry is Array and entry.size() > 0:
			# entry[0] = 该效果引用的道具 id；玩家必须真的持有它
			if RunData.get_player_item(int(entry[0]), player_index) == null:
				dropped += 1
				continue
		out.append(entry)
	if dropped > 0:
		effects[dup_hash] = out
		ModLoaderLog.info("商店兜底：丢弃 %d 条指向未持有道具的 duplicate_item 效果" % dropped, LOG_NAME)


func _bromeme_meme_core_gain(player_index: int) -> void:
	if not _bromeme_has_meme_core(player_index):
		return

	RunData.add_stat(Keys.generate_hash(MEME_STAT_KEY), MEME_CORE_GAIN, player_index)
	ModLoaderLog.info("meme核心：meme值 +%d" % MEME_CORE_GAIN, LOG_NAME)


func _bromeme_has_meme_core(player_index: int) -> bool:
	for item in RunData.get_player_items(player_index):
		if item == null or not is_instance_valid(item):
			continue
		if String(item.my_id).find(CORE_ID_PART) >= 0:
			return true
	return false
