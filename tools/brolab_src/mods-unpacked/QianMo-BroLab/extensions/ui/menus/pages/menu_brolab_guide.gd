extends VBoxContainer


signal back_button_pressed


const SPECIFIC_KEYS: Dictionary = {
	"tree_turrets": "EFFECT_TREE_TURRET",
	"upgraded_baits": "effect_upgraded_baits",
	"no_heal": "effect_no_heal",
	"projectiles": "EFFECT_PROJECTILES",
	"cryptid": "effect_cryptid",
	"min_weapon_tier": "effect_min_weapon_tier",
	"max_weapon_tier": "effect_max_weapon_tier",
}

onready var stats_container: VBoxContainer = $HBoxContainer/StatsReferenceContainer/ScrollContainer/Stats
onready var example_stat_label = $HBoxContainer/StatsReferenceContainer/Example
onready var items_container: VBoxContainer = $HBoxContainer/ItemsReferenceContainer/ScrollContainer/Items
onready var example_item_label = $HBoxContainer/ItemsReferenceContainer/Example


func init()->void :
	var effects_list = []
	for i in RunData.players_data.size():
#		if i == RunData.DUMMY_PLAYER_INDEX:
#			continue
		var effects = RunData.players_data[i].effects
		for effect in effects:
			if not effect in effects_list:
				effects_list.append(effect)
	
	var effects: Dictionary = RunData.dummy_player_effects
	var stat_text: = tr("BROLAB_GUIDE_EXAMPLE")
	var item_text: = tr("BROLAB_ITEMS_GUIDE_EXAMPLE")
	for effect_key in effects:
		var upper_key: String = effect_key.to_upper()
		var tr_key: String = tr(upper_key)
		
		if upper_key == tr_key:
			if SPECIFIC_KEYS.has(effect_key):
				var text_key: String = SPECIFIC_KEYS[effect_key].to_upper()
				tr_key = "%s - %s" % [tr(text_key), text_key]
			else:
				continue
		
		stat_text += "\n%s - %s" % [effect_key, tr_key]
	
	var items: Array = ItemService.items
	var weapons: Array = ItemService.weapons
	for item in items:
		item_text += "\n%s - %s" % [item.my_id, tr(item.name)]
	for weapon in weapons:
		item_text += "\n%s - %s %s" % [weapon.my_id, tr(weapon.name), ItemService.get_tier_number(weapon.tier)]
	
	example_stat_label.text = stat_text
	example_item_label.text = item_text


func _on_BackButton_pressed():
	emit_signal("back_button_pressed")
