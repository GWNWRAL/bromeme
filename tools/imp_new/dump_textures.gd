extends SceneTree

# Loads compiled StreamTextures and writes them back out as PNG, so the
# compiled cache can be compared against the source art.

func _init():
	var jobs = [
		["res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/deepseek.png", "user://deepseek_decoded.png"],
		["res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/deepsleep.png", "user://deepsleep_decoded.png"],
		["res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/deepseek_icon.png", "user://deepseek_icon_decoded.png"],
	]

	for job in jobs:
		var res = load(job[0])
		if res == null:
			print("LOAD FAILED: ", job[0])
			continue
		var img = res.get_data()
		if img == null:
			print("NO IMAGE DATA: ", job[0])
			continue
		img.lock()
		var fmt = img.get_format()
		img.unlock()
		var err = img.save_png(job[1])
		print("SAVED ", job[0], " -> ", job[1],
			"  size=", img.get_width(), "x", img.get_height(),
			" format=", fmt, " err=", err,
			"  abspath=", ProjectSettings.globalize_path(job[1]))

	quit()
