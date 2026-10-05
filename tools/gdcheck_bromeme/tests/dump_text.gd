extends SceneTree

func _init() -> void:
	var t = load("res://trans/zh.translation")
	var f := File.new()
	f.open("D:/DSH/_aitato_work/vanilla_bonk_text.txt", File.WRITE)
	f.store_string(str(t.get_message("EFFECT_PET_BONK_DOG")))
	f.close()
	print("written")
	quit(0)
