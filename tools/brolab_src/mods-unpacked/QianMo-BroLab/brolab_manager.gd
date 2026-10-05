class_name BrolabManager
extends Node


const CONFIG_NAME: = "brolab_config"
const MOD_NAME: = "QianMo-BroLab"
const LOG_NAME: = "BroLab"
const ENUMS: = {
	"storage_method": {
		Effect.StorageMethod.SUM: "Sum",
		Effect.StorageMethod.KEY_VALUE: "Key Value",
		Effect.StorageMethod.REPLACE: "Replace",
		Effect.StorageMethod.APPEND_KEY: "Append Key",
		Effect.StorageMethod.APPEND_KEY_VALUE: "Append Key Value",
	},
	"effect_sign": {
		Effect.Sign.POSITIVE: "Positive",
		Effect.Sign.NEGATIVE: "Negative",
		Effect.Sign.NEUTRAL: "Neutral",
		Effect.Sign.FROM_VALUE: "From Value",
		Effect.Sign.FROM_ARG: "From Arg",
		Effect.Sign.OVERRIDE: "Override",
	},
}
const DEFAULT_SETTINGS: = {
	"BROLAB_ENABLE_SPECIAL_MECHANISMS": false
}

var TYPE_WEAPON_STATS: int = TYPE_MAX + 1
var TYPE_ENUM: int = TYPE_MAX + 2

var DEFAULT_CHARACTER_ICON: StreamTexture
var DEFAULT_ITEM_ICON: StreamTexture
var DEFAULT_CHARACTER_APPERANCES: Array
var DEFAULT_STARTING_WEAPONS: Array

var BASE_SAVE_PATH: String = ""

var mod_list: Dictionary = {}

var ModsConfigInterface = null
var config = null

var _current_settings: Dictionary = DEFAULT_SETTINGS.duplicate()


func _ready():
	ModsConfigInterface = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
#	if ModsConfigInterface:
	var configs = ModLoaderConfig.get_configs(MOD_NAME)
	if configs.has(CONFIG_NAME):
		config = ModLoaderConfig.get_config(MOD_NAME, CONFIG_NAME)
	else:
		config = ModLoaderConfig.create_config(MOD_NAME, CONFIG_NAME, DEFAULT_SETTINGS)
	
	if config:
		var _error_config = ModLoaderConfig.update_config(config)
		var data = config.data
		
		for key in _current_settings.keys():
			_current_settings[key] = data[key]
		
	if ModsConfigInterface:
		ModsConfigInterface.connect("setting_changed", self, "_on_setting_changed")
		call_deferred("_init_settings")


func _init_settings() -> void:
	for key in _current_settings.keys():
		ModsConfigInterface.on_setting_changed(key, _current_settings[key], MOD_NAME)


func get_settings() -> Dictionary:
	return _current_settings


func _on_setting_changed(setting_name, value, mod_name)->void :
	if mod_name == MOD_NAME:
		_current_settings[setting_name] = value
		
		if config:
			config.data[setting_name] = value
			var _error_config = ModLoaderConfig.update_config(config)


func _init()->void :
	name = "BrolabManager"
	
	refresh_mod_list()
	
#	call_deferred("init_save_paths")
	call_deferred("init_resource")


func init_resource()->void :
	DEFAULT_CHARACTER_ICON = load("res://items/characters/well_rounded/well_rounded_icon.png")
	DEFAULT_ITEM_ICON = load("res://items/all/acid/acid_icon.png")
	DEFAULT_CHARACTER_APPERANCES = [
		load("res://items/characters/well_rounded/well_rounded_eyes_appearance.tres"),
		load("res://items/characters/well_rounded/well_rounded_mouth_appearance.tres"),
	]
	DEFAULT_STARTING_WEAPONS = [
		load("res://weapons/melee/cactus_mace/1/cactus_mace_data.tres"),
		load("res://weapons/melee/chopper/1/chopper_data.tres"),
		load("res://weapons/melee/claw/1/claw_data.tres"),
		load("res://weapons/melee/dagger/1/dagger_data.tres"),
		load("res://weapons/melee/ghost_axe/1/ghost_axe_data.tres"),
		load("res://weapons/melee/hand/1/hand_data.tres"),
		load("res://weapons/melee/pruner/1/pruner_data.tres"),
		load("res://weapons/melee/screwdriver/1/screwdriver_data.tres"),
		load("res://weapons/melee/wrench/1/wrench_data.tres"),
		load("res://weapons/ranged/crossbow/1/crossbow_data.tres"),
		load("res://weapons/ranged/double_barrel_shotgun/1/double_barrel_shotgun_data.tres"),
		load("res://weapons/ranged/shredder/1/shredder_data.tres"),
		load("res://weapons/ranged/slingshot/1/slingshot_data.tres"),
		load("res://weapons/ranged/taser/1/taser_data.tres"),
		load("res://weapons/ranged/wand/1/wand_data.tres"),
	]


