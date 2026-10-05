extends "res://main.gd"


var brolab_midas_timers: Dictionary = {}


func _ready():
	for player_index in _players.size():
		var player = _players[player_index]
		
		# Handle Midas
		# value, brolab_midas_count, brolab_midas_multiplier, curse_factor
		var midas_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_midas_hand"), player_index)
		
		if not midas_effects.empty():
			if not brolab_midas_timers.has(player_index):
				brolab_midas_timers[player_index] = []
			
			for midas_effect in midas_effects:
				var timer: Timer = Timer.new()
				timer.one_shot = false
				timer.wait_time = midas_effect[0]
				timer.name = "BrolabMidasTimer"
				player.add_child(timer)
				timer.start()
				timer.connect("timeout", self, "_on_brolab_midas_timer_timeout", [midas_effect[1], midas_effect[2], player_index])
				brolab_midas_timers[player_index].push_back(timer)
		
		var need_reset_player: bool = false
		# value, brolab_receive_item_id, brolab_receive_item_wave, curse_factor, is_cursed, end_wave
		var receive_item_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_receive_item_at_wave"), player_index)
		if not receive_item_effects.empty():
			# Cache
			var _item = ItemService.get_item_from_id(Keys.generate_hash("item_acid"))
			
			var remove_array: Array = []
			for receive_item_effect in receive_item_effects:
				if receive_item_effect[2] <= RunData.current_wave:
					var end_wave = -1 
					if receive_item_effect.size() > 5:
						end_wave = receive_item_effect[5]
					if end_wave <= 0:
						remove_array.push_back(receive_item_effect)
					elif end_wave < RunData.current_wave:
						remove_array.push_back(receive_item_effect)
						continue
					
					var item_data = ItemService.get_element(ItemService.items, Keys.generate_hash(receive_item_effect[1]))
					if not item_data == null:
						var is_cursed: bool = receive_item_effect[4]
						var dlc = null
						var actual_item_data = item_data
						
						if is_cursed:
							dlc = ProgressData.get_dlc_data("abyssal_terrors")	
						
						for i in receive_item_effect[0]:
							if dlc:
								actual_item_data = dlc.curse_item(item_data, player_index, false)
							if actual_item_data.my_id_hash == Keys.item_axolotl_hash:
								for effect in actual_item_data.effects:
									if effect is SwapMaxMinStatEffect:
										effect.stats_swapped = effect._find_min_max_stat_keys(player_index)
							RunData.add_item(actual_item_data, player_index)
							
						_floating_text_manager.display_icon(receive_item_effect[0], item_data.icon, _floating_text_manager.stat_pos_sounds, _floating_text_manager.stat_neg_sounds, player.global_position - Vector2(0, 50), _floating_text_manager.direction, -10.0)
						
						need_reset_player = true
			
			for remove_entry in remove_array:
				receive_item_effects.erase(remove_entry)
		
		# value, brolab_receive_stat_key, brolab_receive_stat_wave, curse_factor, end_wave
		var receive_stat_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_receive_stat_at_wave"), player_index)
		if not receive_stat_effects.empty():
			var remove_array: Array = []
			
			for receive_stat_effect in receive_stat_effects:
				if receive_stat_effect[2] <= RunData.current_wave:
					var end_wave = -1 
					if receive_stat_effect.size() > 4:
						end_wave = receive_stat_effect[4]
					if end_wave <= 0:
						remove_array.push_back(receive_stat_effect)
					elif end_wave < RunData.current_wave:
						remove_array.push_back(receive_stat_effect)
						continue
					
					var effects: Dictionary = RunData.get_player_effects(player_index)
					if effects.has(Keys.generate_hash(receive_stat_effect[1])):
						RunData.add_stat(Keys.generate_hash(receive_stat_effect[1]), receive_stat_effect[0], player_index)
						
						need_reset_player = true
			
			for remove_entry in remove_array:
				receive_stat_effects.erase(remove_entry)
		
		# [key, value, starting_wave, end_wave]
		var stats_end_of_wave_after_wave: Array = RunData.get_player_effect(Keys.generate_hash("brolab_stats_end_of_wave_after_wave"), player_index)
		if not stats_end_of_wave_after_wave.empty():
			var remove_array: = []
			for j in stats_end_of_wave_after_wave.size():
				var eff = stats_end_of_wave_after_wave[j]
				if RunData.current_wave == int(eff[2]):
					var effect_items: Array = RunData.get_player_effect(Keys.generate_hash("stats_end_of_wave"), player_index)
					var has_effect: bool = false
					for existing_item in effect_items:
						if existing_item[0] == eff[0]:
							existing_item[1] += int(eff[1])
							has_effect = true
							break
					if not has_effect:
						effect_items.append([eff[0], int(eff[1])]) 
				if RunData.current_wave == (int(eff[3]) + 1):
					var effect_items: Array = RunData.get_player_effect(Keys.generate_hash("stats_end_of_wave"), player_index)
					for i in effect_items.size():
						var effect_item = effect_items[i]
						if effect_item[0] == eff[0]:
							effect_item[1] -= eff[1]
							if effect_item[1] == 0:
								effect_items.remove(i)
							break
					
					remove_array.push_back(eff)
			for j in remove_array:
				stats_end_of_wave_after_wave.erase(j)
		
		if need_reset_player:
			player.update_player_stats(true)

