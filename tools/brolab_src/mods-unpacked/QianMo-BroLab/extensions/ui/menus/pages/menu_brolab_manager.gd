extends VBoxContainer


signal back_button_pressed


var INVENTORY_ELEMENT_SCENE: PackedScene

onready var items_container_grid: GridContainer = $HBoxContainer/VBoxItemsContainer/ItemsContainer/VBoxContainer/GridContainer
onready var search_edit: LineEdit = $HBoxContainer/VBoxItemsContainer/SearchContainer/SearchEdit
onready var preview_rich_text: RichTextLabel = $HBoxContainer/VBoxPreviewContainer/RichTextLabel
onready var actions_info: RichTextLabel = $HBoxContainer/VBoxActionsContainer/ActionsInfo
onready var delete_button: Button = $HBoxContainer/VBoxActionsContainer/DeleteButton
onready var show_button: Button = $HBoxContainer/VBoxPreviewContainer/ShowButton
onready var load_button: Button = $HBoxContainer/VBoxActionsContainer/LoadButton

var BrolabManager
var menu_brolab
var brolab_title_screen
#var BrolabNavigationMenu
var _file_items_dict: Dictionary = {} # Store the <file_name, item_data>
var _is_inited: = false
var _file_name_mapping: Dictionary
var _current_selected = null
var _item_elements: Array = []
var _show_preview: = false
var _raw_datas: Dictionary = {}


func _ready()->void :
	INVENTORY_ELEMENT_SCENE = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/brolab_inventory_element.tscn")
	
	BrolabManager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")
	
	# /root/TitleScreen/Menus/BrolabNavigationMenu
#	BrolabNavigationMenu = get_node_or_null("/root/TitleScreen/MarginContainer/Menus/BrolabNavigationMenu")
#	if BrolabNavigationMenu == null:
#		BrolabNavigationMenu = get_node("/root/TitleScreen/Menus/BrolabNavigationMenu")
	
	menu_brolab = get_node("/root/TitleScreen/Menus/MenuOptions/Buttons/HBoxContainer3/TabContainer/BrolabScrollContainer/MenuBroLab")
	brolab_title_screen = get_node("/root/TitleScreen")


func init()->void :
	if _is_inited:
		return
	
	_is_inited = true
	
	refresh()


func refresh()->void :
	init()
	
	var content_data_dict: Dictionary = BrolabManager.get_content_data_dict(true, false)
	
	if content_data_dict.empty():
		return
	
	for item in items_container_grid.get_children():
		item.queue_free()
	_item_elements.clear()
	
	_file_name_mapping = content_data_dict.file_name_mapping
	_raw_datas = content_data_dict.raw_datas
	
	var index: int = -1
	for character in content_data_dict.characters:
		index += 1
		
		var element = INVENTORY_ELEMENT_SCENE.instance()
		element.init()
		element.set_element(character)
		element.connect("element_pressed", self, "_on_item_element_pressed", [index])
		
		items_container_grid.add_child(element)
		
		_item_elements.append(element)
	for item in content_data_dict.items:
		index += 1
		
		var element = INVENTORY_ELEMENT_SCENE.instance()
		element.init()
		element.set_element(item)
		element.connect("element_pressed", self, "_on_item_element_pressed", [index])
		
		items_container_grid.add_child(element)
		
		_item_elements.append(element)
	
	delete_button.hide()
	load_button.hide()
	show_button.hide()
	actions_info.clear()
	display_preview(false)


func _on_item_element_pressed(element, index: int)->void :
	_current_selected = element
	
	delete_button.show()
	load_button.show()
	
	actions_info.clear()
	
	show_button.show()
	
	_show_preview = true
	_on_ShowButton_pressed()
	
	var item = element.item
	
	preview_rich_text.clear()
	preview_rich_text.append_bbcode("[center][b][color=yellow]%s[/color][/b][/center]\n" % tr(item.name))
	
	if item is CharacterData:
		preview_rich_text.append_bbcode("[center][color=#00ff00]%s[/color][/center]\n" % tr("CHARACTER"))
	else:
		preview_rich_text.append_bbcode("[center][color=#00ff00]%s[/color][/center]\n" % tr("ITEM"))


func _on_BackButton_pressed():
	emit_signal("back_button_pressed")


