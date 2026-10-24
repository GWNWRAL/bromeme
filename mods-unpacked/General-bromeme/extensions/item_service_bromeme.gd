extends "res://singletons/item_service.gd"

# =============================================================================
#  bromeme - 波次结束的「本 mod 物品 4 选 1」出卡
#
#  只提供出卡函数给 main 扩展调用（不改原版 get_upgrades：
#  原版那个升级面板卡皮巴拉等 mod 也在用，会互相顶掉，
#  我们的面板是自己一套，见 extensions/ui/bromeme_pick_ui.gd）。
#
#  三种卡：
#    组合卡   两件本 mod 道具的效果合在一张卡上，名字各取一半（直升机+肘 → 直升肘）
#    换属性卡 一件本 mod 道具的【全部】效果照搬，其中 1~2 条属性效果被换成别的
#             属性，换过的那几条数值在 -25%~+200% 之间随机浮动
#    转职卡   概率低（15%）：把玩家【全部】某条主属性按价值比折成另一条主属性
#             （不是 1:1），转换比例再乘一个 -50%~+100% 的浮动，最后附送一个
#             从任意物品里抽的增益效果
#
#  价值比来自原版升级（加点）数据 items/upgrades：同一档点数下每条属性给多少，
#  取 T1 的数值反推「1 点值多少」：worth = 1 / T1数值。
#  例如 armor T1=+1 → 1.0，max_hp T1=+3 → 0.333，range T1=+15 → 0.0667。
#  于是 max_hp → armor 的转换比例 = 0.333/1.0 = 1:0.333（armor 更贵）。
# =============================================================================

const BROMEME_ITEM_PREFIX: String = "item_bromeme_"
const BROMEME_RES_DIR: String = "res://mods-unpacked/General-bromeme/resources/"
# 卡道具的图标路径存在这里（卡图是运行时合成的，原版存档不存 Texture）
const BROMEME_CARD_ICON_FILE: String = "user://bromeme_card_icons.json"
const BROMEME_PICK_COUNT: int = 4
const BROMEME_LOG_NAME: String = "bromeme"

# 换属性卡：属性效果的数值浮动区间
const BROMEME_SWAP_VALUE_MIN: float = -0.25
const BROMEME_SWAP_VALUE_MAX: float = 2.0
# 转职卡
const BROMEME_JOB_CHANCE: float = 0.15
const BROMEME_JOB_FLOAT_MIN: float = -0.5
const BROMEME_JOB_FLOAT_MAX: float = 1.0
const BROMEME_JOB_BUFF_TRIES: int = 60

# 原版加点数据反推的属性价值（越大越贵），键是 Keys.hash_to_string 里的名字
const BROMEME_STAT_WORTH: Dictionary = {
	"stat_armor": 1.0,
	"stat_damage": 1.0,
	"stat_elemental_damage": 1.0,
	"stat_ranged_damage": 1.0,
	"stat_lifesteal": 1.0,
	"stat_engineering": 0.5,
	"stat_hp_regeneration": 0.5,
	"stat_melee_damage": 0.5,
	"stat_crit_chance": 0.333,
	"stat_dodge": 0.333,
	"stat_max_hp": 0.333,
	"stat_speed": 0.333,
	"stat_accuracy": 0.25,
	"stat_attack_speed": 0.2,
	"stat_harvesting": 0.2,
	"stat_luck": 0.2,
	"stat_percent_damage": 0.2,
	"stat_crit_damage": 0.1,
	"stat_range": 0.0667,
	# meme值按「约等于射程」定价
	"stat_meme": 0.0667,
}
# 表里没有的属性（别的 mod 加的）用这个兜底
const BROMEME_STAT_WORTH_DEFAULT: float = 0.2

# 「选项专属道具」：tier 3（原版红色框），抽到的概率低；最后一个是原版 DLC 道具蝾螈
const BROMEME_EXCLUSIVE_IDS: Array = [
	"item_bromeme_meme_core",
	"item_bromeme_meme_chaos",
	"item_bromeme_meme_random",
	"item_bromeme_meme_sell",
	"item_axolotl",
	# 苍 / 赫：挑战者初始携带，也会出现在 meme 奖励里（不进商店）
	"item_bromeme_orbs_cang",
	"item_bromeme_orbs_he",
]
const BROMEME_EXCLUSIVE_CHANCE: float = 0.10
# 角色卡：原来 0.15，改成原来的 1/3
const BROMEME_CHARACTER_CHANCE: float = 0.05
const BROMEME_AXOLOTL_ID: String = "item_axolotl"

# 「更混沌」的一批：概率比专属道具还低一半，效果也更疯
const BROMEME_CHAOS_IDS: Array = [
	"item_bromeme_meme_entropy",
	"item_bromeme_meme_gambler",
	"item_bromeme_meme_quantum",
	"item_bromeme_meme_sacrifice",
]
const BROMEME_CHAOS_CHANCE: float = 0.05
# 改造卡（换属性）出现概率：10%，其余位置出组合卡
const BROMEME_SWAP_CHANCE: float = 0.10
# 改造组合卡（组合 + 改造兼具）出现概率：20%
const BROMEME_COMBO_CHANCE: float = 0.20
# 随机抽取卡：20%（从所有道具里随机抽 3~4 条「非简单数值」效果，名字/图标随机）
const BROMEME_DRAW_CHANCE: float = 0.20
const BROMEME_DRAW_MIN: int = 3
const BROMEME_DRAW_MAX: int = 4
const BROMEME_EXCLUSIVE_MARKER: String = "bromeme_exclusive"

# -----------------------------------------------------------------------------
#  「依赖持有某件具体道具」的效果 —— 组合卡/抽取卡绝不能搬运
#
#  这类效果的 key 就是**源道具的 id**，读取方会拿这个 id 去玩家背包里找那个道具的
#  实例，用来实现"消耗/损毁"机制。原版只有 3 件：
#     item_mirror     镜子    custom_key=duplicate_item            storage=1 (KEY_VALUE)
#     item_goldfish   金鱼    custom_key=increase_tier_on_reroll   storage=4 (APPEND_KEY_VALUE)
#     item_hourglass  沙漏    custom_key=""（key 本身就是道具 id）  storage=0 (SUM)
#
#  一旦被复制到组合卡上，玩家持有的是**卡**而不是那件道具，于是：
#     base_shop.buy_item  → get_player_item(镜子id) 返回 null → remove_item(null)
#     base_shop 出发按钮   → get_player_item(沙漏id) 返回 null → remove_item(null)
#     set_reroll_button_price / shop_item → source_item.icon.get_data() 空引用
#  轻则刷道具/效果表错乱，重则崩溃。所以从源头禁止搬运。
# -----------------------------------------------------------------------------
const BROMEME_IDENTITY_ITEM_IDS: Array = ["item_mirror", "item_goldfish", "item_hourglass"]
const BROMEME_IDENTITY_CUSTOM_KEYS: Array = ["duplicate_item", "increase_tier_on_reroll"]