func _on_WaveTimer_timeout() -> void:
	._on_WaveTimer_timeout()
	
	for timers in brolab_midas_timers.values():
		for timer in timers:
			if is_instance_valid(timer):
				timer.queue_free()
	
	# key, value, pct_converted, to_stat, to_value, target_wave
	for player_index in _players.size():
		var current_wave = RunData.current_wave
		for eff in RunData.get_player_effect(Keys.generate_hash("brolab_effect_convert_stats_at_wave"), player_index):
			if current_wave == int(eff[5]):
				var effects: Dictionary = RunData.get_player_effects(player_index)
				
				if (not eff[0] == "materials" and not effects.has(Keys.generate_hash(eff[0])) or (not eff[3] == "materials" and not effects.has(Keys.generate_hash(eff[3])))):
					continue
				
				var from_value = 0
				if not eff[0] == "materials":
					from_value = effects[Keys.generate_hash(eff[0])]
				else:
					from_value = RunData.get_player_gold(player_index)
				
				if from_value == 0:
					continue
				
				var from_value_pct = from_value * float(eff[2])
				var from_value_chunk = int(floor(from_value_pct / eff[1]))
				
				if from_value_chunk == 0:
					return
				
				from_value_pct = from_value_chunk * eff[1]
				var to_value = int(max(1, from_value_chunk * int(eff[4])))
				
				if not eff[0] == "materials":
					RunData.remove_stat(Keys.generate_hash(eff[0]), from_value_pct, player_index)
				else:
					RunData.remove_gold(from_value_pct, player_index)
				
				if not eff[3] == "materials":
					RunData.add_stat(Keys.generate_hash(eff[3]), to_value, player_index)
				else:
					RunData.add_gold(to_value, player_index)
				
				_players[player_index].update_player_stats(true)


func _on_brolab_midas_timer_timeout(count: int, multiplier: int, player_index: int) -> void:
	var all_enemies: Array = _entity_spawner.enemies
	if all_enemies.empty():
		return
	
	var enemies: Array = []
	if all_enemies.size() <= count:
		enemies = all_enemies
	
	if enemies.empty():
		var index_array: Array = []
		for i in all_enemies.size():
			index_array.append(i)
		
		for i in count:
			var index = Utils.get_rand_element(index_array)
			index_array.erase(index)
			
			enemies.append(all_enemies[index])
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.get("_pending_die"):
			continue
		
		var take_damage_args: = TakeDamageArgs.new(player_index)
		enemy.stats = enemy.stats.duplicate()
		enemy.stats.value *= multiplier
		enemy.take_damage(max(999999, enemy.max_stats.health * 3), take_damage_args)
	
