extends SceneTree

# Validates the texture side of the update. This staging project does not have
# the base game's scripts (they live in Brotato.pck), so the full .tres chain
# cannot be parsed here - but the PNG -> .import -> .stex chain can, and that is
# exactly what a texture update touches.
#
# vanilla player.gd does `Sprite.new(); sprite.texture = appearance.get_sprite()`
# with no scaling, so texture size == rendered size.

const CHAR := "res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/"

func _init():
	var all_ok = true
	for name in ["deepseek.png", "deepsleep.png", "deepseek_icon.png"]:
		var path = CHAR + name
		if not ResourceLoader.exists(path):
			print("FAIL ", name, ": not found at ", path)
			all_ok = false
			continue
		var tex = load(path)
		if tex == null:
			print("FAIL ", name, ": load returned null")
			all_ok = false
			continue
		var size = tex.get_size()
		print("OK   ", name, " -> ", tex.get_class(),
			" size=", size, " path=", tex.resource_path)
		if size.x != 96 or size.y != 96:
			print("     ^^ WARNING: expected 96x96 (vanilla renders at native size)")
			all_ok = false
	print("RESULT: ", "OK" if all_ok else "FAILED")
	quit(0 if all_ok else 1)