# 这条效果是否"依赖持有某件具体道具"（搬到卡上会坏）
func bromeme_is_identity_effect(effect) -> bool:
	if effect == null or not is_instance_valid(effect):
		return false
	if BROMEME_IDENTITY_CUSTOM_KEYS.has(String(effect.custom_key)):
		return true
	if BROMEME_IDENTITY_ITEM_IDS.has(String(effect.key)):
		return true
	return false

# 卡 → 道具：图标用卡图 + 减淡的 bromeme logo 水印
const BROMEME_LOGO_PATH: String = "res://mods-unpacked/General-bromeme/meme/content/ui/bromeme_logo.png"
const BROMEME_PICK_ICON_SIZE: int = 96
const BROMEME_LOGO_ALPHA: float = 0.35

var _bromeme_logo_image: Image = null


# 把一个运行时生成的道具登记进 ItemService.items。
# 这是"卡做成的道具"能被存档读回来的前提：原版 player_run_data.gd:177 读档时
# 用 my_id 在 ItemService.items 里找同 id 的道具，找不到就丢弃。
# 这些道具 unlocked_by_default = false + can_be_looted = false，
# 所以既不会进解锁表，也不会进商店池/宝箱 —— 只是"可被查回"。
func register_runtime_item(item) -> void:
	if item == null or not is_instance_valid(item):
		return
	# 空 id 的道具不注册（否则会被下面"已存在"的循环误判成重复而跳过）
	if String(item.my_id).empty():
		return
	for existing in items:
		if existing != null and is_instance_valid(existing) and existing.my_id == item.my_id:
			return
	items.append(item)


# 4 张卡：组合 / 换属性 交替出，另外低概率插一张转职卡
func bromeme_build_pick_cards(player_index: int) -> Array:
	var pool: Array = bromeme_item_pool(player_index)
	if pool.empty():
		return []

	# 面板每次弹出打一条，方便确认组合池范围（= 商店在售道具总数，约 485）
	ModLoaderLog.info("组合池：%d 件（含原版/其它mod）" % pool.size(), BROMEME_LOG_NAME)

	pool.shuffle()
	var picks: Array = []
	var cursor: int = 0
	var used: Dictionary = {}
	for i in BROMEME_PICK_COUNT:
		if cursor >= pool.size():
			break

		# 更混沌的专属道具：概率更低
		if not used.has("chaos") and randf() < BROMEME_CHAOS_CHANCE:
			var chaos = bromeme_make_chaos_pick(player_index)
			if chaos != null:
				picks.append(chaos)
				used["chaos"] = true
				continue

		# 选项专属道具（红色 tier 3，概率低，一轮最多一张）
		if not used.has("exclusive") and randf() < BROMEME_EXCLUSIVE_CHANCE:
			var exclusive = bromeme_make_exclusive_pick(player_index)
			if exclusive != null:
				picks.append(exclusive)
				used["exclusive"] = true
				continue

		# 角色卡（随机抽一个本 mod 角色，选中就获得它的效果）
		if not used.has("character") and randf() < BROMEME_CHARACTER_CHANCE:
			var character_pick = bromeme_make_character_pick()
			if character_pick != null:
				picks.append(character_pick)
				used["character"] = true
				continue

		# 转职卡：概率低，一次只出一张
		if not used.has("job") and randf() < BROMEME_JOB_CHANCE:
			var job = bromeme_make_job_pick(player_index)
			if job != null:
				picks.append(job)
				used["job"] = true
				continue

		# 普通位置：20% 改造组合卡（组合 + 改造）、10% 改造卡、其余组合卡
		var roll: float = randf()
		var can_pair: bool = cursor + 1 < pool.size()

		if can_pair and roll < BROMEME_COMBO_CHANCE:
			var combo_pick = bromeme_make_combo_pick(pool[cursor], pool[cursor + 1])
			cursor += 2
			if combo_pick != null:
				picks.append(combo_pick)
				continue

		if roll < BROMEME_COMBO_CHANCE + BROMEME_SWAP_CHANCE:
			var swap_item = pool[cursor]
			cursor += 1
			var swap_pick = bromeme_make_swap_pick(swap_item)
			if swap_pick != null:
				picks.append(swap_pick)
				continue
			# 造不出改造卡就退回组合卡
			if cursor < pool.size():
				var fallback_pick = bromeme_make_fusion_pick(swap_item, pool[cursor])
				cursor += 1
				if fallback_pick != null:
					picks.append(fallback_pick)
			continue

		if roll < BROMEME_COMBO_CHANCE + BROMEME_SWAP_CHANCE + BROMEME_DRAW_CHANCE:
			var draw = bromeme_make_draw_pick()
			if draw != null:
				picks.append(draw)
				continue

		if can_pair:
			var fusion_pick = bromeme_make_fusion_pick(pool[cursor], pool[cursor + 1])
			cursor += 2
			if fusion_pick != null:
				picks.append(fusion_pick)
				continue

		# 池子只剩最后一件
		if cursor >= pool.size():
			break
		var last_item = pool[cursor]
		cursor += 1
		var last_pick = bromeme_make_swap_pick(last_item)
		if last_pick != null:
			picks.append(last_pick)

	var names: Array = []
	for pick in picks:
		names.append(String(pick.name))
	ModLoaderLog.info("波次结束 4 选 1：%s" % PoolStringArray(names).join(" / "), BROMEME_LOG_NAME)
	return picks


# 道具的显示名。原版 / 其它 mod 的道具 name 存的是**翻译键**（如 "ITEM_ACID"），
# 直接拿来切片 / 显示就会露出键名（原版 UI 里显示 "ITEM_脊髓剑 IV 升级" 就是这么来的）。
# 原版自己的做法是 ItemParentData.get_name_text() { return tr(name) }，这里跟它一致：
# 优先调用对象自带的 get_name_text()，没有（或返回空）就退回 tr(name)，
# 再不行（tr 没查到会原样返回键）才用裸 name。
func bromeme_display_name(item) -> String:
	if item == null or not is_instance_valid(item):
		return ""
	var raw: String = String(item.get("name"))
	if item.has_method("get_name_text"):
		var t: String = String(item.call("get_name_text"))
		if not t.empty():
			return t
	if raw.empty():
		return ""
	var key: String = raw.to_upper()
	var translated: String = String(tr(key))
	if translated != key:
		return translated
	return raw


# 「各取一半」用的：先取显示名再切，避免切到翻译键的中间
func bromeme_half_display_name(a, b) -> String:
	return bromeme_half_name(bromeme_display_name(a), bromeme_display_name(b))


