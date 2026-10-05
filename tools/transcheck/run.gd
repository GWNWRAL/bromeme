extends SceneTree

func _init() -> void:
	var path := "res://mods-unpacked/Aitato-Aitato/translations/trans.zh_Hans_CN.translation"
	var t = load(path)
	print("loaded: ", t, " locale=", t.locale if t else "?")

	TranslationServer.add_translation(t)

	for locale in ["en", "zh", "zh_Hans_CN"]:
		TranslationServer.set_locale(locale)
		print("--- locale=", locale, " (TranslationServer.get_locale()=", TranslationServer.get_locale(), ")")
		for k in ["AITATO_SLEEP", "AITATO_STARTING_ITEM", "CHARACTER_AITATO_DEEPSEEK"]:
			print("    tr(", k, ") = '", tr(k), "'")
	quit(0)
