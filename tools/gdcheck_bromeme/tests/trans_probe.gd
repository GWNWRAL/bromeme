extends SceneTree

const KEYS := ["EFFECT_PET_BONK_DOG", "BONK_DOG", "ITEM_BONK_DOG"]


func _init() -> void:
	for f in ["zh", "en"]:
		var t = load("res://trans/%s.translation" % f)
		print("=== ", f, " loaded=", t != null)
		if t == null:
			continue
		for k in KEYS:
			print("   %-20s -> %s" % [k, str(t.get_message(k))])
	quit(0)
