extends Node

# =============================================================================
# Aitato - a Brotato content mod
# Version 0.0.1
#
# Adds new characters (and, later, other content) to Brotato.
# First character: DeepSeek (大肥鱼).
#
# Requires: Brotato ModLoader 6.x
# Optional: Darkly77-ContentLoader (used to register the new content; the mod
#           falls back to a manual ItemService registration if it is missing).
#
# The initialisation order mirrors the reference character mod:
#   _init() -> resolve the mod dir, install script extensions, register
#              translations, then register content.
# =============================================================================

# The mod's folder must be named `{namespace}-{name}`, which is also the mod id
# the loader reports.
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
var _is_initialized := false
var _content_loaded := false


func _init() -> void:
	if _is_initialized:
		return
	_is_initialized = true

	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR

	# These two are safe from _init(): they only touch the mod loader and the
	# translation server, and they must happen early so text is available.
	_install_extensions()
	register_translations()


func _ready() -> void:
	# Content registration needs to look up the ContentLoader node, which is
	# only possible once this node is inside the active scene tree.
	if _content_loaded:
		return
	_content_loaded = true

	_load_content()


# Registers the script extensions that implement the new mechanics.
func _install_extensions() -> void:
	for relative_path in EXTENSION_SCRIPTS:
		var script_path: String = dir + relative_path
		if not ResourceLoader.exists(script_path):
			ModLoaderLog.error("Missing extension script: %s" % script_path, LOG_NAME)
			continue
		ModLoaderMod.install_script_extension(script_path)
		ModLoaderLog.info("Installed extension: %s" % relative_path, LOG_NAME)


# Registers the compiled translation resources (built from translations/trans.csv).
func register_translations() -> void:
	for relative_path in TRANSLATION_PATHS:
		var translation_path: String = dir + relative_path
		if not ResourceLoader.exists(translation_path):
			ModLoaderLog.error("Missing translation: %s" % translation_path, LOG_NAME)
			continue
		ModLoaderMod.add_translation(translation_path)
		ModLoaderLog.info("Loaded translation: %s" % relative_path, LOG_NAME)


# Adds the mod's characters/items to the game's content pools.
func _load_content() -> void:
	var content_data_path: String = dir + CONTENT_DATA_PATH
	if not ResourceLoader.exists(content_data_path):
		ModLoaderLog.error("Missing content data: %s" % content_data_path, LOG_NAME)
		return

	var content_loader = get_tree().root.get_node_or_null("ModLoader/Darkly77-ContentLoader/ContentLoader")
	if content_loader != null and content_loader.has_method("load_data"):
		ModLoaderLog.info("Registering content through ContentLoader", LOG_NAME)
		content_loader.load_data(content_data_path, MOD_NAME)
		return

	# Fallback: register the content manually (requires the mod loader only).
	ModLoaderLog.warn(
		"Darkly77-ContentLoader not found - falling back to manual content registration",
		LOG_NAME
	)
	_register_content_manually(content_data_path)


func _register_content_manually(content_data_path: String) -> void:
	var content_data = load(content_data_path)
	if content_data == null:
		ModLoaderLog.error("Failed to load content data: %s" % content_data_path, LOG_NAME)
		return

	ItemService.items.append_array(content_data.items)
	ItemService.characters.append_array(content_data.characters)
	ItemService.weapons.append_array(content_data.weapons)

	# Unlocks everything marked `unlocked_by_default` and - importantly for new
	# characters - builds the CharacterDifficultyInfo entries that the character
	# selection screen needs.
	ProgressData.add_unlocked_by_default()

	ItemService.init_unlocked_pool()
