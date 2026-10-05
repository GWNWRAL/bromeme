extends Node

# =============================================================================
# Aitato - a Brotato content mod
# Version 0.0.2
#
# 0.0.2 变更:开局武器池校验(见 _weapon_is_usable / _sanitize_starting_weapons)。
#   本构建里"对 null 值调方法"是进程级陷阱(0xC0000005 读 0x38
#   @ Brotato.exe+0x1F8D28A),所以任何被放进 starting_weapons 的武器,
#   都必须在加入之前确认它的场景能安全实例化、且满足 vanilla weapon.gd 的
#   节点契约($Sprite / $Sprite/Hitbox),否则宁可不要这把武器,也不能让
#   玩家带着它进关。
#
# Character: DeepSeek (大肥鱼)
#   * starts with a Scared Sausage
#   * Elemental Damage modifications -25%
#   * falls asleep when she stops moving: +10 HP Regeneration, and her art is
#     swapped for the "deepsleep" sprite while asleep
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
		"AITATO_EFFECT_SLEEP": "Falls asleep when she stops moving: {0} HP Regeneration.",
		"AITATO_EFFECT_STARTING_ITEM": "Starts with {0} Scared Sausage.",
	},
	"zh_Hans_CN": {
		"CHARACTER_AITATO_DEEPSEEK": "大肥鱼",
		"AITATO_EFFECT_SLEEP": "停止移动时开始睡觉：生命再生{0}。",
		"AITATO_EFFECT_STARTING_ITEM": "开局自带{0}个害怕的香肠。",
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

	call_deferred("_log_translation_status")


# Diagnostic: reports what the running game actually resolves for our keys, so
# "description shows the raw key" problems can be traced from modloader.log.
func _log_translation_status() -> void:
	var probe := ["AITATO_EFFECT_SLEEP", "AITATO_EFFECT_STARTING_ITEM", "CHARACTER_AITATO_DEEPSEEK"]

	ModLoaderLog.info("current locale: " + str(TranslationServer.get_locale()), LOG_NAME)
	ModLoaderLog.info("locale fallback: " + str(TranslationServer.get_fallback_locale()), LOG_NAME)
	ModLoaderLog.info("loaded locales: " + str(TranslationServer.get_loaded_locales()), LOG_NAME)

	for key in probe:
		ModLoaderLog.info("tr(" + key + ") = '" + str(tr(key)) + "'", LOG_NAME)

	# Exercise the exact code path the character panel uses.
	for character in ItemService.characters:
		if character == null or character.my_id != "character_aitato_deepseek":
			continue
		for effect in character.effects:
			if effect == null:
				continue
			ModLoaderLog.info(
				"effect key='" + str(effect.key)
				+ "' text_key='" + str(effect.text_key)
				+ "' custom_key='" + str(effect.custom_key)
				+ "' get_text='" + str(effect.get_text(0, true)) + "'",
				LOG_NAME
			)


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
		_sanitize_starting_weapons()
		return

	for character in ItemService.characters:
		if character == null or character.my_id != "character_aitato_deepseek":
			continue

		for extra_path in DLC_POOL_WEAPONS:
			if not ResourceLoader.exists(extra_path):
				ModLoaderLog.warn("DLC weapon data missing, skipped: " + extra_path, LOG_NAME)
				continue

			var weapon = load(extra_path)
			if weapon == null:
				ModLoaderLog.warn("DLC weapon data failed to load, skipped: " + extra_path, LOG_NAME)
				continue

			# 0.0.2:只有"能安全实例化 + 满足 vanilla weapon.gd 节点契约"的武器才进池。
			# 坏武器一旦成为开局装备,玩家一进关就会在 weapon.gd 里对 null 调方法,
			# 而本构建会直接把进程打死(见文件头说明)。
			var unusable_reason := _weapon_is_usable(weapon)
			if unusable_reason != "":
				ModLoaderLog.warn(
					"DLC weapon skipped, would crash on equip (" + unusable_reason + "): "
					+ str(weapon.my_id), LOG_NAME)
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

		_sanitize_starting_weapons()

		ModLoaderLog.info("weapon pool size: " + str(character.starting_weapons.size()), LOG_NAME)

		# Dump the pool so "which weapons are offered" is verifiable from the log.
		var pool_ids: Array = []
		for weapon in character.starting_weapons:
			pool_ids.push_back("?" if weapon == null else str(weapon.my_id))
		ModLoaderLog.info("weapon pool: " + str(pool_ids), LOG_NAME)

		return


# 0.0.2:把"一定会打死进程"的武器从开局池里剔除。
# 只剔除 scene 都无法实例化的条目(那种武器一进关必崩),其余问题只报告不动手,
# 以免擅自改动别的 mod 放进来的正常武器。
func _sanitize_starting_weapons() -> void:
	for character in ItemService.characters:
		if character == null or character.my_id != "character_aitato_deepseek":
			continue

		var kept: Array = []
		for weapon in character.starting_weapons:
			if weapon == null:
				ModLoaderLog.warn("removed a null entry from the starting weapon pool", LOG_NAME)
				continue

			var scene = _weapon_scene(weapon)
			if scene != null:
				var probe = scene.instance()
				if probe == null:
					ModLoaderLog.warn(
						"removed a starting weapon whose scene cannot be instantiated: "
						+ str(weapon.get("my_id")), LOG_NAME)
					continue
				probe.free()

			kept.push_back(weapon)

		if kept.size() != character.starting_weapons.size():
			character.starting_weapons = kept

		return


# 返回 "" 表示这把武器可以安全地当开局装备;否则返回不可用原因(写进日志)。
# 检查项:
#   1. 武器数据带有可用的 PackedScene(字段名由属性表自动识别);
#   2. scene 能成功 instance() —— 失败时引擎会报
#      "Script inherits from native type 'X', so it can't be instanced in object of type 'Y'",
#      调用方拿到 null,之后对 null 调方法就是致命的;
#   3. 场景满足 vanilla weapon.gd 的节点契约:$Sprite 与 $Sprite/Hitbox 必须存在,
#      否则 weapon.gd 里 onready var _hitbox = $Sprite/Hitbox 会是 null,
#      connect_effects() 里的 _hitbox.connect("killed_something", ...) 会打死进程;
#   4. 场景不是 Godot 4 命名的( Sprite2D / Marker2D 在本构建里根本不是节点类型,
#      会得到 Cannot get class / Node ... cannot be created)。
#
# 注意:认不出场景字段时**不拒绝**这把武器,只报警告并退回旧行为 ——
# 校验的作用是挡住"一定会崩"的武器,而不是因为字段改名就清空玩家的开局武器。
func _weapon_is_usable(weapon) -> String:
	if weapon == null:
		return "null weapon data"

	var scene = _weapon_scene(weapon)
	if scene == null:
		ModLoaderLog.warn(
			"cannot locate a PackedScene on this weapon data, pool validation skipped: "
			+ str(weapon.get("my_id")), LOG_NAME)
		return ""

	var probe = scene.instance()
	if probe == null:
		return "scene failed to instance (script/native type mismatch)"

	var reason := ""
	if probe.get_node_or_null("Sprite") == null:
		reason = "scene has no Sprite node"
	elif probe.get_node_or_null("Sprite/Hitbox") == null:
		reason = "scene has no Sprite/Hitbox node"
	elif probe.find_node("Sprite2D", true, false) != null:
		reason = "scene uses the Godot 4 node name Sprite2D"
	elif probe.find_node("Marker2D", true, false) != null:
		reason = "scene uses the Godot 4 node name Marker2D"

	probe.free()
	return reason


# 武器数据上的 PackedScene(不依赖具体字段名:在属性表里找第一个 PackedScene 值)。
func _weapon_scene(weapon):
	if weapon == null:
		return null
	for property in weapon.get_property_list():
		if property.type == TYPE_OBJECT:
			var value = weapon.get(property.name)
			if value is PackedScene:
				return value
	return null


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
