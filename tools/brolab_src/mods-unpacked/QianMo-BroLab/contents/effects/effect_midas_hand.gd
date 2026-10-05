extends "res://items/global/effect.gd"


export var brolab_midas_count: int = 5
export var brolab_midas_multiplier: int = 3


static func get_id() -> String:
	return "brolab_effect_midas_hand"


func apply(player_index: int) -> void:
	RunData.get_player_effect(Keys.generate_hash(key), player_index).append([value, brolab_midas_count, brolab_midas_multiplier, curse_factor])


func unapply(player_index: int) -> void:
	var effect: Array = RunData.get_player_effect(Keys.generate_hash(key), player_index)
	var index: int = -1
	for entry in effect:
		index += 1
		
		if entry[3] == curse_factor:
			break
	
	if not index == -1:
		effect.remove(index)


func serialize() -> Dictionary:
	var serialized = .serialize()
	
	serialized["brolab_midas_count"] = brolab_midas_count
	serialized["brolab_midas_multiplier"] = brolab_midas_multiplier
	
	return serialized


func deserialize_and_merge(effect: Dictionary) -> void:
	.deserialize_and_merge(effect)
	
	brolab_midas_count = effect.get("brolab_midas_count", 5)
	brolab_midas_multiplier = effect.get("brolab_midas_multiplier", 3)


func get_args(_player_index: int) -> Array:
	return [
		"[color=#00ff00]" + str(value) + "[/color]",
		"[color=#00ff00]" + str(brolab_midas_count) + "[/color]",
		"[color=#00ff00]" + str(brolab_midas_multiplier) + "[/color]"
	]