# 所有"会在商店卖的道具"（原版 + 其它 mod + 本 mod 商店货），不做 max_nb / 玩家相关过滤。
# 与 bromeme_item_pool() 同源（都读原版建的 _tiers_data ITEMS 池），
# 区别是这里给"随机抽取卡 / 随机 buff / 量子meme"当来源用，所以不排除已经拿满 max_nb 的道具
# —— 否则同一件道具拿满后就再也抽不到它的效果了。
# 结果缓存一份：量子meme 要对背包里每件道具按同 tier 筛池，不缓存就是 O(n²)。
# 缓存只在本次面板 / 本次选卡行为内有效（池子只会在进商店时被 init_unlocked_pool 重建）。
var _bromeme_shop_items_cache: Array = []


func bromeme_shop_items() -> Array:
	if not _bromeme_shop_items_cache.empty():
		return _bromeme_shop_items_cache

	var seen: Dictionary = {}
	var pool: Array = []
	var tiers = get("_tiers_data")
	if typeof(tiers) != TYPE_ARRAY:
		return pool
	for tier_data in tiers:
		if typeof(tier_data) != TYPE_ARRAY or tier_data.size() <= TierData.ITEMS:
			continue
		var items_pool = tier_data[TierData.ITEMS]
		if typeof(items_pool) != TYPE_ARRAY:
			continue
		for item in items_pool:
			if item == null or not is_instance_valid(item):
				continue
			if String(item.my_id).begins_with("character_"):
				continue
			if seen.has(item.my_id_hash):
				continue
			seen[item.my_id_hash] = true
			pool.append(item)
	_bromeme_shop_items_cache = pool
	return pool


# 候选：所有"会在商店卖的道具"——原版 + 其它 mod + 本 mod 的 71 件商店货。
# 直接读 ItemService._tiers_data 的 ITEMS 池（原版 init_unlocked_pool() 建的那份），
# 所以判定条件与商店完全一致：can_be_looted + 已解锁 + max_nb != 0，且自动排除武器/消耗品。
# 注意不要用 ProgressData.items_unlocked 当判据：2.42.2 之后本 mod 95 件全在里面。
# 排除项：
#   · 本 mod 的 24 件非商店货（4 选 1 专属/事件/角色自带）—— can_be_looted=false，本来就不在池里
#   · 字符道具（id 以 character_ 开头，原版把角色当道具放，避免把角色效果组合进来）
#   · 没有 effects 的、以及玩家已经拿满 max_nb 的
func bromeme_item_pool(player_index: int) -> Array:
	var seen: Dictionary = {}
	var pool: Array = []

	var tiers = get("_tiers_data")
	if typeof(tiers) == TYPE_ARRAY:
		for tier_data in tiers:
			if typeof(tier_data) != TYPE_ARRAY or tier_data.size() <= TierData.ITEMS:
				continue
			var items_pool = tier_data[TierData.ITEMS]
			if typeof(items_pool) != TYPE_ARRAY:
				continue
			for item in items_pool:
				_bromeme_try_pool_item(item, player_index, seen, pool)

	return pool


func _bromeme_try_pool_item(item, player_index: int, seen: Dictionary, pool: Array) -> void:
	if item == null or not is_instance_valid(item):
		return
	if item.effects == null or item.effects.empty():
		return
	if item.max_nb == 0:
		return
	if item.max_nb > 0 and RunData.get_nb_item(item.my_id_hash, player_index) >= item.max_nb:
		return
	if String(item.my_id).begins_with("character_"):
		return
	if seen.has(item.my_id_hash):
		return
	seen[item.my_id_hash] = true
	pool.append(item)


# 组合卡 / 改造卡 / 改造组合卡的共同入口检查：
# 只接受"会在商店卖的道具"（can_be_looted；本 mod 的 24 件专属/事件/角色自带道具是 false）。
# 池子 bromeme_item_pool() 本来就只收在售道具，这里是显式防线：
# 以后池子逻辑再怎么改，这三张卡也不可能拿非卖品当素材。
func bromeme_is_pickable(item) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	return bool(item.can_be_looted)


# -----------------------------------------------------------------------------
#  组合卡：两件道具的效果合在一起，名字各取一半
# -----------------------------------------------------------------------------
func bromeme_make_fusion_pick(a, b) -> UpgradeData:
	if not bromeme_is_pickable(a) or not bromeme_is_pickable(b):
		return null

	var effects: Array = []
	effects.append_array(bromeme_copy_effects(a))
	effects.append_array(bromeme_copy_effects(b))
	# 镜子/金鱼/沙漏这类道具的效果会被过滤掉；若两件都被滤空就别出卡
	if effects.empty():
		return null

	var pick := bromeme_new_pick("mix", "%s+%s" % [String(a.my_id), String(b.my_id)])
	pick.name = bromeme_half_display_name(a, b)
	pick.icon = a.icon
	pick.tier = max(int(a.tier), int(b.tier))
	pick.effects = effects
	return pick


# 「各取一半」（2 件组合用的旧行为，已按用户要求回退）：
# 前一件取开头一半，后一件取结尾一半。
# 例：直升机 + 肘 → "直升" + "肘" = "直升肘"
func bromeme_half_name(a: String, b: String) -> String:
	if a.empty():
		return b
	if b.empty():
		return a
	var front_len: int = int(ceil(a.length() / 2.0))
	var back_len: int = int(ceil(b.length() / 2.0))
	var front: String = a.substr(0, front_len)
	var back: String = b.substr(b.length() - back_len)
	return front + back


# 「各取一个词根」：每件物品各取名字的第一个字拼起来。
# 用于"多道具组合"（随机抽取卡从 3~4 件各取一条效果）。
# 中文名字本来就是一个字一个词根（例：直升机 + 肘 + 鬼火 → "直肘鬼"）；
# 英文等按"空格分段取首词"处理（例：Gun + Sword → "GunSword"），
# 否则逐字母取会得到没有意义的名字。
func bromeme_root_name(names: Array) -> String:
	var out: String = ""
	for raw in names:
		var name: String = String(raw).strip_edges()
		if name.empty():
			continue
		out += _bromeme_root_of(name)
	return out


func _bromeme_root_of(name: String) -> String:
	# 英文/含空格的：取第一个词
	if name.find(" ") >= 0:
		return name.split(" ")[0]
	# 中日韩等：取第一个字
	return name.substr(0, 1)


# -----------------------------------------------------------------------------
#  换属性卡：保留道具全部效果，只把其中 1~2 条属性效果换属性
# -----------------------------------------------------------------------------
func bromeme_make_swap_pick(item) -> UpgradeData:
	if not bromeme_is_pickable(item):
		return null

	var effects: Array = bromeme_copy_effects(item)
	if effects.empty():
		return null

	var changed: Array = bromeme_apply_stat_swap(effects)

	var pick := bromeme_new_pick("swap", String(item.my_id))
	var shown_name: String = bromeme_display_name(item)
	pick.name = shown_name
	if not changed.empty():
		# 名字里不写换了什么，只加个问号（改了哪几条留给日志）
		pick.name = "%s？" % shown_name
		ModLoaderLog.info("改造卡 %s：%s" % [shown_name, PoolStringArray(changed).join("，")], BROMEME_LOG_NAME)
	pick.icon = item.icon
	pick.tier = int(item.tier)
	pick.effects = effects
	return pick


