extends "res://items/global/effect.gd"


export (int) var starting_wave: int = 6
export (int) var end_wave: int = 19

var _brolab_custom_key = "brolab_stats_end_of_wave_after_wave"


static func get_id() -> String:
	return "brolab_effect_stats_end_of_wave_after_wave"


func serialize() -> Dictionary:
	var serialized = .serialize()
	
	serialized["starting_wave"] = starting_wave
	serialized["end_wave"] = end_wave
	
	return serialized


func deserialize_and_merge(effect: Dictionary) -> void:
	.deserialize_and_merge(effect)
	
	starting_wave = effect.get("starting_wave", 6)
	end_wave = effect.get("end_wave", 19)


func apply(player_index: int) -> void:
	if end_wave > 0 and starting_wave > end_wave:
		return
	
	var effect_array: Array = RunData.get_player_effect(Keys.generate_hash(_brolab_custom_key), player_index)
	
	for existing_item in effect_array:
		if existing_item[0] == key and existing_item[2] == starting_wave and existing_item[3] == end_wave:
			existing_item[1] += value
			return
	
	effect_array.push_back([key, value, starting_wave, end_wave])


func unapply(player_index: int) -> void:
	if end_wave > 0 and starting_wave > end_wave:
		return
	
	var has_effect: bool = false
	var effect_array: Array = RunData.get_player_effect(Keys.generate_hash(_brolab_custom_key), player_index)
	
	for i in effect_array.size():
		var eff = effect_array[i]
		if eff[0] == key and eff[2] == starting_wave and eff[3] == end_wave:
			has_effect = true
			eff[1] -= value
			if eff[1] == 0:
				effect_array.remove(i)
				break
	
	if has_effect and RunData.current_wave >= starting_wave and RunData.current_wave <= end_wave:
		.unapply(player_index)


func get_args(player_index: int) -> Array:
	var text_key_cache = text_key
	text_key = "effect_gain_stat_end_of_wave"
	var text_raw = get_text_raw(player_index)
	var args: = [
		"[color=#00ff00]%s[/color]" % [str(starting_wave)],
		text_raw if end_wave < 1 else text_raw + ", " + tr("BROLAB_EFFECT_STATS_END_OF_WAVE_BEFORE_WAVE").replace("{0}", str(end_wave)),
	]
	text_key = text_key_cache
	
	return args


func get_text_raw(player_index: int, colored: bool = true) -> String:
	var key_text = key.to_upper() if text_key.length() == 0 else text_key.to_upper()
	var args = .get_args(player_index)
	var signs = []
	
	for i in args:
		signs.push_back(get_sign(effect_sign, value))

	if not _custom_args_added:
		_add_custom_args()
		_custom_args_added = true

	for custom_arg in custom_args:
		var i = custom_arg.arg_index
		if i >= args.size():
			for j in (i - args.size()) + 1:
				args.push_back("")
				signs.push_back(Sign.NEUTRAL)

		args[i] = get_arg_value(custom_arg, args[i], player_index)
		signs[i] = get_sign(custom_arg.arg_sign, int(args[i]))
		args[i] = get_formatted(custom_arg.arg_format, args[i], custom_arg.arg_value)
	
	return Text.text(key_text, args, [] if !colored else signs)
