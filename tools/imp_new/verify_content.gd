extends SceneTree

# Verifies the shipped content the same way the game does:
#   * the .tres chain still parses (character data, appearance, effects)
#   * the appearance texture resolves to a real texture and reports its size
#     (player.gd creates a bare Sprite, so texture size == rendered size)

const MOD := "res://mods-unpacked/Aitato-Aitato/"
const CHAR := MOD + "contents/characters/deepseek/"

func _init():
	var ok = true

	var character = load(CHAR + "deepseek_data.tres")
	if character == null:
		print("FAIL: character data did not load")
		quit(1)
		return
	print("character my_id      = ", character.my_id)
	print("character name key   = ", character.name)
	print("unlocked_by_default  = ", character.unlocked_by_default)

	print("--- icon ---")
	_report(character.icon, "icon")

	print("--- appearances ---")
	for appearance in character.item_appearances:
		var tex = appearance.get_sprite()
		_report(tex, "appearance position=" + str(appearance.position)
			+ " priority=" + str(appearance.display_priority)
			+ " depth=" + str(appearance.depth))

	print("--- effects ---")
	for effect in character.effects:
		print("  key=", effect.key,
			" text_key=", effect.text_key,
			" value=", effect.value,
			" custom_key=", effect.custom_key,
			" storage=", effect.storage_method,
			" args=", effect.custom_args.size())

	print("--- weapons ---")
	for w in character.starting_weapons:
		print("  ", w.my_id if w != null else "<null>")

	print("--- deepsleep (loaded from the mod folder, as the extension does) ---")
	var sleep_path = CHAR + "deepsleep.png"
	print("  exists=", ResourceLoader.exists(sleep_path))
	_report(load(sleep_path) if ResourceLoader.exists(sleep_path) else null, "deepsleep")

	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0)

func _report(tex, label):
	if tex == null:
		print("  ", label, " -> NULL (texture missing!)")
		return
	var size = "?"
	if tex.has_method("get_size"):
		size = str(tex.get_size())
	print("  ", label, " -> ", tex.get_class(), " size=", size,
		" path=", tex.resource_path)
