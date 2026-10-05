extends SceneTree
func _init() -> void:
	var t = load("res://t.zh_Hans_CN.translation")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("zh_Hans_CN")
	var v0 = tr("CHARACTER_AITATO_DEEPSEEK")
	print("  CHARACTER_AITATO_DEEPSEEK -> '", v0, "'")
	var v1 = tr("AITATO_EFFECT_SLEEP")
	print("  AITATO_EFFECT_SLEEP -> '", v1, "'")
	var v2 = tr("AITATO_EFFECT_STARTING_ITEM")
	print("  AITATO_EFFECT_STARTING_ITEM -> '", v2, "'")
	quit(0)

