extends Node

# =============================================================================
# Aitato - a Brotato content mod
# Version 0.0.1
#
# Character: DeepSeek (大肥鱼)
#   * starts with a Scared Sausage
#   * starting weapon choice: Spoon / Stick / Knife
#   * falls asleep when she stops moving: +10 HP Regeneration, cannot attack,
#     and her art is swapped for the "deepsleep" sprite while asleep
#
# Requires: Brotato ModLoader 6.x
# Optional: Darkly77-ContentLoader (falls back to a manual registration)
# =============================================================================

const MOD_NAME := "Aitato"
const MOD_ID := "Aitato-Aitato"
const MOD_DIR := "Aitato-Aitato/"
const LOG_NAME := "Aitato"

const CONTENT_DATA_PATH := "content_data/aitato_content_data.tres"

const EXTENSION_SCRIPTS := [
	"extensions/player_aitato.gd",
	"extensions/weapon_aitato.gd",
]

const TRANSLATION_PATHS := [
	"translations/trans.en.translation",
	"translations/trans.zh_Hans_CN.translation",
]

var dir := ""
var _initialized := false
var _content_loaded := false


func _init() -> void:
	if _initialized:
		return
	_initialized = true

	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR

	_install_extensions()
	_register_translations()


func _ready() -> void:
	if _content_loaded:
		return
	_content_loaded = true

	_register_content()


func _install_extensions() -> void:
	for relative_path in EXTENSION_SCRIPTS:
		var script_path: String = dir + relative_path
		if not ResourceLoader.exists(script_path):
			ModLoaderLog.error("Missing extension script: %s" % script_path, LOG_NAME)
			continue
		ModLoaderMod.install_script_extension(script_path)


func _register_translations() -> void:
	for relative_path in TRANSLATION_PATHS:
		var translation_path: String = dir + relative_path
		if not ResourceLoader.exists(translation_path):
			ModLoaderLog.error("Missing translation: %s" % translation_path, LOG_NAME)
			continue
		ModLoaderMod.add_translation(translation_path)


func _register_content() -> void:
	var content_data_path: String = dir + CONTENT_DATA_PATH
	if not ResourceLoader.exists(content_data_path):
		ModLoaderLog.error("Missing content data: %s" % content_data_path, LOG_NAME)
		return

	var content_loader = get_tree().root.get_node_or_null("ModLoader/Darkly77-ContentLoader/ContentLoader")
	if content_loader != null and content_loader.has_method("load_data"):
		content_loader.load_data(content_data_path, MOD_NAME)
		ModLoaderLog.info("Content registered", LOG_NAME)
		return

	ModLoaderLog.warn("Darkly77-ContentLoader missing - manual registration", LOG_NAME)
	_register_content_manually(content_data_path)


func _register_content_manually(content_data_path: String) -> void:
	var content_data = load(content_data_path)
	if content_data == null:
		ModLoaderLog.error("Failed to load content data: %s" % content_data_path, LOG_NAME)
		return

	ItemService.items.append_array(content_data.items)
	ItemService.characters.append_array(content_data.characters)
	ItemService.weapons.append_array(content_data.weapons)

	ProgressData.add_unlocked_by_default()
	ItemService.init_unlocked_pool()
