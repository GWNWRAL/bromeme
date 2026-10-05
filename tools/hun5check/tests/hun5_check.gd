extends SceneTree
func _init():
	var s = load("res://hun5_check.gd")
	if s == null:
		print("FAILED: 解析不过")
		quit(1)
	else:
		print("OK: hun5.gd 解析通过")
		quit(0)
