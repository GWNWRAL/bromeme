extends SceneTree

const SCRIPTS := [
	"res://meme/meme_sfx.gd",
	"res://meme/meme_invasion.gd",
]


func _init() -> void:
	var failures := 0
	for path in SCRIPTS:
		var s = load(path)
		if s == null:
			printerr("FAILED script: ", path)
			failures += 1
		else:
			print("OK script: ", path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
