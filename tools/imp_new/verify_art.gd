extends SceneTree

# Loads the shipped StreamTextures the way the game does and writes them back out
# as PNGs, so the compiled cache can be compared against the source art.

func _init():
	var jobs = [
		["deepseek.png", "user://decoded_deepseek.png"],
		["deepsleep.png", "user://decoded_deepsleep.png"],
		["deepseek_icon.png", "user://decoded_icon.png"],
	]
	for job in jobs:
		var path = "res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/" + job[0]
		var res = load(path)
		if res == null:
			print("LOAD FAILED: ", path)
			continue
		var img = res.get_data()
		if img == null:
			print("NO IMAGE DATA: ", path)
			continue
		var err = img.save_png(job[1])
		print("SAVED ", job[0], " size=", img.get_width(), "x", img.get_height(),
			" err=", err, " -> ", ProjectSettings.globalize_path(job[1]))
	quit()
