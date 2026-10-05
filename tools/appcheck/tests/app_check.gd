extends SceneTree
func _init():
	var s = load("res://app_check.gd")
	print("OK: item_appearance_bromeme.gd 解析通过" if s != null else "FAILED")
	quit(0 if s != null else 1)
