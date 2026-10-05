extends SceneTree
func _init():
	var s = load("res://prd_check.gd")
	if s == null:
		print("FAILED: player_run_data 扩展解析不过")
		quit(1)
	else:
		print("OK: player_run_data 扩展解析通过")
		quit(0)
