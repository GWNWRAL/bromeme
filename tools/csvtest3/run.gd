extends SceneTree
func _init() -> void:
	var t = load("res://t.en.translation")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("en")
	var keys := ["CHARACTER_AITATO_DEEPSEEK","AITATO_SLEEP","AITATO_STARTING_ITEM","SLEEP","START_ITEM","A_SLEEP","ZZZZ_SLEEP"]
	for k in keys:
		print("  ", k, " -> '", tr(k), "'")
	quit(0)
