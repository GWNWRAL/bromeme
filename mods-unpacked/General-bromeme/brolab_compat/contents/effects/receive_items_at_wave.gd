extends "res://items/global/effect.gd"


export var brolab_receive_item_id: String = "item_acid"
export var brolab_receive_item_wave: int = 5
export var brolab_receive_item_end_wave: int = -1
export (bool) var brolab_cursed_item: bool = false


static func get_id() -> String:
	return "brolab_effect_receive_item_at_wave"


func apply(player_index: int) -> void:
	RunData.get_player_effect(Keys.generate_hash(key), player_index).append([value, brolab_receive_item_id, brolab_receive_item_wave, curse_factor, brolab_cursed_item, brolab_receive_item_end_wave])


func unapply(player_index: int) -> void:
	var effect: Array = RunData.get_player_effect(Keys.generate_hash(key), player_index)
	var index: int = -1
	for i in effect.size():
		var entry = effect[i]
		if entry[3] == curse_factor and entry[4] == brolab_cursed_item and entry[5] == brolab_receive_item_end_wave:
			index = i
			break
	
	if not index == -1:
		effect.remove(index)


func serialize() -> Dictionary:
	var serialized = .serialize()
	
	serialized["brolab_receive_item_id"] = brolab_receive_item_id
	serialized["brolab_receive_item_wave"] = brolab_receive_item_wave
	serialized["brolab_cursed_item"] = brolab_cursed_item
	serialized["brolab_receive_item_end_wave"] = brolab_receive_item_end_wave
	
	return serialized


func deserialize_and_merge(effect: Dictionary) -> void:
	.deserialize_and_merge(effect)
	
	brolab_receive_item_id = effect.get("brolab_receive_item_id", "item_acid")
	brolab_receive_item_wave = effect.get("brolab_receive_item_wave", 5)
	brolab_cursed_item = effect.get("brolab_cursed_item", false)
	brolab_receive_item_end_wave = effect.get("brolab_receive_item_end_wave", -1)


func get_args(_player_index: int) -> Array:
	var item_data = ItemService.get_element(ItemService.items, Keys.generate_hash(brolab_receive_item_id))
	
	var item_name: String = ""
	if not item_data == null:
		item_name = tr(item_data.name)
	else:
		# 查不到物品时也要走 tr()：这个名字 key 由 mod 自己注册
		# （<my_id>.to_upper()），直接吐 id 会在描述里显示成 ITEM_XXX。
		item_name = tr(brolab_receive_item_id.to_upper())
	if brolab_cursed_item:
		item_name += "([color=#%s]%s[/color])" % [Utils.CURSE_COLOR.to_html(), tr("BROLAB_CURSED_TEXT")]
	
	return [
		str(brolab_receive_item_wave) if brolab_receive_item_end_wave <= 0 else "%d ~ %d" % [brolab_receive_item_wave, brolab_receive_item_end_wave],
		item_name,
		str(value)
	]
