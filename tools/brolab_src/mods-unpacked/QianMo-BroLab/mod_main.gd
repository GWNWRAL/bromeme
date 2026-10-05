extends Node


const CONFIG_NAME: = "brolab_config"
const MOD_NAME: String = "QianMo-BroLab"
const EXTENSION_RELATIVE_PATH: String = "extensions/"
const TRANSLATION_RELATIVE_PATH: String = "translations/"
const EFFECTS_PATH: = "contents/effects/"
const EFFECTS_SCRIPTS: = [
	"effect_midas_hand.gd",
	"receive_items_at_wave.gd",
	"receive_stat_at_wave.gd",
	"stats_end_of_wave_after_wave.gd",
	"convert_stats_at_wave.gd",
]

var BrolabManager

var dir: String = ""
var extension_dir: String = ""
var tranlation_dir: String = ""

var _is_extension_enabled: bool = false


func _init():
	dir = ModLoaderMod.get_unpacked_dir() + MOD_NAME + "/"
	extension_dir = dir + EXTENSION_RELATIVE_PATH
	tranlation_dir = dir + TRANSLATION_RELATIVE_PATH
	
#	ModLoaderMod.install_script_extension(extension_dir + "ui/menus/menus.gd")
	ModLoaderMod.install_script_extension(extension_dir + "ui/menus/pages/menu_choose_options.gd")
#	ModLoaderMod.install_script_extension(extension_dir + "singletons/progress_data.gd")
	ModLoaderMod.install_script_extension(extension_dir + "ui/menus/base_shop.gd")
	ModLoaderMod.install_script_extension(extension_dir + "singletons/run_data.gd")
	ModLoaderMod.install_script_extension(extension_dir + "singletons/player_run_data.gd")
	
	var configs: Dictionary = ModLoaderConfig.get_configs(MOD_NAME)
	if configs.has(CONFIG_NAME):
		var config = ModLoaderConfig.get_config(MOD_NAME, CONFIG_NAME)
		var data = config.data
		if data and not data.empty() and data.get("BROLAB_ENABLE_SPECIAL_MECHANISMS", false):
			_is_extension_enabled = true
			
			ModLoaderMod.install_script_extension(extension_dir + "main.gd")
	
	ModLoaderMod.add_translation(tranlation_dir + "brolab_translation.en.translation")
	ModLoaderMod.add_translation(tranlation_dir + "brolab_translation.zh_Hans_CN.translation")
	
	BrolabManager = load("res://mods-unpacked/QianMo-BroLab/brolab_manager.gd").new()
	add_child(BrolabManager)
	
#	BrolabManager.fix_lag_save(false, "user://" + Platform.get_user_id() + "/save_v2.json")


#func apply_extension(extension_path: String) -> void:
#	var child_script: Script = ResourceLoader.load(extension_path)
#	child_script.set_meta("extension_script_path", extension_path)
#
#	var parent_script: Script = child_script.get_base_script()
#	var parent_script_path: String = parent_script.resource_path
#
#	if not ModLoaderStore.saved_scripts.has(parent_script_path):
#		ModLoaderStore.saved_scripts[parent_script_path] = []
#		ModLoaderStore.saved_scripts[parent_script_path].append(parent_script.duplicate())
#
#	ModLoaderStore.saved_scripts[parent_script_path].append(child_script)
#
#	child_script.take_over_path(parent_script_path)


func _ready():
	for s in EFFECTS_SCRIPTS:
		ItemService.effects.append(load(dir + EFFECTS_PATH + s))
	
	BrolabManager.init_save_paths()
	
	call_deferred("_load_data")


func _load_data()->void :
	var content_datas: Dictionary = BrolabManager.get_content_data_dict()
	
	BrolabManager.add_items(content_datas.characters, "character", false, true)
	BrolabManager.add_items(content_datas.items, "item", false, true)
	
	ProgressData.load_game_file()

# Invoke when DebugService ready
#func install_data()->void :
#	ItemService.items.append_array(item_datas)
#	ItemService.characters.append_array(character_datas)
#
#	for item in item_datas:
#		if not ProgressData.items_unlocked.has(item.my_id):
#			ProgressData.items_unlocked.push_back(item.my_id)
#
#	for character in character_datas:
#		if not ProgressData.characters_unlocked.has(character.my_id):
#			ProgressData.characters_unlocked.push_back(character.my_id)
#
#		var character_diff_info = CharacterDifficultyInfo.new(character.my_id)
#		for zone in ZoneService.zones:
#			if zone.unlocked_by_default:
#				character_diff_info.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone.my_id))
#
#			ProgressData.difficulties_unlocked.push_back(character_diff_info)
#
#	ProgressData.load_game_file()
#
#	ModLoaderLog.success("Successfully installed extra items", MOD_NAME)

