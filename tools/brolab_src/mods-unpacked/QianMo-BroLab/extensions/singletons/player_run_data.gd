extends "res://singletons/player_run_data.gd"


static func init_effects()->Dictionary:
	var all_effects = .init_effects()
	var new_effects: = {
		Keys.generate_hash("brolab_effect_receive_item_at_wave"): [],
		Keys.generate_hash("brolab_effect_receive_stat_at_wave"): [],
		Keys.generate_hash("brolab_effect_midas_hand"): [],
		Keys.generate_hash("brolab_stats_end_of_wave_after_wave"): [],
		Keys.generate_hash("brolab_effect_convert_stats_at_wave"): [],
	}

	all_effects.merge(new_effects)

	return all_effects
