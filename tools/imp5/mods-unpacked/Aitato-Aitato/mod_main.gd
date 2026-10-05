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

# Text is registered through plain `Translation` objects at runtime.
#
# The compiled CSV resources are kept as a fallback, but they cannot be relied
# on: Godot 3's `PHashTranslation` (what the csv_translation importer produces)
# uses a perfect-hash table that collides for some key sets, and colliding keys
# silently resolve to their raw key text. `Translation.add_message()` stores a
# normal dictionary and always resolves.
const TEXT := {
	"en": {
		"CHARACTER_AITATO_DEEPSEEK": "DeepSeek",
		"AITATO_EFFECT_SLEEP": "Falls asleep when she stops moving: +10 HP Regeneration, but she cannot attack.",
		"AITATO_EFFECT_STARTING_ITEM": "Starts with a Scared Sausage.",
	},
	"zh_Hans_CN": {
		"CHARACTER_AITATO_DEEPSEEK": "大肥鱼",
		"AITATO_EFFECT_SLEEP": "停止移动时开始睡觉：生命再生+10，但无法攻击。",
		"AITATO_EFFECT_STARTING_ITEM": "开局自带一个害怕的香肠。",
	},
}

# The game's own language setting uses plain "zh", which Godot resolves to
# zh_Hans_CN, so the same strings are registered under both locales.
const TEXT_LOCALE_ALIASES := {
	"zh": "zh_Hans_CN",
}

# DLC-only weapons offered as extra starting-weapon choices.
const DLC_POOL_WEAPONS := [
	"res://dlcs/dlc_1/weapons/melee/spoon/1/spoon_data.tres",
	"res://dlcs/dlc_1/weapons/melee/brick/1/brick_data.tres",
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
	# Runtime translations first: these always resolve.
	var added: Array = []

	for locale in TEXT:
		var translation := Translation.new()
		translation.locale = locale
		for key in TEXT[locale]:
			translation.add_message(key, TEXT[locale][key])
		TranslationServer.add_translation(translation)
		added.push_back(locale)

	# Same strings under the plain "zh" locale the game setting uses.
	for alias in TEXT_LOCALE_ALIASES:
		var source_locale: String = TEXT_LOCALE_ALIASES[alias]
		if not TEXT.has(source_locale):
			continue
		var alias_translation := Translation.new()
		alias_translation.locale = alias
		for key in TEXT[source_locale]:
			alias_translation.add_message(key, TEXT[source_locale][key])
		TranslationServer.add_translation(alias_translation)
		added.push_back(alias)

	ModLoaderLog.info("translations registered for: " + str(added), LOG_NAME)

	# Fallback: the compiled CSV resources, in case a locale is missing above.
	for relative_path in TRANSLATION_PATHS:
		var translation_path: String = dir + relative_path
		if ResourceLoader.exists(translation_path):
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
		call_deferred("_log_registration_status")
		return

	ModLoaderLog.warn("Darkly77-ContentLoader missing - manual registration", LOG_NAME)
	_register_content_manually(content_data_path)
	call_deferred("_log_registration_status")


# Diagnostic + extra pool weapons.
func _log_registration_status() -> void:
	var character_id := "character_aitato_deepseek"
	var found_in_characters := false
	var character_hash := 0

	for character in ItemService.characters:
		if character != null and character.my_id == character_id:
			found_in_characters = true
			character_hash = character.my_id_hash
			break

	_add_dlc_pool_weapons()

	ModLoaderLog.info(
		"status: in ItemService.characters=" + str(found_in_characters)
		+ " hash=" + str(character_hash)
		+ " unlocked=" + str(ProgressData.characters_unlocked.has(character_hash))
		+ " pool_size=" + str(ItemService.characters.size()),
		LOG_NAME
	)


# Spoon (勺子) and Brick (板砖) are DLC weapons. They must not be referenced from
# the character's .tres, because a missing DLC resource makes that .tres fail to
# parse and the character cannot be loaded at all. Instead they are appended to
# the character's weapon pool here, and only when the DLC is actually active, so
# the weapon-selection screen offers them like any other starting weapon.
func _add_dlc_pool_weapons() -> void:
	if not ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		ModLoaderLog.info("DLC not active - Spoon/Brick not added to the pool", LOG_NAME)
		return

	for character in ItemService.characters:
		if character == null or character.my_id != "character_aitato_deepseek":
			continue

		for extra_path in DLC_POOL_WEAPONS:
			if not ResourceLoader.exists(extra_path):
				continue

			var weapon = load(extra_path)
			if weapon == null:
				continue

			var already_present := false
			for existing in character.starting_weapons:
				if existing != null and existing.my_id == weapon.my_id:
					already_present = true
					break

			if not already_present:
				character.starting_weapons.push_back(weapon)
				ModLoaderLog.info("Added to weapon pool: " + str(weapon.my_id), LOG_NAME)

			if not ProgressData.weapons_unlocked.has(weapon.my_id_hash):
				ProgressData.weapons_unlocked.push_back(weapon.my_id_hash)

		ModLoaderLog.info("weapon pool size: " + str(character.starting_weapons.size()), LOG_NAME)
		return


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
