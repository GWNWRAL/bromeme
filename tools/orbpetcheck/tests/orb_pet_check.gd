extends SceneTree
func _init():
	var s = load("res://orb_pet_check.gd")
	if s == null:
		print("FAILED: orb_pet.gd")
		quit(1)
	else:
		print("OK: orb_pet.gd")
		quit(0)