# (item_data)
func add_item(item_data, type: String, force_reload: bool = false, not_reload: bool = false)->void :
	add_items([item_data], type, force_reload, not_reload)


func add_items(item_datas: Array, type: String, force_reload: bool = false, not_reload: bool = false)->void :
	var need_reload_gamefile: = false
	
	for item_data in item_datas:
		var id_hash = Keys.generate_hash(item_data.my_id)
		if type == "character":
			ItemService.characters.append(item_data)
			
			if not ProgressData.characters_unlocked.has(id_hash):
				ProgressData.characters_unlocked.append(id_hash)
			
			var has_diff_info: bool = false
			for diff_info in ProgressData.difficulties_unlocked:
				if id_hash == diff_info.character_id_hash:
					has_diff_info = true
					break
			if not has_diff_info:
				var character_diff_info = CharacterDifficultyInfo.new(item_data.my_id)
				for zone in ZoneService.zones:
					if zone.unlocked_by_default:
						character_diff_info.zones_difficulty_info.append(ZoneDifficultyInfo.new(zone.my_id))
				
				set_max_selectable_difficulty(character_diff_info)
				ProgressData.difficulties_unlocked.append(character_diff_info)
			
			need_reload_gamefile = true
		else:
			ItemService.items.append(item_data)
			
			if item_data.unlocked_by_default and not ProgressData.items_unlocked.has(id_hash):
				ProgressData.items_unlocked.append(id_hash)
			
			ItemService.init_unlocked_pool()
			
			need_reload_gamefile = true
		
	if (need_reload_gamefile or force_reload) and not not_reload:
		ProgressData.load_game_file()