# 改造组合卡：两件道具效果合一（名字各取一半），再改造其中 1~2 条属性
func bromeme_make_combo_pick(a, b) -> UpgradeData:
	if not bromeme_is_pickable(a) or not bromeme_is_pickable(b):
		return null

	var effects: Array = []
	effects.append_array(bromeme_copy_effects(a))
	effects.append_array(bromeme_copy_effects(b))
	if effects.empty():
		return null

	var changed: Array = bromeme_apply_stat_swap(effects)

	var pick := bromeme_new_pick("comboswap", "%s+%s" % [String(a.my_id), String(b.my_id)])
	var base_name: String = bromeme_half_display_name(a, b)
	pick.name = base_name
	if not changed.empty():
		pick.name = "%s？" % base_name
	ModLoaderLog.info("改造组合卡 %s（%s + %s）：%s" % [
			base_name, bromeme_display_name(a), bromeme_display_name(b), PoolStringArray(changed).join("，")], BROMEME_LOG_NAME)
	pick.icon = a.icon
	pick.tier = max(int(a.tier), int(b.tier))
	pick.effects = effects
	return pick


# 把效果数组里 1~2 条属性效果换成别的属性（数值 -25%~+200%），返回改动说明（空数组 = 没改）
func bromeme_apply_stat_swap(effects: Array) -> Array:
	var stat_indexes: Array = []
	for idx in effects.size():
		if Utils.is_stat_key(effects[idx].key_hash):
			stat_indexes.append(idx)
			# 没被换掉的那些属性条也要保证能显示数值（别的 mod 的属性会丢数字）
			_bromeme_fix_stat_effect_text(effects[idx], effects[idx].key_hash)
	if stat_indexes.empty():
		return []

	stat_indexes.shuffle()
	var swap_count: int = min(stat_indexes.size(), 1 + (randi() % 2))
	var changed: Array = []
	for k in swap_count:
		var effect = effects[stat_indexes[k]]
		var old_hash: int = effect.key_hash
		var new_hash: int = bromeme_roll_stat_hash(old_hash)
		if new_hash == 0:
			continue
		changed.append("%s→%s" % [bromeme_stat_label(old_hash), bromeme_stat_label(new_hash)])
		effect.key = bromeme_stat_name(new_hash)
		effect.key_hash = new_hash
		_bromeme_fix_stat_effect_text(effect, new_hash)
		effect.custom_key = ""
		effect.custom_key_hash = Keys.empty_hash
		# 数值在 -25%~+200% 之间浮动
		effect.value = int(round(float(effect.value) * rand_range(BROMEME_SWAP_VALUE_MIN, BROMEME_SWAP_VALUE_MAX)))
	return changed


# Text 单例上那张"需要操作符的属性"表。用动态取节点而不是直接写 `Text.xxx`：
# 语法自检工程里没有 Text stub，直接引用会 parse error。
func _bromeme_text_needs_operator(raw_name: String) -> bool:
	if raw_name == "":
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var t = tree.root.get_node_or_null("Text")
	if t == null:
		return false
	var map = t.get("keys_needing_operator")
	if typeof(map) != TYPE_DICTIONARY:
		return false
	return map.has(raw_name)


# 让一条属性效果的文本一定带得出数值。
# 原版属性（例如 stat_armor）的 key 本身在 keys_needing_operator 里，文本会自动变成
# "+5 护甲"；但**别的 mod 的属性**常常两条都不满足（翻译串里既没有 {0}、
# 名字又没登记进 keys_needing_operator），效果行就只剩属性名、数值消失
# （用户截图里的 "-3 %暴击率" / "+2 %生命窃取"）。
# 这里：只有在文本里确实取不到数值时才改写，避免动到本来正常的原版属性行。
func _bromeme_fix_stat_effect_text(effect, stat_hash: int) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	var raw: String = bromeme_stat_name(stat_hash)
	if raw == "":
		return
	var key_text: String = raw.to_upper() if String(effect.text_key).length() == 0 else String(effect.text_key).to_upper()
	if String(tr(key_text)).find("{0}") >= 0:
		return          # 翻译串自己带 {0}，能显示数值，不用动
	if _bromeme_text_needs_operator(raw):
		return          # 原版会把它当成"需要操作符的属性"，自动变成 "+N 名字"
	var lbl: String = bromeme_stat_label(stat_hash)
	if lbl == "":
		return
	effect.text_key = "{0} " + lbl
	effect.key = raw
	effect.key_hash = stat_hash


# -----------------------------------------------------------------------------
#  转职卡：把玩家全部某条主属性按价值比折成另一条 + 送一个增益
# -----------------------------------------------------------------------------
func bromeme_make_job_pick(player_index: int) -> UpgradeData:
	var keys: Array = Utils.get_primary_stat_keys()

	var owned: Array = []
	for key in keys:
		var stat_key: int = int(key)
		if stat_key == Keys.empty_hash:
			continue
		if bromeme_stat_excluded(stat_key):
			continue
		if RunData.get_player_effect(stat_key, player_index) > 0:
			owned.append(stat_key)
	if owned.empty():
		return null

	owned.shuffle()
	var source_key: int = owned[0]

	var targets: Array = []
	for key in keys:
		var stat_key: int = int(key)
		if stat_key == source_key or stat_key == Keys.empty_hash:
			continue
		if bromeme_stat_excluded(stat_key):
			continue
		targets.append(stat_key)
	if targets.empty():
		return null
	var target_key: int = targets[randi() % targets.size()]

	var raw_source: float = RunData.get_player_effect(source_key, player_index)
	var shown_source: float = Utils.get_stat(source_key, player_index)
	var worth_source: float = bromeme_stat_worth(source_key)
	var worth_target: float = bromeme_stat_worth(target_key)
	# 价值比只用于算「本次比例」，卡面不再显示它（用户要求只显示本次比例）
	var _base_ratio: float = worth_source / max(worth_target, 0.0001)
	var final_ratio: float = _base_ratio * (1.0 + rand_range(BROMEME_JOB_FLOAT_MIN, BROMEME_JOB_FLOAT_MAX))
	var converted: int = max(1, int(round(shown_source * final_ratio)))

	var source_name: String = bromeme_stat_label(source_key)
	var target_name: String = bromeme_stat_label(target_key)

	var effects: Array = []

	# 说明行（key 为空 → 不会被 apply，只是一行字）
	# 只显示「本次」的换算比例，不再暴露基础价值比和浮动区间（用户要求）
	var explain := Effect.new()
	explain.key = ""
	explain.text_key = "转职：全部 %s → %s（本次 1:%.2f）" % [
			source_name, target_name, final_ratio]
	explain.value = 0
	effects.append(explain)

	# 扣掉全部来源属性
	var loss := Effect.new()
	loss.key = bromeme_stat_name(source_key)
	loss.key_hash = source_key
	loss.text_key = ""
	loss.value = -int(round(raw_source))
	_bromeme_fix_stat_effect_text(loss, source_key)
	effects.append(loss)

	# 加上折算出来的目标属性
	var gain := Effect.new()
	gain.key = bromeme_stat_name(target_key)
	gain.key_hash = target_key
	gain.text_key = ""
	gain.value = converted
	_bromeme_fix_stat_effect_text(gain, target_key)
	effects.append(gain)

	# 说明：转职卡**不再**附赠随机效果（用户要求删掉原来那条"附送的增益"）。

	var pick := bromeme_new_pick("job", "%s>%s" % [bromeme_stat_name(source_key), bromeme_stat_name(target_key)])
	pick.name = "转职：%s → %s" % [source_name, target_name]
	pick.icon = get_stat_small_icon(source_key)
	pick.tier = 3
	pick.effects = effects
	return pick


