extends "res://effects/items/convert_stat_effect.gd"


export (int) var target_wave: int = 5


static func get_id() -> String:
	return "brolab_effect_convert_stats_at_wave"


func serialize() -> Dictionary:
	var serialized = .serialize()
	
	serialized["target_wave"] = target_wave
	
	return serialized


func deserialize_and_merge(effect: Dictionary) -> void:
	.deserialize_and_merge(effect)
	
	target_wave = effect.get("target_wave", 5)


func apply(player_index: int) -> void:
	var effect_array: Array = RunData.get_player_effect(Keys.generate_hash(custom_key), player_index)
	
	effect_array.push_back([key, value, pct_converted * 0.01, to_stat, to_value, target_wave])


func unapply(player_index: int) -> void:
	var effect_array: Array = RunData.get_player_effect(Keys.generate_hash(custom_key), player_index)
	
	for i in effect_array.size():
		var eff = effect_array[i]
		if eff[0] == key and eff[1] == value and eff[2] == (pct_converted * 0.01) and eff[3] == to_stat and eff[4] == to_value and eff[5] == target_wave:
			effect_array.remove(i)
			return


# effect_convert_stat_end_of_wave
func get_args(player_index: int) -> Array:
	var text_key_cache = text_key
	text_key = "effect_convert_stat_end_of_wave"
	var text_raw = get_text_raw(player_index)
	var args: = [
		"[color=#00ff00]%s[/color]" % [str(target_wave)],
		text_raw,
	]
	text_key = text_key_cache
	
	return args


func get_text_raw(player_index: int, colored: bool = true) -> String:
	var key_text = key.to_upper() if text_key.length() == 0 else text_key.to_upper()
	var args = .get_args(player_index)
	var signs = []
	
	for i in args:
		signs.push_back(get_sign(Sign.POSITIVE, value))

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
