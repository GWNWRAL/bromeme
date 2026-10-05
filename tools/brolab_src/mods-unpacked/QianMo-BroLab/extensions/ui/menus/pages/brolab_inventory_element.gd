extends "res://items/global/inventory_element.gd"


var _locked_icon = null


func init()->void :
	_icon = get_node("Icon")
	_curse = get_node("MarginContainer/Curse")
	_baned = get_node("Baned")


func set_element(item_data: Resource)->void :
	item = item_data
	_icon.texture = item_data.get_icon()
	
	if not _icon or not is_instance_valid(_icon):
		_icon = get_node("Icon")
	if not _curse or not is_instance_valid(_curse):
		_curse = get_node("MarginContainer/Curse")
	if not _baned or not is_instance_valid(_baned):
		_baned = get_node("Baned")
	
	update_background_color()
	update_banned_item()
	current_number = 1

	if item_data is ItemParentData and item_data.is_cursed:
		_curse.visible = true
	else :
		_curse.visible = false


func update_banned_item()->void :
	return
#	if display_banned <= 0:
#		_baned.visible = false
#		return 
#
#	var show_banned: = false
#	if RunData.players_data[player_index].banned_items.has(item.my_id):
#		show_banned = true
#	elif item is WeaponData and RunData.players_data[player_index].banned_items.has(item.weapon_id):
#		show_banned = true
#
#	if show_banned:
#		_baned.modulate = Color(ProgressData.settings.color_negative)
#		_baned.modulate.a = display_banned
#		_baned.visible = true
#	else :
#		_baned.visible = false


func set_unlocked(unlocked: bool) -> void:
	if _locked_icon == null or not is_instance_valid(_locked_icon):
		_locked_icon = TextureRect.new()
		_locked_icon.name = "LockedIcon"
		_locked_icon.texture = load("res://items/global/locked_icon.png")
		_locked_icon.expand = true
		_locked_icon.rect_size = Vector2(48, 48)
		_locked_icon.rect_position = Vector2(48, 0)
		add_child(_locked_icon)
	
	if not _locked_icon == null and is_instance_valid(_locked_icon):
		if not unlocked:
			_locked_icon.show()
		else:
			_locked_icon.hide()


func set_cursed(item_data: Resource)->void :
	if item_data is ItemParentData and item_data.is_cursed:
		_curse.visible = true
	else :
		_curse.visible = false


func brolab_update_background_color(color: Color) -> void:
	var stylebox_color = get_stylebox("normal").duplicate()
	stylebox_color.bg_color = Color(color.r, color.g, color.b, 0.25)
	add_stylebox_override("normal", stylebox_color)
