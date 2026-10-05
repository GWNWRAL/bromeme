extends SceneTree

const SCRIPTS := [
	"res://meme/item_service_bromeme_check.gd",
	"res://meme/bromeme_pick_ui_check.gd",
	"res://meme/pet_bonk_dog_check.gd",
	"res://meme/meme_sfx.gd",
]


func _init() -> void:
	var failures := 0
	for path in SCRIPTS:
		var s = load(path)
		if s == null:
			printerr("FAILED load: ", path)
			failures += 1
			continue
		var inst = null
		if s.can_instance():
			inst = s.new()
		if inst == null:
			printerr("FAILED instantiate: ", path)
			failures += 1
		else:
			print("OK: ", path)
			if inst is Node:
				inst.free()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