func bromeme_make_random_buff():
	var pool: Array = []
	for item in bromeme_shop_items():
		for effect in item.effects:
			if effect == null or not is_instance_valid(effect):
				continue
			if Utils.is_stat_key(effect.key_hash) and effect.value > 0:
				pool.append(effect)
	if pool.empty():
		return null
	pool.shuffle()
	var copy = pool[0].duplicate()
	if copy == null or not is_instance_valid(copy):
		return null
	# 抽到的可能是别的 mod 的属性，同样要把文本补成能显示数值的形式
	_bromeme_fix_stat_effect_text(copy, copy.key_hash)
	return copy


# 随机抽取卡：从**商店在售道具**里随机抽 3~4 条「不是简单数值加减」的效果，名字/图标随机
#（原来扫的是全游戏 ItemService.items，会把本 mod 的非卖品和其它 mod 的隐藏道具也抽进来）
func bromeme_make_draw_pick() -> UpgradeData:
	var candidates: Array = []
	for item in bromeme_shop_items():
		if item.effects == null:
			continue
		for effect in item.effects:
			if effect == null or not is_instance_valid(effect):
				continue
			# 别的 mod 的效果对象里 key_hash 常常是空的，所以用 key 现算一次
			var eff_hash: int = effect.key_hash
			if eff_hash == Keys.empty_hash and not String(effect.key).empty():
				eff_hash = Keys.generate_hash(String(effect.key))
			# 排除简单数值加减（纯属性 key），以及本 mod 那些只用于展示的标记效果
			if Utils.is_stat_key(eff_hash):
				continue
			if String(effect.custom_key) == BROMEME_EXCLUSIVE_MARKER:
				continue
			# 镜子/金鱼/沙漏的效果会去背包找"那件道具"，搬到卡上必坏
			if bromeme_is_identity_effect(effect):
				continue
			candidates.append([effect, item])
	if candidates.empty():
		return null

	candidates.shuffle()
	var want: int = BROMEME_DRAW_MIN + (randi() % (BROMEME_DRAW_MAX - BROMEME_DRAW_MIN + 1))
	var effects: Array = []
	var sources: Array = []
	var seen: Dictionary = {}
	for entry in candidates:
		if effects.size() >= want:
			break
		var effect = entry[0]
		var item = entry[1]
		var dedup: String = "%s|%s|%s" % [String(item.my_id), String(effect.custom_key), String(effect.key)]
		if seen.has(dedup):
			continue
		seen[dedup] = true
		var copy = effect.duplicate()
		if copy == null or not is_instance_valid(copy):
			continue
		effects.append(copy)
		sources.append(item)

	if effects.empty():
		return null
	# 去重后的来源道具（同名的只算一次），用于拼卡名
	var uniq_items: Array = []
	var uniq_seen: Dictionary = {}
	for it in sources:
		if it == null or not is_instance_valid(it):
			continue
		var mid: String = String(it.my_id)
		if uniq_seen.has(mid):
			continue
		uniq_seen[mid] = true
		uniq_items.append(it)

	# 卡名 = 每件来源道具各取一个词根（用户要求）。
	# 例：直升机 + 肘 + 鬼火 → "直肘鬼"
	var name_parts: Array = []
	for it in uniq_items:
		name_parts.append(bromeme_display_name(it))
	var composed: String = bromeme_root_name(name_parts)

	var source_item = uniq_items[0] if not uniq_items.empty() else null
	if source_item == null:
		return null
	var pick := bromeme_new_pick("draw", String(source_item.my_id))
	pick.name = composed if not composed.empty() else bromeme_display_name(source_item)
	pick.icon = source_item.icon
	pick.tier = int(source_item.tier)
	pick.effects = effects

	var names: Array = []
	for effect in effects:
		names.append(String(effect.key))
	ModLoaderLog.info("随机抽取卡 %s（%d 件各取一条：%s）：%d 条效果（%s）" % [
			pick.name, uniq_items.size(), PoolStringArray(name_parts).join("+"),
			effects.size(), PoolStringArray(names).join("，")], BROMEME_LOG_NAME)
	return pick


# -----------------------------------------------------------------------------
#  选项专属道具卡 / 角色卡
# -----------------------------------------------------------------------------
func bromeme_make_exclusive_pick(player_index: int = 0) -> UpgradeData:
	var pool: Array = []
	for item_id in BROMEME_EXCLUSIVE_IDS:
		var item = get_item_from_id(Keys.generate_hash(String(item_id)))
		if item == null or not is_instance_valid(item):
			continue
		# 和普通池 _bromeme_try_pool_item 同样的限制：
		# max_nb 是"最多持有几个"（直升机/苍/赫都是 1），已持有到上限就不再进池，
		# 否则专属道具会被反复抽到（用户反馈：苍赫能重复买）。
		if item.max_nb > 0 and RunData.get_nb_item(item.my_id_hash, player_index) >= item.max_nb:
			continue
		pool.append(item)
	if pool.empty():
		return null

	pool.shuffle()
	var item = pool[0]
	var pick := bromeme_new_pick("exclusive", String(item.my_id))
	pick.name = bromeme_display_name(item)
	pick.icon = item.icon
	pick.tier = 3
	pick.effects = bromeme_copy_effects(item)
	return pick


