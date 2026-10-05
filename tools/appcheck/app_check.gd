extends "res://items/global/item_appearance_data.gd"

# =============================================================================
#  外套外观：补一个"贴图来源名"，让动态生成的角色贴图能扛过读档
#
#  背景：原版 ItemAppearanceData.serialize() 存的是 `sprite.resource_path`：
#        if sprite != null:
#            serialized.sprite = sprite.resource_path
#    而本 mod 的角色外观贴图是**运行时**从 mod 里的 png 字节解码出来的
#    ImageTexture —— `resource_path` 是空串 → 存档里干脆连 sprite 字段都没有
#    → 读档后 load 不到图，**角色贴图消失**（用户报告的现象）。
#
#  为什么不走"给 png 补 .import/.stex"这条路：mod 是从 zip 挂成虚拟 res://，
#  磁盘上没有可写目录（实测写 .tres 缓存直接 err=19），离线造合法 .stex 风险也高。
#
#  所以这里换思路：额外存一个 `bromeme_sprite_stem`（贴图在 art/ 里的文件名），
#  读档时由 player_run_data 扩展按它把贴图**重新合成**并挂回外层数据。
# =============================================================================

var bromeme_sprite_stem: String = ""


func serialize() -> Dictionary:
	var serialized = .serialize()
	if bromeme_sprite_stem != "":
		serialized["bromeme_sprite_stem"] = bromeme_sprite_stem
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	bromeme_sprite_stem = String(serialized.get("bromeme_sprite_stem", ""))
