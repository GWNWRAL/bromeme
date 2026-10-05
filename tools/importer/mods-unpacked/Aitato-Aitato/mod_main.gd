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

var dir := ""


func _init() -> void:
	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR


func _ready() -> void:
	_install_extensions()
	_load_content()
	register_translations()


# Registers the script extensions that implement the new mechanics.
func _install_extensions() -> void:
	for relative_path in EXTENSION_SCRIPTS:
		var script_path: String = dir + relative_path
		if not ResourceLoader.exists(script_path):
			ModLoaderLog.error("Missing extension script: %s" % script_path, LOG_NAME)
			continue
		ModLoaderMod.install_script_extension(script_path)


# Adds the mod's characters/items to the game's content pools.
func _load_content() -> void:
	var content_data_path: String = dir + CONTENT_DATA_PATH
	if not ResourceLoader.exists(content_data_path):
		ModLoaderLog.error("Missing content data: %s" % content_data_path, LOG_NAME)
		return

	var content_loader = get_node_or_null("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
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


# =============================================================================
# Translations
#
# Text is registered at runtime so the mod does not ship pre-compiled
# `.translation` resources (which cannot be authored from plain text).
# =============================================================================

const TRANSLATIONS := {
	"en": {
		"CHARACTER_AITATO_DEEPSEEK": "DeepSeek",
		"CHARACTER_AITATO_DEEPSEEK_DESCR": "Big Fat Fish. Sleeps whenever she stops moving.",
		"ITEM_AITATO_SCARED_SAUSAGE": "Scared Sausage",
		"ITEM_AITATO_SCARED_SAUSAGE_DESCR": "It is very scared. Damaging a burning enemy makes it burn harder.",
		"AITATO_EFFECT_DEEPSEEK_0": "Stops moving to fall asleep: [color=#00ff00]+{0} HP Regeneration[/color], but [color=red]cannot attack[/color].",
		"AITATO_EFFECT_DEEPSEEK_1": "While asleep a charge bar fills up in {0}s beneath her feet.",
		"AITATO_EFFECT_DEEPSEEK_2": "When the bar is full, gain [color=#00ff00]doubled Critical Damage[/color] and [color=#00ff00]doubled Armor[/color] for {0}s.",
		"AITATO_EFFECT_DEEPSEEK_3": "Starts with a Scared Sausage.",
	},
	"zh": {
		"CHARACTER_AITATO_DEEPSEEK": "大肥鱼",
		"CHARACTER_AITATO_DEEPSEEK_DESCR": "大肥鱼。停止移动时就会开始睡觉。",
		"ITEM_AITATO_SCARED_SAUSAGE": "害怕的香肠",
		"ITEM_AITATO_SCARED_SAUSAGE_DESCR": "它非常害怕。对燃烧中的敌人造成伤害时，它们会烧得更旺。",
		"AITATO_EFFECT_DEEPSEEK_0": "停止移动后开始睡觉：生命再生[color=#00ff00]+{0}[/color]，但[color=red]无法攻击[/color]。",
		"AITATO_EFFECT_DEEPSEEK_1": "睡觉时脚下会出现一个充能条，{0} 秒攒满。",
		"AITATO_EFFECT_DEEPSEEK_2": "攒满后获得持续 {0} 秒的[color=#00ff00]暴击伤害翻倍[/color]和[color=#00ff00]护甲翻倍[/color]。",
		"AITATO_EFFECT_DEEPSEEK_3": "开局自带一个害怕的香肠。",
	},
}

var _translations_registered := false


func register_translations() -> void:
	if _translations_registered:
		return
	_translations_registered = true

	for locale in TRANSLATIONS:
		var translation := Translation.new()
		translation.locale = locale
		for key in TRANSLATIONS[locale]:
			translation.add_message(key, TRANSLATIONS[locale][key])
		TranslationServer.add_translation(translation)

	ModLoaderLog.info("Runtime translations registered", LOG_NAME)
