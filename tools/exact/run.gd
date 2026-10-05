extends SceneTree
func check(loc):
	var t = load("res://mods-unpacked/Aitato-Aitato/translations/trans." + loc + ".translation")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale(loc)
	print("--- locale=", loc, " fileLocale=", t.locale)
	for k in ["CHARACTER_AITATO_DEEPSEEK","AITATO_EFFECT_SLEEP","AITATO_EFFECT_STARTING_ITEM"]:
		var v = tr(k)
		print("   ", k, " -> '", v, "'  ", "OK" if v != k else "FAILED")
func _init() -> void:
	check("zh_Hans_CN")
	check("en")
	quit(0)
