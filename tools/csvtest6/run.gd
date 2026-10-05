extends SceneTree
func _init() -> void:
	var t = load("res://t.zh_Hans_CN.translation")
	var t2 = load("res://t.zh.translation")
	if t2:
		TranslationServer.add_translation(t2)
	elif t:
		TranslationServer.add_translation(t)
	for loc in ["zh", "zh_Hans_CN"]:
		TranslationServer.set_locale(loc)
		print("asked=", loc, " resolved=", TranslationServer.get_locale(),
			"  SLEEP='", tr("AITATO_EFFECT_SLEEP"), "'")
	quit(0)
