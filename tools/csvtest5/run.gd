extends SceneTree
func _init() -> void:
	# mimic the game: load the zh_Hans_CN translation, then try locales "zh" and "zh_Hans_CN"
	var t = load("res://t.zh_Hans_CN.translation")
	TranslationServer.add_translation(t)
	for loc in ["zh", "zh_Hans_CN"]:
		TranslationServer.set_locale(loc)
		print("asked=", loc, " resolved=", TranslationServer.get_locale(),
			"  AITATO_EFFECT_SLEEP='", tr("AITATO_EFFECT_SLEEP"), "'")
	quit(0)
