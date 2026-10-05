extends SceneTree
func _init() -> void:
	var t = load("res://t.zh_Hans_CN.translation")
	print("locale of file: ", t.locale)
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("zh_Hans_CN")
	print("resolved locale: ", TranslationServer.get_locale())
	print("AITATO_EFFECT_SLEEP -> '", tr("AITATO_EFFECT_SLEEP"), "'")
	print("AITATO_EFFECT_STARTING_ITEM -> '", tr("AITATO_EFFECT_STARTING_ITEM"), "'")
	print("CHARACTER_AITATO_DEEPSEEK -> '", tr("CHARACTER_AITATO_DEEPSEEK"), "'")
	quit(0)
