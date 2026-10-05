extends "res://items/global/effect.gd"


export var brolab_receive_stat_key: String = "stat_max_hp"
export var brolab_receive_stat_wave: int = 5
export var brolab_receive_stat_end_wave: int = -1


static func get_id() -> String:
	return "brolab_effect_receive_stat_at_wave"


func apply(player_index: int) -> void:
	RunData.get_player_effect(Keys.generate_hash(key), player_index).append([value, brolab_receive_stat_key, brolab_receive_stat_wave, curse_factor, brolab_receive_stat_end_wave])


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
	
	serialized["brolab_receive_stat_key"] = brolab_receive_stat_key
	serialized["brolab_receive_stat_wave"] = brolab_receive_stat_wave
	serialized["brolab_receive_stat_end_wave"] = brolab_receive_stat_end_wave
	
	return serialized


func deserialize_and_merge(effect: Dictionary) -> void:
	.deserialize_and_merge(effect)
	
	brolab_receive_stat_key = effect.get("brolab_receive_stat_key", "stat_max_hp")
	brolab_receive_stat_wave = effect.get("brolab_receive_stat_wave", 5)
	brolab_receive_stat_end_wave = effect.get("brolab_receive_stat_end_wave", -1)


func get_args(player_index: int) -> Array:
	# Cache once
	var effects: Dictionary = RunData.get_player_effects(player_index)
	var has_effect: bool = effects.has(brolab_receive_stat_key)
	
	return [
		str(brolab_receive_stat_wave) if brolab_receive_stat_end_wave <= 0 else "%d ~ %d" % [brolab_receive_stat_wave, brolab_receive_stat_end_wave],
		tr(brolab_receive_stat_key.to_upper()),
		str(value)
	]
