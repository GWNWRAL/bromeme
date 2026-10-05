extends SceneTree
func _init() -> void:
	var t = load("res://t.en.translation")
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("en")
	var keys := [
		"AITATO_EFFECT_SLEEP","AITATO_EFFECT_STARTING_ITEM",
		"EFFECT_AITATO_SLEEP","EFFECT_AITATO_STARTING_ITEM",
		"AITATO_SLEEP_DESCR","AITATO_STARTING_ITEM_DESCR",
	]
	for k in keys:
		var v = tr(k)
		print("  ", k, " -> '", v, "'  ", "OK" if v != k else "  <-- FAILED")
	quit(0)