# 「更混沌」那一批：同样走 exclusive 前缀，行为在 main 扩展里按 id 分派
func bromeme_make_chaos_pick(player_index: int = 0) -> UpgradeData:
	var pool: Array = []
	for item_id in BROMEME_CHAOS_IDS:
		var item = get_item_from_id(Keys.generate_hash(String(item_id)))
		if item == null or not is_instance_valid(item):
			continue
		# 同专属池：max_nb 是持有上限（这 4 件都是 1），到上限就不再进池
		if item.max_nb > 0 and RunData.get_nb_item(item.my_id_hash, player_index) >= item.max_nb:
			continue
		pool.append(item)
	if pool.empty():
		return null

	pool.shuffle()
	var item = pool[0]
	var pick := bromeme_new_pick("exclusive", String(item.my_id))
	pick.name = bromeme_display_name(item)
	pick.icon = item.icon
	pick.tier = 3
	pick.effects = bromeme_copy_effects(item)
	return pick


func bromeme_make_character_pick() -> UpgradeData:
	var pool: Array = []
	for character in characters:
		if character == null or not is_instance_valid(character):
			continue
		if not String(character.my_id).begins_with("character_bromeme_"):
			continue
		pool.append(character)
	if pool.empty():
		return null

	pool.shuffle()
	var character = pool[0]
	var pick := bromeme_new_pick("character", String(character.my_id))
	pick.name = bromeme_display_name(character)
	pick.icon = character.icon
	pick.tier = 3
	pick.effects = bromeme_copy_effects(character)
	return pick


# -----------------------------------------------------------------------------
#  卡 → 道具：选中后作为一件道具进背包（图标 = 卡图 + 减淡的 logo）
# -----------------------------------------------------------------------------
func bromeme_make_pick_item(card, _player_index: int) -> ItemData:
	# 用一件真实存在的道具当模板复制出来，字段最全
	# （item_appearances / tags / max_nb / tracking_text …），
	# 避免 ItemData.new() 造出来的半成品在背包 / 「获得道具」弹窗里被取到空值而闪退
	var item = null
	var template = bromeme_pick_item_template()
	if template != null:
		item = template.duplicate()
	if item == null or not (item is ItemData):
		item = ItemData.new()

	# 稳定且唯一的 id（同一张卡的重复件自动加序号 _2 / _3 …）。
	# 为什么必须稳定：原版读档时是拿 **存档里的 my_id** 去 ItemService.items 里
	# 找同 id 的道具再反序列化（player_run_data.gd:177 get_element_safe），
	# 找不到就**直接把这个道具丢掉** —— 这就是"meme 奖励道具 SL 后消失"的根因。
	# 所以卡道具必须有确定的 id 并注册进 ItemService.items，读档才认得回来。
	var base_id: String = "item_bromeme_pick_%s" % String(card.my_id).replace("|", "_")
	item.my_id = _bromeme_available_pick_id(base_id)
	item.my_id_hash = Keys.generate_hash(item.my_id)
	# ⚠️ 这里**绝不能**给实例 set_script()：卡道具是从共用模板 duplicate 出来的，
	# 给已实例化的 Resource 换脚本会重建脚本实例（悬空引用风险），
	# 实测引发过原生访问违例崩溃（Brotato.exe 0xc0000005，日志里没有 SCRIPT ERROR）。
	# 卡道具的图标是运行时合成的、原版 serialize 不存 Texture，所以图标来源
	# 记到 user:// 下的小文件里（见 bromeme_remember_icon_path）。
	item.name = String(card.name)
	# 水印规则（用户 2.42.40 要求）：
	#   · meme 系列道具（量子meme 等 8 件）→ **不加**水印，用道具自己的图标
	#   · 组合卡（融合/改造组合）、改造卡、转职卡、随机抽取卡、角色卡 → 保持原样（加水印）
	if _bromeme_card_is_meme_item(card):
		item.icon = _bromeme_card_source_icon(card)
		if item.icon == null:
			item.icon = bromeme_watermark_icon(card.icon)
	else:
		item.icon = bromeme_watermark_icon(card.icon)
	bromeme_remember_icon_path(item.my_id, card)
	item.tier = int(card.tier)
	item.value = 60
	item.unlocked_by_default = false
	item.can_be_looted = false
	item.is_lockable = false
	item.max_nb = 0
	item.tracking_text = ""

	var effects: Array = []
	if card.effects != null:
		for effect in card.effects:
			if effect != null and is_instance_valid(effect):
				effects.append(effect)
	item.effects = effects
	# 注册进 ItemService.items（unlocked_by_default=false → 不会被塞进解锁表，
	# 也不会进商店池/宝箱；只是让读档能按 id 找回它）
	ItemService.register_runtime_item(item)
	return item


