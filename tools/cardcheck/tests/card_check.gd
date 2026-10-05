extends SceneTree
func _init():
	var s = load("res://card_check.gd")
	print("OK: card_item.gd 解析通过" if s != null else "FAILED")
	quit(0 if s != null else 1)
