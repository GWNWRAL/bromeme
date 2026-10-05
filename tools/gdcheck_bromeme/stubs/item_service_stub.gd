extends Resource

# 语法自检用的 ItemService stub。
# 只要 extensions/item_service_bromeme.gd 里引用了被扩展类的成员（这里是 TierData 枚举
# 和 _tiers_data），stub 就必须也有，否则自检会报
# "identifier X isn't declared in the current scope"。

enum TierData {
	ALL_ITEMS,
	ITEMS,
	WEAPONS,
	CONSUMABLES,
	UPGRADES,
	MIN_WAVE,
	BASE_CHANCE,
	WAVE_BONUS_CHANCE,
	MAX_CHANCE,
}

var items := []
var characters := []
var weapons := []
var _tiers_data := [
	[[], [], [], [], [], 0, 1.0, 0.0, 1.0],
	[[], [], [], [], [], 0, 0.0, 0.06, 0.6],
	[[], [], [], [], [], 2, 0.0, 0.02, 0.25],
	[[], [], [], [], [], 6, 0.0, 0.0023, 0.08],
]


func get_pool(_item_tier: int, _type: int) -> Array:
	return []


func get_upgrades(level: int, number: int, old_upgrades: Array, player_index: int) -> Array:
	return []


func get_stat_small_icon(_h: int) -> Texture:
	return null


func get_item_from_id(_h: int):
	return null