func set_max_selectable_difficulty(difficulty)->void :
	var overall_max_selectable_difficulty: = 0
	for difficulty_info in ProgressData.difficulties_unlocked:
		for zone_difficulty_info in difficulty_info.zones_difficulty_info:
			overall_max_selectable_difficulty = int(max(overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for zone_difficulty_info in difficulty.zones_difficulty_info:
		if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
			zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty


func init_save_paths()->void :
	ProgressData.init_save_paths()
	
	var save_path: String = ProgressData.SAVE_PATH
	
	var last_splitter: = save_path.find_last("/")
	var base_save_path: = save_path.left(last_splitter).get_base_dir()
	
	BASE_SAVE_PATH = base_save_path.plus_file("brolab")
	
	# Prevent crash when character nil
	var saved_file: File = File.new()
	var error_open = saved_file.open(save_path, File.READ)
	
	if error_open == OK:
		var text: String = saved_file.get_as_text()
		if text and not text.empty():
			var need_to_fix: = false
			var saved_v2_json = parse_json(text)
			
			if saved_v2_json and typeof(saved_v2_json) == TYPE_DICTIONARY:
				var saved_run_state = saved_v2_json.get("current_run_state") if saved_v2_json.has('current_run_state') else null
				if not saved_run_state == null and saved_run_state is Dictionary:
					if saved_run_state.has("has_run_state") and saved_run_state.has_run_state:
		#				if not saved_run_state.has("current_character") or saved_run_state.current_character == null:
		#					saved_v2_json.current_run_state['current_character'] = "character_well_rounded"
		#					need_to_fix = true
						if saved_run_state.has("players_data"):
							for i in saved_run_state.players_data.size():
								var player_data = saved_run_state.players_data[i]
								if not player_data.has("current_character") or player_data.current_character == null:
									saved_v2_json.current_run_state.players_data[i]['current_character'] = "character_well_rounded"
									need_to_fix = true
				
				if need_to_fix:
					var new_file: File = File.new()
					var error_open_new_file = new_file.open(save_path, File.WRITE)
					
					if error_open_new_file == OK:
						var save_json: = JSON.print(saved_v2_json, "  ", true)
						new_file.store_string(save_json)
						new_file.close()
	
	saved_file.close()
	
#	call_deferred("deffered_load_game")


func deffered_load_game()->void :
	ProgressData.load_game_file()


func fix_lag_save(reload_game_file: bool = true, save_path: String = ProgressData.SAVE_PATH) -> void:
	var character_id_diff_dict: Dictionary = {}
	var raw_difficulties_unlocked: Array = []
	var raw_saved_dict: Dictionary = {}
	
	if reload_game_file:
		raw_difficulties_unlocked = ProgressData.difficulties_unlocked
	else:
		pass
#		var file: File = File.new()
#		var error_open = file.open(save_path, File.READ)
#		if error_open == OK:
#			raw_saved_dict = parse_json(file.get_as_text())
#			raw_difficulties_unlocked = raw_saved_dict.get("difficulties_unlocked", [])
#		file.close()
	
	for diff_info in raw_difficulties_unlocked:
		var character_id = diff_info.character_id
		
		if not character_id_diff_dict.has(character_id):
			character_id_diff_dict[character_id] = [diff_info]
		else:
			character_id_diff_dict[character_id].append(diff_info)
	
	var new_difficulities_unlocked: Array = []
	var need_fix: bool = false
	var fixed_count: int = 0
	for character_id in character_id_diff_dict.keys():
		var diff_info_array: Array = character_id_diff_dict[character_id]
		var count = diff_info_array.size()
		
		if count > 1:
			need_fix = true
			
			# zone_id -> zone_info
			var max_beaten_zone_info_dict: Dictionary = {}
			for i in diff_info_array[0].zones_difficulty_info.size():
				var zone_info = diff_info_array[0].zones_difficulty_info[i]
				var zone_id = zone_info.zone_id
				
				if not max_beaten_zone_info_dict.has(zone_id):
					max_beaten_zone_info_dict[zone_id] = zone_info
				else:
					var max_beaten_zone_info = max_beaten_zone_info_dict[zone_id]
					if max_beaten_zone_info.max_difficulty_beaten.difficulty_value < zone_info.max_difficulty_beaten.difficulty_value:
						max_beaten_zone_info_dict[zone_id] = zone_info
			for diff_info in diff_info_array:
				var zone_info_array: Array = diff_info.zones_difficulty_info
				
				for i in zone_info_array.size():
					var zone_info = zone_info_array[i]
					var zone_id = zone_info.zone_id
					
					if not max_beaten_zone_info_dict.has(zone_id):
						max_beaten_zone_info_dict[zone_id] = zone_info
					
					var max_beaten_zone_info = max_beaten_zone_info_dict[zone_id]
					if max_beaten_zone_info.max_difficulty_beaten.difficulty_value < zone_info.max_difficulty_beaten.difficulty_value:
						max_beaten_zone_info_dict[zone_id] = zone_info
			
			var new_zone_info_array: Array = []
			for zone_id in max_beaten_zone_info_dict.keys():
				new_zone_info_array.append(max_beaten_zone_info_dict[zone_id])
			
			var new_diff_info = CharacterDifficultyInfo.new()
			new_diff_info.character_id = character_id
			new_diff_info.zones_difficulty_info = new_zone_info_array
			
			new_difficulities_unlocked.append(new_diff_info)
			
			fixed_count += 1
		else:
			new_difficulities_unlocked.append(diff_info_array[0])
	
	if need_fix:
#		ModLoaderLog.info("Got %d difficulties_unlocked entry" % [character_id_diff_dict.size()], "QianMo-Brolab")
		
		if reload_game_file:
			ProgressData.difficulties_unlocked = new_difficulities_unlocked
			ProgressData.call_deferred("save")
		else:
			pass
#			var save_file: File = File.new()
#			var error_open = save_file.open(save_path, File.WRITE)
#			if error_open == OK:
#				var save_object = raw_saved_dict
#				var serialized_new_difficulities_unlocked: Array = []
#				for diff in new_difficulities_unlocked:
#					serialized_new_difficulities_unlocked.append(diff.serialize())
#
#				save_object["difficulties_unlocked"] = serialized_new_difficulities_unlocked
#
#				var sort_keys: = true
#				var save_json: = JSON.print(save_object, "  ", sort_keys)
#				save_file.store_string(save_json)
#				save_file.close()
#		ProgressData.load_game_file()
		
#		ModLoaderLog.info("Fixed %d difficulties_unlocked entry" % [fixed_count], "QianMo-Brolab")


func is_valid_array(from_array: Array)->bool :
	if from_array == null or from_array.empty():
		return false
	
	var is_valid: bool = true
	for item in from_array:
		if not (item is String or 
			item is int or 
			item is float or
			item is Array):
			is_valid = false
			break
		if item is Array:
			for item_item in item:
				if not (item_item is String or 
					item_item is int or 
					item_item is float):
					is_valid = false
					break
			if not is_valid:
				break
	
	return is_valid


func get_json_dict_from_file(path:String)->Dictionary :
	var file: = File.new()
	
	if not file.file_exists(path):
		file.close()
		return {}
	
	var error: = file.open(path, File.READ)
	if not error == OK:
		ModLoaderLog.error("Error opening file. Code: %s" % error, LOG_NAME)
		return {}
	
	var content: = file.get_as_text()
	var parse_result: = JSON.parse(content)
	if not parse_result.error == OK:
		ModLoaderLog.error("Error parsing json. Code: %s, Json: %s" % [parse_result.error, content], LOG_NAME)
		
		return {}
	
	return parse_result.result


func save_buffer(save_buffer: PoolByteArray, file_name: String, child_dir: String = "", base_dir: String = BASE_SAVE_PATH)->bool :
	var file_directory: = base_dir.plus_file(child_dir)
	var dir: = Directory.new()
	
	if not dir.dir_exists(file_directory):
		var makedir_error: = dir.make_dir_recursive(file_directory)
		if not makedir_error == OK:
			ModLoaderLog.info("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false
	
	var file: = File.new()
	var filepath: = file_directory.plus_file(file_name)
	var fileopen_error: = file.open(filepath, File.WRITE)
	
	if not fileopen_error == OK:
		ModLoaderLog.info("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [fileopen_error, filepath], LOG_NAME)
		return false
	
	file.store_buffer(save_buffer)
	file.close()
	
	return true


func save_file(save_string: String, file_name: String, base_dir: String = BASE_SAVE_PATH)->bool :
	var file_directory: = base_dir
	var dir: = Directory.new()
	
	if not dir.dir_exists(file_directory):
		var makedir_error: = dir.make_dir_recursive(file_directory)
		if not makedir_error == OK:
			ModLoaderLog.info("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false
	
	var file: = File.new()
	var filepath: = file_directory.plus_file(file_name)
	var fileopen_error: = file.open(filepath, File.WRITE)
	
	if not fileopen_error == OK:
		ModLoaderLog.info("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [fileopen_error, filepath], LOG_NAME)
		return false
	
	file.store_string(save_string)
	file.close()
	
	return true


func delete_file(file_name: String, child_directory: String = "", file_directory: String = BASE_SAVE_PATH)->bool :
	var dir: = Directory.new()
	var file_path: = file_directory.plus_file(child_directory).plus_file(file_name)
	
	var error_remove: = dir.remove(file_path)
	if not error_remove == OK:
		ModLoaderLog.info("File remove failed: %s (%s)" % [file_path, error_remove], LOG_NAME)
		return false
	
	return true


func walk_directory(folder_path: String = BASE_SAVE_PATH)->Dictionary :
	var dir: = Directory.new()
	var dir_open_error: = dir.open(folder_path)
	if not dir_open_error == OK:
		ModLoaderLog.info("Can't open mod folder %s (Error: %s)" % [folder_path, dir_open_error], LOG_NAME)
		return {}
	var dir_listdir_error: = dir.list_dir_begin()
	if not dir_listdir_error == OK:
		ModLoaderLog.info("Can't read mod folder %s (Error: %s)" % [folder_path, dir_listdir_error], LOG_NAME)
		return {}
	
	var datas: Dictionary = {}
	
	while true:
		var file_name: = dir.get_next()
		
		if file_name == "":
			break
		if not file_name.get_extension() == "json":
			continue
		if dir.current_is_dir():
			continue
		
		var data: Dictionary = get_json_dict_from_file(BASE_SAVE_PATH.plus_file(file_name))
		if (data.has("my_id") 
			and data.has("name")
			and data.has("price")
			and data.has("tier")
			and data.has("item_type")
			and data.has("datas")):
			datas[file_name] = data
	
	return datas


func get_tier_from_number(tier_number: int = 0)->int :
	match tier_number:
		0:
			return Tier.COMMON
		1:
			return Tier.UNCOMMON
		2:
			return Tier.RARE
		3:
			return Tier.LEGENDARY
		_:
			return Tier.COMMON


func deserialize_item_data_from_data(value: Dictionary, item_type: int = 0) :
	var item_data = null
	
	if value.has("item_type"):
		item_type = value.item_type
	
	var icon = null
	match item_type:
		0:
			item_data = CharacterData.new()
			item_data.max_nb = -1
			item_data.wanted_tags = value.wanted_tags
			item_data.tier = Tier.COMMON
			item_data.item_appearances = DEFAULT_CHARACTER_APPERANCES
			item_data.unlocked_by_default = true
			icon = DEFAULT_CHARACTER_ICON
			
			var starting_weapons = []
			if value.has("starting_weapons") and not value.starting_weapons.empty():
				var saved_starting_weapons_id_array: Array = value.starting_weapons
				for weapon_data in ItemService.weapons:
					if weapon_data.my_id in saved_starting_weapons_id_array:
						starting_weapons.append(weapon_data)
					if starting_weapons.size() >= saved_starting_weapons_id_array.size():
						break
			item_data.starting_weapons = starting_weapons if not starting_weapons.empty() else DEFAULT_STARTING_WEAPONS
		1:
			item_data = ItemData.new()
			item_data.max_nb = value.max_nb
			item_data.tags = value.tags
			item_data.tier = get_tier_from_number(value.tier)
			item_data.unlocked_by_default = true
			item_data.can_be_looted = true if not value.get("unlocked_by_default", 0) == 1 else false
			
			icon = DEFAULT_ITEM_ICON
			
	if not item_data == null:
		if value.has("relative_icon_path"):
			var image: = Image.new()
			var error_load_image = image.load(BASE_SAVE_PATH.plus_file(value["relative_icon_path"]))
			if error_load_image == OK:
				image.resize(96, 96)
				var texture: = ImageTexture.new()
				texture.create_from_image(image)
				icon = texture
		
		item_data.icon = icon
		item_data.my_id = value.my_id
		item_data.name = value.name
		item_data.value = value.price
		
		if value.has("is_cursed"):
			item_data.is_cursed = value.is_cursed
		
		# Deserialize Effects
		var effects: Array = deserialize_effects_from_data(value)
		
		item_data.effects = effects
	
	return item_data


func deserialize_effect_from_data(data: Dictionary)->Resource :
	var base_resource_path: String = data.get("base_resource_path")
	if base_resource_path == null:
		return null
	var changed_key_values: Dictionary = data.get("changed_key_values")
	if changed_key_values == null:
		return null
	
	var is_from_mod: = false
	if base_resource_path.get_slice("/", 2) == "mods-unpacked":
		is_from_mod = true
	
	if is_from_mod:
		var mod_name: = base_resource_path.get_slice("/", 3)
		if mod_list.has(mod_name):
			if not mod_list[mod_name].is_active:
				return null
#		elif mod_name == MOD_NAME and not _current_settings["BROLAB_ENABLE_SPECIAL_MECHANISMS"]:
#			return null
	
	var effect = load(base_resource_path)
	if effect == null:
		return null
	
	if changed_key_values.empty():
		return effect
	
	var duplicated_effect = effect.duplicate()
	for changed_key in changed_key_values.keys():
#			var changed_value = changed_key_values[changed_key]
#			if changed_key == "key" and changed_value.to_lower().begins_with("stat_") and not default_effects_keys.has(changed_value):
#				continue
		if not changed_key.ends_with("_RESOURCE"):
			duplicated_effect.set(changed_key, changed_key_values[changed_key])
		else:
			var val: Dictionary = changed_key_values[changed_key]
			if not val == null and not val.empty():
				if val.has("base_resource_path") and val.has("changed_key_values"):
					var child_resource_changed_key_values: Dictionary = val.changed_key_values
					if child_resource_changed_key_values == null or child_resource_changed_key_values.empty():
						return effect
					var child_resource_path: String = val.base_resource_path
					var child_resource: Resource = load(child_resource_path)
					if not child_resource == null:
						if child_resource_changed_key_values.empty():
							return effect
						
						var duplicated_child_resource: Resource = child_resource.duplicate()
						for child_key in child_resource_changed_key_values.keys():
							duplicated_child_resource.set(child_key, child_resource_changed_key_values[child_key])
						
						duplicated_effect.set(changed_key.trim_suffix("_RESOURCE"), duplicated_child_resource)
	
	return duplicated_effect


func deserialize_effects_from_data(value: Dictionary)->Array :
	refresh_mod_list()
	
	var effects: Array = []
	var datas: Array = value.datas
	for data in datas:
		var effect = deserialize_effect_from_data(data)
		
		if not effect == null:
			effects.append(effect)
		
	return effects


func refresh_mod_list()->void :
	var current_user_profile: = ModLoaderStore.current_user_profile
	if not current_user_profile == null:
		if not current_user_profile.mod_list == null:
			mod_list = current_user_profile.mod_list


func get_content_data_dict(with_file_name_mapping: bool = false, need_translation: bool = true)->Dictionary :
	var item_datas: Array = []
	var character_datas: Array = []
	var file_name_mapping: Dictionary = {}
	var loaded_datas: Dictionary = walk_directory()
	var translation: Translation = Translation.new()
	for file_name in loaded_datas.keys():
		var value = loaded_datas[file_name]
		var item_data = deserialize_item_data_from_data(value)
		var item_type: int = value.item_type
		
		if not item_data == null:
			match item_type:
				0:
					character_datas.append(item_data)
				1:
					item_datas.append(item_data)
			
			if with_file_name_mapping:
				file_name_mapping[item_data] = file_name
			
			if need_translation:
				translation.add_message(value.my_id.to_upper(), tr(value.name))
	
	if need_translation:
		TranslationServer.add_translation(translation)
	
	var content_data_dict: Dictionary = {}
	content_data_dict["items"] = item_datas
	content_data_dict["characters"] = character_datas
	
	if with_file_name_mapping:
		content_data_dict["file_name_mapping"] = file_name_mapping
	
	content_data_dict["raw_datas"] = loaded_datas
	
	return content_data_dict


func get_editable_datas_from_resource(res: Resource, default_key_value: Dictionary = {})->Array :
	var datas: Array = []
	var script: Script = res.get_script()
	if script == null:
		return datas
	var script_path: String = script.resource_path
	var property_list: Array = res.get_property_list()
	var enums_names: Array = ENUMS.keys()
	for property_dict in property_list:
		var actual_property_name: String = property_dict["name"]
		var property_name: String = actual_property_name.to_lower()
		var property_type: int = property_dict["type"]
		var property_class_name = property_dict["class_name"].to_lower()
		if (property_class_name == "packedscene"
			or property_name == "reference" 
			or property_name == "resource"
			or property_name == "resource_local_to_scene"
			or property_name == "resource_path"
			or property_name == "script"
			or property_name == "script variables"
			or property_name == "resource_name"
#			or property_name == "storage_method"
#			or property_name == "effect_sign"
			or property_name == "custom_args"
			or property_name == "base_value"
			or property_name.begins_with("_")
			or property_name.ends_with("_RESOURCE")
			or property_name.ends_with("_hash")
			):
			continue
		
		var property_value = res.get(actual_property_name)
		match property_type:
			TYPE_INT:
				if actual_property_name in enums_names:
					property_type = TYPE_ENUM
			TYPE_REAL, TYPE_BOOL, TYPE_STRING, TYPE_ARRAY:
				pass
			_:
				if property_value is WeaponStats:
					property_type = TYPE_WEAPON_STATS
				else:
					continue
		
		var data: Dictionary = {}
		data["key"] = actual_property_name
		data["type"] = property_type
		if default_key_value.empty():
			data["value"] = property_value
		else:
			var use_default_value: bool = true
			if property_type == TYPE_WEAPON_STATS:
				var res_property_name: String = actual_property_name + "_RESOURCE"
				if default_key_value.has(res_property_name):
					use_default_value = false
					var default_resource_value_dict: Dictionary = default_key_value[res_property_name]
					var child_res: Resource = load(default_resource_value_dict.base_resource_path)
					if not child_res == null:
						data["value"] = child_res
						data["child_resource_key_values"] = default_resource_value_dict.changed_key_values
					else:
						use_default_value = true
			else:
				if default_key_value.has(actual_property_name):
					use_default_value = false
					data["value"] = default_key_value[actual_property_name]
			if use_default_value:
				data["value"] = property_value
		
		datas.append(data)
	
	return datas
