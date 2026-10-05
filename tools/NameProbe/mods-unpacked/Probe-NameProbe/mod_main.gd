extends Node

# 一次性验证用: 实例化原版的角色面板 / 图鉴实体描述面板, 打印它们最终显示的文本,
# 用来确认 Toys&Balls 的两个脚本扩展真的把 key 换成了翻译后的名字。
# 验证完会把这个 mod 从游戏目录删掉。

const LOG := "UINameProbe"


func _ready() -> void:
	call_deferred("_probe")


func _probe() -> void:
	ModLoaderLog.info("=== ui probe start (locale=%s) ===" % TranslationServer.get_locale(), LOG)
	_check_character_panel()
	_check_entity("vanilla_pet", "res://entities/units/pet/bonk_dog/bonk_dog_item.tres",
			"BONK_DOG_NAME", "Bonk Dog")
	_check_entity("mod_pet    ", "res://mods-unpacked/General-Toys_Balls/content/pets/woody/woody_pet_item.tres",
			"TOYS_BALLS_ITEM_WOODY", "Woody")
	ModLoaderLog.info("=== ui probe end ===", LOG)


func _check_character_panel() -> void:
	var scene = load("res://ui/menus/ingame/character_panel_ui.tscn")
	var data = load("res://items/characters/well_rounded/well_rounded_data.tres")
	if scene == null or data == null:
		ModLoaderLog.info("character_panel: load failed", LOG)
		return

	var panel = scene.instance()
	add_child(panel)
	if panel.has_method("set_data"):
		panel.set_data(data, 0)

	var lbl = panel.get_node_or_null("%CharacterName")
	var shown = "<null>"
	if lbl != null:
		shown = lbl.text
	ModLoaderLog.info("character_panel 显示='%s'  (原始 key='%s' 期望='Well-Rounded')"
			% [shown, str(data.name)], LOG)
	panel.queue_free()


func _check_entity(label: String, path: String, raw_key: String, expect: String) -> void:
	var scene = load("res://ui/menus/pages/menu_codex/codex_entity_description.tscn")
	var data = load(path)
	if scene == null or data == null:
		ModLoaderLog.info("%s: load failed" % label, LOG)
		return

	# 1) 保持图鉴默认(未解锁条目显示 "???"), 确认没有被我们的扩展破坏
	var locked = scene.instance()
	add_child(locked)
	if locked.has_method("set_item"):
		locked.set_item(data, 0)
	var locked_lbl = locked.get_node_or_null("%Name")
	ModLoaderLog.info("%s 未解锁状态 名字='%s' (应为 '???')"
			% [label, (locked_lbl.text if locked_lbl != null else "<null>")], LOG)
	locked.queue_free()

	# 2) 关掉剪影, 看真实名字与行为描述
	var node = scene.instance()
	add_child(node)
	node.silhouette_locked_items = false
	if node.has_method("set_item"):
		node.set_item(data, 0)

	var lbl = node.get_node_or_null("%Name")
	var bd = node.get_node_or_null("%BehaviourDesc")
	var shown = "<null>"
	var behav = "<null>"
	if lbl != null:
		shown = lbl.text
	if bd != null:
		behav = bd.text
	ModLoaderLog.info("%s 名字='%s' (原始 key='%s' 期望='%s') | 行为描述='%s'"
			% [label, shown, raw_key, expect, behav.substr(0, 70)], LOG)
	node.queue_free()
