extends "res://ui/menus/shop/base_shop.gd"


func buy_item(item_data, player_index)->void :
	var brolab_were_items_duplicated = false
	
	# Fix mirror effect
	var effects = RunData.get_player_effects(player_index)
	var mirror_count = effects[Keys.duplicate_item_hash] if effects.has(Keys.duplicate_item_hash) else 0
	if mirror_count and not mirror_count.empty():
		var brolab_player_items = RunData.get_player_items_ref(player_index)
		var brolab_hourglass_items_index_dict: = {}
		var brolab_mirror_count: = []
		for item_index in brolab_player_items.size():
			var player_item = brolab_player_items[item_index]
			if player_item.my_id.begins_with("item_brolab_") or player_item.my_id.begins_with("character_brolab_"):
				var hourglass_effect_index: = []
				var item_effects = player_item.effects
				for i in item_effects.size():
					var eff = item_effects[i]
					if eff.custom_key_hash == Keys.duplicate_item_hash:
						hourglass_effect_index.push_back(i)
						if eff.value > 0:
							brolab_mirror_count.push_back([eff.key_hash, eff.value])
				if not hourglass_effect_index.empty():
					var new_effects = item_effects.duplicate()
					var new_item_data = player_item.duplicate()
					hourglass_effect_index.invert()
					for i in hourglass_effect_index:
						new_effects.remove(i)
					new_item_data.effects = new_effects
					
					brolab_hourglass_items_index_dict[item_index] = new_item_data
		# replace brolab hourglass item with no hourglass effect new item
		if not brolab_hourglass_items_index_dict.empty():
			for index in brolab_hourglass_items_index_dict:
				brolab_player_items[index] = brolab_hourglass_items_index_dict[index]
		# remove non mirror item count
		for count in brolab_mirror_count:
			var remaining_item_count: int = RunData.get_remaining_max_nb_item(item_data, player_index)
			var normal_buy_count: = 1
			var duplicated_count: = min(count[1], remaining_item_count - normal_buy_count)
			
			if duplicated_count <= 0:
				continue
			
			brolab_were_items_duplicated = true
			
			for _nb in duplicated_count:
				RunData.add_item(item_data, player_index)
			
			for duplicate_array in effects[Keys.duplicate_item_hash]:
				if duplicate_array[0] == count[0]:
					if duplicate_array[1] >= duplicated_count:
						duplicate_array[1] -= duplicated_count
						
						if duplicate_array[1] <= 0:
							effects[Keys.duplicate_item_hash].erase(duplicate_array)
					else:
						duplicated_count -= duplicate_array[1]
						effects[Keys.duplicate_item_hash].erase(duplicate_array)
	
	var brolab_player_gear_container = _get_gear_container(player_index)
	if brolab_were_items_duplicated:
		brolab_player_gear_container.set_items_data(RunData.get_player_items(player_index))
	
	.buy_item(item_data, player_index)


func _on_GoButton_pressed(player_index):
	._on_GoButton_pressed(player_index)
	
	# Fix crash when some items use hourglass effect but not hourglass
	for player_index in RunData.get_player_count():
		var effects = RunData.get_player_effects(player_index)
		var hourglass_count = effects[Keys.item_hourglass_hash] if effects.has(Keys.item_hourglass_hash) else 0
		if hourglass_count > 0:
			var brolab_player_items = RunData.get_player_items_ref(player_index)
			var brolab_hourglass_items_index_dict: = {}
			var brolab_wave_reset_count: = 0
			for item_index in brolab_player_items.size():
				var player_item = brolab_player_items[item_index]
				if player_item.my_id.begins_with("item_brolab_") or player_item.my_id.begins_with("character_brolab_"):
					var hourglass_effect_index: = []
					var item_effects = player_item.effects
					for i in item_effects.size():
						var eff = item_effects[i]
						if eff.key_hash == Keys.item_hourglass_hash:
							hourglass_effect_index.push_back(i)
							if eff.value > 0:
								brolab_wave_reset_count += eff.value
					if not hourglass_effect_index.empty():
						var new_effects = item_effects.duplicate()
						var new_item_data = player_item.duplicate()
						hourglass_effect_index.invert()
						for i in hourglass_effect_index:
							new_effects.remove(i)
						new_item_data.effects = new_effects
						
						brolab_hourglass_items_index_dict[item_index] = new_item_data
			# replace brolab hourglass item with no hourglass effect new item
			if not brolab_hourglass_items_index_dict.empty():
				for index in brolab_hourglass_items_index_dict:
					brolab_player_items[index] = brolab_hourglass_items_index_dict[index]
			# remove non hourglass item count
			effects[Keys.item_hourglass_hash] -= brolab_wave_reset_count
			RunData.current_wave -= brolab_wave_reset_count