func _on_SearchButton_pressed():
	var search_keyword: String = search_edit.text
	if search_keyword == "":
		return
	
	for element in _item_elements:
		if is_instance_valid(element):
			var tr_name: String = tr(element.item.name)
			if not tr_name.find(search_keyword) == -1:
				if not element.visible:
					element.show()
			else:
				if element.visible:
					element.hide()


func _on_SearchEdit_text_changed(new_text: String):
	if new_text == "":
		for element in _item_elements:
			if is_instance_valid(element) and not element.visible:
				element.show()


func _on_LoadButton_pressed():
	var file_name: String = _file_name_mapping.get(_current_selected.item)
	var raw_data: Dictionary = _raw_datas[file_name]
	
#	BrolabNavigationMenu._on_manager_back_button_pressed()
#	BrolabNavigationMenu._on_EditorButton_pressed()
#	menu_brolab_menus.switch(self, menu_brolab)
	brolab_title_screen.emit_signal("menu_brolab_menus_page_switched", self, menu_brolab)
	menu_brolab.load_from_raw_data(raw_data)


func _on_DeleteButton_pressed():
	actions_info.clear()
	show_button.hide()
	
	if not is_instance_valid(_current_selected):
		actions_info.append_bbcode(tr("BROLAB_DELETE_SUCCESS"))
		return
	
	var file_name: String = _file_name_mapping.get(_current_selected.item)
	
	# Hot delete
	var item_data = _current_selected.item
	var item_to_be_removed = null
	var remove_index: int = -1
	if item_data is CharacterData:
		var characters: Array = ItemService.characters
		for i in characters.size():
			var character: CharacterData = characters[i]
			if character.my_id == item_data.my_id:
				remove_index = i
				ProgressData.characters_unlocked.erase(item_data.my_id)
				break
		if not remove_index == -1:
			characters.remove(remove_index)
	else:
		var items: Array = ItemService.items
		for i in items.size():
			var item = items[i]
			if item.my_id == item_data.my_id:
				remove_index = i
				ProgressData.items_unlocked.erase(item_data.my_id)
				break
		if not remove_index == -1:
			items.remove(remove_index)
			ItemService.init_unlocked_pool()
	
	if not file_name == null:
		var delete_success: bool = BrolabManager.delete_file(file_name)
		var raw_data: Dictionary = _raw_datas[file_name]
		if raw_data.has("relative_icon_path"):
			var icon_name: String = raw_data.relative_icon_path.get_file()
			var delete_icon_success: bool = BrolabManager.delete_file(icon_name, "icons")
			if not delete_icon_success:
				actions_info.append_bbcode(tr("BROLAB_DELETE_ICON_FAILED"))
		
		if delete_success:
			actions_info.append_bbcode(tr("BROLAB_DELETE_SUCCESS"))
			
			delete_button.hide()
			load_button.hide()
			
			preview_rich_text.clear()
			_item_elements.erase(_current_selected)
			_current_selected.queue_free()
		else:
			actions_info.append_bbcode(tr("BROLAB_DELETE_FAILED"))
	else:
		actions_info.append_bbcode(tr("BROLAB_DELETE_SUCCESS"))


func _on_ShowButton_pressed():
	display_preview(not _show_preview)
	
	if _show_preview:
		show_button.text = "BROLAB_HIDE_PREVIEW"
	else:
		show_button.text = "BROLAB_SHOW_PREVIEW"


func display_preview(show: bool = true)->void :
	if show:
		if not is_instance_valid(_current_selected):
			return
		
		if _show_preview:
			return
		
		_show_preview = true
		
		var item = _current_selected.item
		
		preview_rich_text.clear()
		preview_rich_text.append_bbcode("[center][b][color=yellow]%s[/color][/b][/center]\n" % tr(item.name))
		
		if item is CharacterData:
			preview_rich_text.append_bbcode("[center][color=#00ff00]%s[/color][/center]\n" % tr("CHARACTER"))
		else:
			preview_rich_text.append_bbcode("[center][color=#00ff00]%s[/color][/center]\n" % tr("ITEM"))
			
		preview_rich_text.append_bbcode(item.get_effects_text(0))
		
		preview_rich_text.append_bbcode("\n")
	else:
		if not _show_preview:
			return
		
		_show_preview = false
		
		preview_rich_text.clear()


func _on_RefreshButton_pressed():
	refresh()


func _on_FixSaveButton_pressed():
	BrolabManager.fix_lag_save()