# 这张卡是不是"meme 系列道具"（量子meme / meme核心 / 熵增meme …）。
# 这类卡的来源是一件**真实存在的道具**，它自带图标，不需要 mod 水印。
func _bromeme_card_is_meme_item(card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var source_id: String = _bromeme_card_source_item_id(card)
	if source_id == "":
		return false
	if not source_id.begins_with("item_bromeme_meme_"):
		return false
	# 确认它确实是本 mod 注册的 meme 系列（8 件：4 专属 + 4 混沌）
	return get_item_from_id(Keys.generate_hash(source_id)) != null


# 卡的来源道具 id：卡 id 形如 bromeme_pick|exclusive|item_bromeme_meme_quantum
func _bromeme_card_source_item_id(card) -> String:
	if card == null or not is_instance_valid(card):
		return ""
	var raw: String = String(card.my_id)
	var segs: Array = raw.split("|")
	if segs.size() >= 3:
		return String(segs[2])
	return ""


# 来源道具自己的图标（不加任何水印）；取不到则返回 null，由调用方兜底
func _bromeme_card_source_icon(card):
	var source_id: String = _bromeme_card_source_item_id(card)
	if source_id == "":
		return null
	var src = get_item_from_id(Keys.generate_hash(source_id))
	if src != null and src.icon != null:
		return src.icon
	return bromeme_raw_icon_for(source_id)


# 在当前 ItemService.items 里找一个还没被占用的 id：
# 先试 base_id 本身，被占了就依次试 base_id + "_2"、"_3" …
func _bromeme_available_pick_id(base_id: String) -> String:
	var taken: Dictionary = {}
	for existing in items:
		if existing != null and is_instance_valid(existing):
			taken[String(existing.my_id)] = true
	if not taken.has(base_id):
		return base_id
	var n: int = 2
	while taken.has("%s_%d" % [base_id, n]):
		n += 1
	return "%s_%d" % [base_id, n]


# 拿一件有图标的真实 mod 道具当模板
func bromeme_pick_item_template():
	for item in items:
		if item == null or not is_instance_valid(item):
			continue
		if not String(item.my_id).begins_with(BROMEME_ITEM_PREFIX):
			continue
		if item.icon == null or item.effects == null or item.effects.empty():
			continue
		return item
	return null


func bromeme_watermark_icon(base_icon: Texture) -> Texture:
	if base_icon == null:
		return null

	var base_image: Image = base_icon.get_data()
	if base_image == null:
		return base_icon

	base_image = base_image.duplicate()
	base_image.convert(Image.FORMAT_RGBA8)
	if base_image.get_width() != BROMEME_PICK_ICON_SIZE or base_image.get_height() != BROMEME_PICK_ICON_SIZE:
		base_image.resize(BROMEME_PICK_ICON_SIZE, BROMEME_PICK_ICON_SIZE, Image.INTERPOLATE_LANCZOS)

	var logo: Image = bromeme_logo_image()
	if logo != null:
		var logo_w: int = BROMEME_PICK_ICON_SIZE - 10
		var logo_h: int = max(1, int(round(float(logo.get_height()) * float(logo_w) / float(logo.get_width()))))
		if logo_h > BROMEME_PICK_ICON_SIZE / 2:
			logo_h = BROMEME_PICK_ICON_SIZE / 2
			logo_w = max(1, int(round(float(logo.get_width()) * float(logo_h) / float(logo.get_height()))))
		logo.resize(logo_w, logo_h, Image.INTERPOLATE_LANCZOS)
		var pos := Vector2((BROMEME_PICK_ICON_SIZE - logo_w) / 2, BROMEME_PICK_ICON_SIZE - logo_h - 3)
		base_image.lock()
		base_image.blend_rect(logo, Rect2(0, 0, logo_w, logo_h), pos)
		base_image.unlock()

	var texture := ImageTexture.new()
	texture.create_from_image(base_image, Texture.FLAG_FILTER)
	return texture


# logo 图（读 mod 里的 png 字节，并把不透明度压到 LOGO_ALPHA）
func bromeme_logo_image() -> Image:
	if _bromeme_logo_image != null:
		return _bromeme_logo_image

	var file := File.new()
	if file.open(BROMEME_LOGO_PATH, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)

	# 减淡
	image.lock()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			color.a = color.a * BROMEME_LOGO_ALPHA
			image.set_pixel(x, y, color)
	image.unlock()

	_bromeme_logo_image = image
	return image


# -----------------------------------------------------------------------------
#  小工具
# -----------------------------------------------------------------------------
# 不参与「转职」和「改造卡（换属性）」的属性：
# 击杀敌人数这类的计数器（id 里带 kill，例如 stat_capybara_enemies_killed /
# stat_every_killed_enemies），以及译名里含「击杀 / killed」的
const BROMEME_STAT_EXCLUDE_PARTS: Array = ["kill"]
const BROMEME_STAT_EXCLUDE_TEXT: Array = ["击杀", "killed"]


func bromeme_stat_excluded(stat_hash: int) -> bool:
	var stat_name: String = bromeme_stat_name(stat_hash)
	if stat_name.empty():
		return false
	for part in BROMEME_STAT_EXCLUDE_PARTS:
		if stat_name.find(String(part)) >= 0:
			return true
	var shown: String = tr(stat_name.to_upper())
	for part in BROMEME_STAT_EXCLUDE_TEXT:
		if shown.find(String(part)) >= 0:
			return true
	return false


# 卡道具的 my_id（item_bromeme_pick_…）→ 它该有的水印图标。
# 卡道具的图是运行时合成的、原版 serialize 不存 Texture，读档后要靠这个函数重建；
# 数据来源按可靠度依次是：
#   1) 记忆表 user://bromeme_card_icons.json（选卡时写入"这张卡来自哪张卡"，最准）
#   2) 从卡道具 id 反推 tag（item_bromeme_pick_<kind>_<tag>，tag 就是来源内容）
#   3) resources 图标表兜底
var _bromeme_pick_icon_cache: Dictionary = {}
var _bromeme_raw_icon_map: Dictionary = {}
var _bromeme_raw_icon_cache: Dictionary = {}


func bromeme_pick_icon_for_source(card_item_id: String) -> Texture:
	if _bromeme_pick_icon_cache.has(card_item_id):
		return _bromeme_pick_icon_cache[card_item_id]

	# 优先用"记忆表"：里面记着这张卡图标来自哪张卡（比从 id 反推 tag 更准，
	# 因为 job 卡的 tag 是两条属性名、mix 卡是两件道具拼接）
	var remembered: String = bromeme_recall_icon_path(card_item_id)
	if remembered != "":
		var card_from_mem = _bromeme_find_pick_card(remembered)
		if card_from_mem != null and card_from_mem.icon != null:
			var tex_mem: Texture = bromeme_watermark_icon(card_from_mem.icon)
			if tex_mem != null:
				_bromeme_pick_icon_cache[card_item_id] = tex_mem
				return tex_mem

	var item_prefix: String = "item_bromeme_pick_"
	var card_prefix: String = "bromeme_pick_"
	if not card_item_id.begins_with(item_prefix):
		return null
	var rest: String = card_item_id.substr(item_prefix.length())
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return null
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)

	var base: Texture = null
	var source_id: String = ""
	if kind == "job":
		# tag = stat_a>stat_b，用来源属性的小图标
		var gt: int = tag.find(">")
		source_id = tag if gt < 0 else tag.substr(0, gt)
		if source_id != "":
			base = get_stat_small_icon(Keys.generate_hash(source_id))
	else:
		# mix / comboswap 的 tag 是 "a+b"，取第一件
		var plus: int = tag.find("+")
		source_id = tag if plus < 0 else tag.substr(0, plus)
		var src = get_item_from_id(Keys.generate_hash(source_id))
		if src == null:
			for ch in characters:
				if ch != null and is_instance_valid(ch) and String(ch.my_id) == source_id:
					src = ch
					break
		if src != null:
			base = src.icon

	if base == null:
		# 兜底：直接从 resources 的图标表里读来源内容自己的图标（不依赖是否已注册）
		base = bromeme_raw_icon_for(source_id)
	if base == null:
		return null

	var tex: Texture = bromeme_watermark_icon(base)
	_bromeme_pick_icon_cache[card_item_id] = tex
	return tex


# 按 id 找"卡片"本体（道具优先，其次角色）—— 记忆表里存的是卡的 my_id
func _bromeme_find_pick_card(id: String):
	if id == "":
		return null
	var item = get_item_from_id(Keys.generate_hash(id))
	if item != null:
		return item
	for ch in characters:
		if ch != null and is_instance_valid(ch) and String(ch.my_id) == id:
			return ch
	return null


# 按"卡片 id"直接出水印图标（记忆表存的格式：bromeme_pick|job|stat_a>stat_b）
func bromeme_icon_for_card_id(card_id: String) -> Texture:
	if card_id == "":
		return null
	var cache_key: String = "card|" + card_id
	if _bromeme_pick_icon_cache.has(cache_key):
		return _bromeme_pick_icon_cache[cache_key]
	var card = _bromeme_find_pick_card(card_id)
	var tex: Texture = null
	if card != null and card.icon != null:
		tex = bromeme_watermark_icon(card.icon)
	_bromeme_pick_icon_cache[cache_key] = tex
	return tex


