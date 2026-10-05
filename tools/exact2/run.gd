extends SceneTree
func _init() -> void:
	var t = load("res://t.en.translation")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("en")
	for k in ["CHARACTER_AITATO_DEEPSEEK","AITATO_EFFECT_SLEEP","AITATO_EFFECT_STARTING_ITEM"]:
		var v = tr(k)
		print("   ", k, " -> '", v, "'  ", "OK" if v != k else "FAILED")
	quit(0)
