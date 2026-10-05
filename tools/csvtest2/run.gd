extends SceneTree
func _init() -> void:
	var t = load("res://mods-unpacked/Aitato-Aitato/translations/trans.en.translation")
	print("loaded=", t, " locale=", t.locale if t else "?")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("en")
	for k in ["CHARACTER_AITATO_DEEPSEEK","AITATO_SLEEP","AITATO_STARTING_ITEM"]:
		print("  ", k, " -> '", tr(k), "'")
	quit(0)