# 从 resources/*.json 的图标表里取某个 id 的原始图标（不经过 ItemService）
func bromeme_raw_icon_for(source_id: String) -> Texture:
	if source_id == "":
		return null
	if _bromeme_raw_icon_map.empty():
		var idx_file := File.new()
		if idx_file.open(BROMEME_RES_DIR + "_index.json", File.READ) != OK:
			return null
		var idx = parse_json(idx_file.get_as_text())
		idx_file.close()
		if idx == null or typeof(idx) != TYPE_DICTIONARY:
			return null
		var files = idx.get("files")
		if typeof(files) == TYPE_ARRAY:
			for name in files:
				var f := File.new()
				if f.open(BROMEME_RES_DIR + String(name), File.READ) != OK:
					continue
				var d = parse_json(f.get_as_text())
				f.close()
				if d == null or typeof(d) != TYPE_DICTIONARY:
					continue
				if int(d.get("item_type", 1)) == 0:
					continue
				var mid: String = String(d.get("my_id", ""))
				var rel: String = String(d.get("relative_icon_path", ""))
				if mid != "" and rel != "":
					_bromeme_raw_icon_map[mid] = rel

	var rel2: String = String(_bromeme_raw_icon_map.get(source_id, ""))
	if rel2 == "":
		return null
	var path: String = BROMEME_RES_DIR + rel2
	if _bromeme_raw_icon_cache.has(path):
		return _bromeme_raw_icon_cache[path]

	var file2 := File.new()
	if file2.open(path, File.READ) != OK:
		_bromeme_raw_icon_cache[path] = null
		return null
	var buffer: PoolByteArray = file2.get_buffer(file2.get_len())
	file2.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		_bromeme_raw_icon_cache[path] = null
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != BROMEME_PICK_ICON_SIZE or image.get_height() != BROMEME_PICK_ICON_SIZE:
		image.resize(BROMEME_PICK_ICON_SIZE, BROMEME_PICK_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex2 := ImageTexture.new()
	tex2.create_from_image(image, Texture.FLAG_FILTER)
	_bromeme_raw_icon_cache[path] = tex2
	return tex2


# -----------------------------------------------------------------------------
#  卡道具图标路径的持久化
#
#  卡图 = 来源图 + mod logo 水印，是运行时合成的；原版 serialize() 不存 Texture，
#  所以退出重进后要能"知道这张卡该用哪个来源图"。
#  不去给 Resource 挂脚本（那会重建脚本实例、有悬空引用风险，实测崩过），
#  改成在 user:// 下记一个小 json：{ 卡道具 my_id -> 该卡的 my_id }。
#  读档时按记录的来源 id 反查图标即可。
# -----------------------------------------------------------------------------

func bromeme_icon_map_remembered() -> Dictionary:
	var out: Dictionary = {}
	var f := File.new()
	if not f.file_exists(BROMEME_CARD_ICON_FILE):
		return out
	if f.open(BROMEME_CARD_ICON_FILE, File.READ) != OK:
		return out
	var text: String = f.get_as_text()
	f.close()
	var parsed = parse_json(text)
	if parsed is Dictionary:
		return parsed
	return out


# 记录"这件卡道具的图标来自哪张卡"，供读档后重建图标用
func bromeme_remember_icon_path(card_item_id: String, card) -> void:
	if card_item_id == "" or card == null:
		return
	var map: Dictionary = bromeme_icon_map_remembered()
	if String(map.get(card_item_id, "")) == String(card.my_id):
		return
	map[card_item_id] = String(card.my_id)
	var f := File.new()
	if f.open(BROMEME_CARD_ICON_FILE, File.WRITE) != OK:
		return
	f.store_string(to_json(map))
	f.close()


# 读回"这件卡道具的图标来自哪张卡"（没有记录则返回空串）
func bromeme_recall_icon_path(card_item_id: String) -> String:
	return String(bromeme_icon_map_remembered().get(card_item_id, ""))


func bromeme_stat_name(stat_hash: int) -> String:
	return String(Keys.hash_to_string.get(stat_hash, ""))


# 属性的「短名」，专门用来拼卡名 / 说明行。
# 关键：别的 mod 的属性翻译串**自带百分号**（例如 stat_crit_chance 翻成 "%暴击率"），
# 而原版 Text.text() 会按 keys_needing_percent 自己补一个 % ——
# 于是先 tr() 再拼字符串就会得到 "%%暴击率"（用户截图里的现象）。
# 这里把 % 去掉，交给原版在效果行里自己补；卡名/说明行本来就是纯文本，不带 % 更干净。
func bromeme_stat_label(stat_hash: int) -> String:
	var raw: String = bromeme_stat_name(stat_hash)
	if raw == "":
		return ""
	var shown: String = String(tr(raw.to_upper()))
	if shown == "" or shown == raw.to_upper():
		shown = raw
	return shown.replace("%", "").strip_edges()


func bromeme_stat_worth(stat_hash: int) -> float:
	var stat_name: String = bromeme_stat_name(stat_hash)
	if BROMEME_STAT_WORTH.has(stat_name):
		return float(BROMEME_STAT_WORTH[stat_name])
	return BROMEME_STAT_WORTH_DEFAULT


# 从原版主属性池里随机换一条（排除原来的那条，以及击杀数这类计数器）
func bromeme_roll_stat_hash(old_hash: int) -> int:
	var all_keys: Array = Utils.get_primary_stat_keys()
	var pool: Array = []
	for key in all_keys:
		if int(key) == old_hash:
			continue
		if int(key) == Keys.empty_hash:
			continue
		if bromeme_stat_excluded(int(key)):
			continue
		pool.append(int(key))
	if pool.empty():
		return 0
	return int(pool[randi() % pool.size()])


func bromeme_copy_effects(item) -> Array:
	var out: Array = []
	if item == null or not is_instance_valid(item):
		return out
	for effect in item.effects:
		if effect == null or not is_instance_valid(effect):
			continue
		# 镜子/金鱼/沙漏这类"依赖持有某件具体道具"的效果不能搬到卡上
		if bromeme_is_identity_effect(effect):
			continue
		var copy = effect.duplicate()
		if copy != null and is_instance_valid(copy):
			out.append(copy)
	return out


func bromeme_new_pick(kind: String, tag: String) -> UpgradeData:
	var pick := UpgradeData.new()
	pick.my_id = "bromeme_pick|%s|%s" % [kind, tag]
	pick.my_id_hash = Keys.generate_hash(pick.my_id)
	pick.value = 1
	pick.upgrade_id = pick.my_id
	pick.upgrade_id_hash = pick.my_id_hash
	return pick
