extends SceneTree

const SCRIPTS := [
	"res://mods-unpacked/Aitato/mod_main.gd",
	"res://mods-unpacked/Aitato/extensions/player_aitato.gd",
	"res://mods-unpacked/Aitato/extensions/weapon_aitato.gd",
]

const RESOURCES := [
	"res://mods-unpacked/Aitato/content_data/aitato_content_data.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/deepseek_data.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/deepseek_appearance.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/effects/deepseek_effect_0.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/effects/deepseek_effect_1.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/effects/deepseek_effect_2.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/effects/deepseek_effect_3.tres",
	"res://mods-unpacked/Aitato/contents/characters/deepseek/effects/deepseek_effect_4.tres",
	"res://mods-unpacked/Aitato/contents/items/scared_sausage/scared_sausage_data.tres",
]


func _init() -> void:
	var failures := 0
	for path in SCRIPTS:
		if load(path) == null:
			printerr("FAILED script: ", path)
			failures += 1
		else:
			print("OK script: ", path)
	for path in RESOURCES:
		if load(path) == null:
			printerr("FAILED resource: ", path)
			failures += 1
		else:
			print("OK resource: ", path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
