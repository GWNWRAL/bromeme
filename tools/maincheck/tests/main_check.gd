extends SceneTree
func _init():
	var bad = 0
	for p in ["res://main_check.gd", "res://main.gd"]:
		var s = load(p)
		if s == null:
			print("FAILED: ", p)
			bad += 1
		else:
			print("OK: ", p)
	quit(bad)
