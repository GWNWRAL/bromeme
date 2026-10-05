extends SceneTree

func _init() -> void:
	var t := Translation.new()
	t.locale = "zh_Hans_CN"
	t.add_message("CHARACTER_AITATO_DEEPSEEK", "???")
	t.add_message("AITATO_EFFECT_SLEEP", "??????????????+10???????")
	t.add_message("AITATO_EFFECT_STARTING_ITEM", "????????????")
	TranslationServer.add_translation(t)

	var t2 := Translation.new()
	t2.locale = "en"
	t2.add_message("CHARACTER_AITATO_DEEPSEEK", "DeepSeek")
	t2.add_message("AITATO_EFFECT_SLEEP", "Falls asleep when she stops moving: +10 HP Regeneration, but she cannot attack.")
	t2.add_message("AITATO_EFFECT_STARTING_ITEM", "Starts with a Scared Sausage.")
	TranslationServer.add_translation(t2)

	for loc in ["zh_Hans_CN", "zh", "en"]:
		TranslationServer.set_locale(loc)
		print("--- asked=", loc, " resolved=", TranslationServer.get_locale())
		for k in ["CHARACTER_AITATO_DEEPSEEK","AITATO_EFFECT_SLEEP","AITATO_EFFECT_STARTING_ITEM"]:
			var v = tr(k)
			print("     ", k, " -> '", v, "'  ", "OK" if v != k else "FAILED")
	quit(0)
