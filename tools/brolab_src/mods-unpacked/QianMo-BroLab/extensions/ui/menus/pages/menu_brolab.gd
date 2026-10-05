extends VBoxContainer


signal back_button_pressed


const LOG_NAME: = "BroLab"

var EDITOR_ENTRY_SCRIPT: Script

var INVENTORY_ELEMENT_SCENE: PackedScene
var DEFAULT_ITEM_ICON: StreamTexture
var DEFAULT_CHARACTER_ICON: StreamTexture

onready var base_characters_container: GridContainer = $HBoxContainer/VBoxChractersContainer/CharactersContainer/VBoxContainer/GridContainer
onready var search_edit: LineEdit = $HBoxContainer/VBoxChractersContainer/SearchContainer/SearchEdit
onready var editor_entries_container: VBoxContainer = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer
onready var example_entry: VBoxContainer = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/Entry
onready var added_entries_container: VBoxContainer = $HBoxContainer/VBoxAddedContainer/AddedContainer/VBoxContainer
onready var id_editor: LineEdit = $HBoxContainer/VBoxGeneratorContainer/IdEditor/LineEdit
onready var name_editor: LineEdit = $HBoxContainer/VBoxGeneratorContainer/NameEditor/LineEdit
onready var price_editor: LineEdit = $HBoxContainer/VBoxGeneratorContainer/PriceEditor/LineEdit
onready var tier_editor: OptionButton = $HBoxContainer/VBoxGeneratorContainer/TierEditor/OptionButton
onready var role_editor: OptionButton = $HBoxContainer/VBoxGeneratorContainer/RoleEditor/OptionButton
onready var cursed_editor: OptionButton = $HBoxContainer/VBoxGeneratorContainer/CurseEditor/OptionButton
onready var generator_info: RichTextLabel = $HBoxContainer/VBoxGeneratorContainer/Info
onready var max_nb_editor: LineEdit = $HBoxContainer/VBoxGeneratorContainer/MaxNBEditor/LineEdit
onready var tags_editor = $HBoxContainer/VBoxGeneratorContainer/TagsEditor/TagsArrayEditor
onready var wanted_tags_editor = $HBoxContainer/VBoxGeneratorContainer/WTagsEditor/WantedTagsArrayEditor
onready var preview_inventory_element = $HBoxContainer/VBoxAddedContainer/PreviewContainer/IconPreview
onready var tags_preview: Label = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/TagsContainer/TagsPreview
onready var wanted_tags_preview: Label = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/WantedTagsContainer/WantedTagsPreview
onready var name_preview: Label = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/NameContainer/NamePreview
onready var price_preview: Label = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/PriceContainer/PricePreview
onready var preview_text: RichTextLabel = $HBoxContainer/VBoxAddedContainer/PreviewContainer/RichTextLabel
onready var search_button: Button = $HBoxContainer/VBoxChractersContainer/SearchContainer/SearchButton
onready var id_preview: LineEdit = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/IdContainer/IdPreview
onready var starting_weapons_preview: Label = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/StartingWeaponsContainer/WeaponsPreview
onready var weapon_selection_button: Button = $HBoxContainer/VBoxAddedContainer/AddedContainer/VBoxContainer/WeaponSelectionButton
onready var add_weapon_button: Button = $HBoxContainer/VBoxChractersContainer/SearchContainer/AddWeaponButton
onready var remove_weapon_button: Button = $HBoxContainer/VBoxChractersContainer/SearchContainer/RemoveWeaponButton
onready var select_base_label: Label = $HBoxContainer/VBoxChractersContainer/Label
onready var weapon_effect_label: RichTextLabel = $HBoxContainer/VBoxEditorContainer/EditorContainer/VBoxContainer/WeaponEffectLabel
onready var file_dialog: FileDialog = $HBoxContainer/FileDialog

var BrolabManager

var _is_inited: bool = false
var _last_entries: Array = []
var _selected_effects: Array = []
var _selected_effects_entries: Array = []
var _changed_keys_dict: Dictionary = {}
var _changed_key_values_dict: Dictionary = {} # use for non-effect value (can't get from effect by property_name)
var _orginal_resource_paths_dict: Dictionary = {}
var _icon_image_path: = ""
var _preview_item_data = null

var _input_delay_timer: Timer

var _characters_items_element_select_cache: Array = []
var _weapons_element_select_cache: Array = []

var _current_edit = "items"
var _current_type = "characters"

var _starting_weapons_selected: bool = false
var _selected_starting_weapons: Array = []
var _current_selected_weapon = null

var _fixed_chactacter_elements: Array = []
var _fixed_item_elements: Array = []

var _brolab_elements: Array = []


func _ready()->void :
	EDITOR_ENTRY_SCRIPT = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/editor_entry.gd")
	INVENTORY_ELEMENT_SCENE = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/brolab_inventory_element.tscn")
	DEFAULT_ITEM_ICON = load("res://items/all/acid/acid_icon.png")
	DEFAULT_CHARACTER_ICON = load("res://items/characters/well_rounded/well_rounded_icon.png")
	
	tags_editor.init([])
	wanted_tags_editor.init([])
	
	var _error_price = price_editor.connect("text_changed", self, "_on_number_editor_text_changed", [price_editor])
	var _error_max_nb = max_nb_editor.connect("text_changed", self, "_on_number_editor_text_changed", [max_nb_editor])
	var _error_tier = tier_editor.connect("item_selected", self, "_on_item_tier_selected")
	var _error_role = role_editor.connect("item_selected", self, "_on_item_type_selected")
	var _error_name = name_editor.connect("text_changed", self, "_on_item_name_changed")
	var _error_cursed = cursed_editor.connect("item_selected", self, "_on_item_cursed_selected", [cursed_editor])
	
	preview_inventory_element.init()
	_preview_item_data = ItemData.new()
	_preview_item_data.icon = DEFAULT_CHARACTER_ICON
	_preview_item_data.is_cursed = false
	preview_inventory_element.set_element(_preview_item_data)
	
	BrolabManager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")
	
	_input_delay_timer = Timer.new()
	_input_delay_timer.autostart = false
	_input_delay_timer.one_shot = true
	_input_delay_timer.wait_time = 0.5
	add_child(_input_delay_timer)
	
	refresh_preview_text()


func _input(event: InputEvent):
	if (event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER) or 
		event is InputEventJoypadButton and event.button_index == JOY_XBOX_A):
		if _input_delay_timer.is_stopped():
			_input_delay_timer.start()
			if not search_edit.text.empty():
				search_button.emit_signal("pressed")


func _on_number_editor_text_changed(new_text: String, instance: LineEdit)->void :
	if not new_text.begins_with("-") and not new_text.is_valid_integer():
		instance.delete_char_at_cursor()
	
	refresh_preview_text()


func init()->void :
	if _is_inited:
		return
	
	if not _is_inited:
		_is_inited = true
	
	if BrolabManager.get_settings().get("BROLAB_ENABLE_SPECIAL_MECHANISMS", false):
		var element = INVENTORY_ELEMENT_SCENE.instance()
		var character = load("res://mods-unpacked/QianMo-BroLab/contents/characters/1/brolab_virtual_character_data.tres")
		element._icon = element.get_node("Icon")
		element._curse = element.get_node("MarginContainer/Curse")
		element._baned = element.get_node("Baned")
		element.set_element(character)
		element.connect("element_pressed", self, "_on_item_element_pressed")
		
		base_characters_container.add_child(element)
		
		_characters_items_element_select_cache.push_back(element)
		
		element.brolab_update_background_color(Utils.CURSE_COLOR)
		
		_fixed_chactacter_elements.push_back(element)
	
	for character in ItemService.characters:
		# Ignore Brolab's Creatation
		var element = INVENTORY_ELEMENT_SCENE.instance()
		
		if character.my_id.begins_with("character_brolab_"):
			character = character.duplicate()
#			character.effects = []
			character.name = "%s (%s)" % [tr(character.name), tr("BROLAB_NOT_EDITIABLE")]
			_brolab_elements.push_back(element)
		
		element._icon = element.get_node("Icon")
		element._curse = element.get_node("MarginContainer/Curse")
		element._baned = element.get_node("Baned")
		element.set_element(character)
		element.connect("element_pressed", self, "_on_item_element_pressed")
		
		base_characters_container.add_child(element)
		
		_characters_items_element_select_cache.push_back(element)
	
	for item in ItemService.items:
		# Ignore Brolab's Creatation
		var element = INVENTORY_ELEMENT_SCENE.instance()
		
		if item.my_id.begins_with("item_brolab_"):
			item = item.duplicate()
#			item.effects = []
			item.name = "%s (%s)" % [tr(item.name), tr("BROLAB_NOT_EDITIABLE")]
			_brolab_elements.push_back(element)
		
		element._icon = element.get_node("Icon")
		element._curse = element.get_node("MarginContainer/Curse")
		element._baned = element.get_node("Baned")
		element.set_element(item)
		element.connect("element_pressed", self, "_on_item_element_pressed")
		
		base_characters_container.add_child(element)
		
		_characters_items_element_select_cache.push_back(element)
	
	for ele in _brolab_elements:
		base_characters_container.move_child(ele, _fixed_chactacter_elements.size() + _fixed_item_elements.size())


func refresh_base_element_container() -> void:
	init()
	
	for ele in _characters_items_element_select_cache:
		if is_instance_valid(ele) and not _fixed_chactacter_elements.has(ele) and not _fixed_item_elements.has(ele):
			ele.queue_free()
	_characters_items_element_select_cache.clear()
	_brolab_elements.clear()
	
	for character in ItemService.characters:
		# Ignore Brolab's Creatation
		var element = INVENTORY_ELEMENT_SCENE.instance()
		
		if character.my_id.begins_with("character_brolab_"):
			character = character.duplicate()
#			character.effects = []
			character.name = "%s (%s)" % [tr(character.name), tr("BROLAB_NOT_EDITIABLE")]
			_brolab_elements.push_back(element)
		
		element._icon = element.get_node("Icon")
		element._curse = element.get_node("MarginContainer/Curse")
		element._baned = element.get_node("Baned")
		element.set_element(character)
		element.connect("element_pressed", self, "_on_item_element_pressed")
		
		base_characters_container.add_child(element)
		
		_characters_items_element_select_cache.push_back(element)
	
	for ele in _fixed_chactacter_elements:
		base_characters_container.move_child(ele, base_characters_container.get_child_count() - 1)
	
	for item in ItemService.items:
		# Ignore Brolab's Creatation
		var element = INVENTORY_ELEMENT_SCENE.instance()
		
		if item.my_id.begins_with("item_brolab_"):
			item = item.duplicate()
#			item.effects = []
			item.name = "%s (%s)" % [tr(item.name), tr("BROLAB_NOT_EDITIABLE")]
			_brolab_elements.push_back(element)
		
		element._icon = element.get_node("Icon")
		element._curse = element.get_node("MarginContainer/Curse")
		element._baned = element.get_node("Baned")
		element.set_element(item)
		element.connect("element_pressed", self, "_on_item_element_pressed")
		
		base_characters_container.add_child(element)
		
		_characters_items_element_select_cache.push_back(element)
	
	_characters_items_element_select_cache.append_array(_fixed_chactacter_elements)
	_characters_items_element_select_cache.append_array(_fixed_item_elements)
	
	for ele in _fixed_chactacter_elements:
		base_characters_container.move_child(ele, 0)
	for ele in _fixed_item_elements:
		base_characters_container.move_child(ele, 0)
	
	for ele in _brolab_elements:
		base_characters_container.move_child(ele, _fixed_chactacter_elements.size() + _fixed_item_elements.size())
	
	if _current_edit == "weapons":
		for ele in _characters_items_element_select_cache:
			if ele.visible:
				ele.hide()


func load_from_raw_data(raw_data: Dictionary)->void :
	for effect in _selected_effects.duplicate():
		_on_want_to_remove_effect(effect)
	for entry in _selected_effects_entries:
		if is_instance_valid(entry):
			entry.queue_free()
	_selected_effects_entries.clear()
	
	var tags_text: = ""
	for tag in raw_data.tags:
		tags_text += "%s\n" % tag
	tags_preview.text = tags_text.trim_suffix("\n")
	
	if raw_data.item_type == 0:
		var wanted_tags_text: = ""
		for tag in raw_data.wanted_tags:
			wanted_tags_text += "%s\n" % tag
		wanted_tags_preview.text = wanted_tags_text.trim_suffix("\n")
	else:
		wanted_tags_preview.text = ""
	
	var tr_name: = tr(raw_data.name)
	name_preview.text = tr_name
	price_preview.text = str(raw_data.price)
	
	name_editor.text = raw_data.name
	price_editor.text = str(raw_data.price)
	max_nb_editor.text = str(raw_data.max_nb)
	tier_editor.select(raw_data.tier)
	tier_editor.emit_signal("item_selected", raw_data.tier)
	role_editor.select(raw_data.item_type)
	role_editor.emit_signal("item_selected", raw_data.item_type)
	tags_editor.init(raw_data.tags)
	cursed_editor.select(raw_data.get("unlocked_by_default", 0))
	cursed_editor.emit_signal("item_selected", raw_data.get("unlocked_by_default", 0))
	wanted_tags_editor.init(raw_data.wanted_tags)
	
	if raw_data.has("relative_icon_path"):
		var icon_path: String = BrolabManager.BASE_SAVE_PATH.plus_file(raw_data.relative_icon_path)
		var image: = Image.new()
		var error_load_image = image.load(icon_path)
		if error_load_image == OK:
			var texture: = ImageTexture.new()
			texture.create_from_image(image)
			preview_inventory_element.set_icon(texture)
			
			_icon_image_path = icon_path
	
	var effects: = []
	var default_key_values: = {}
	var datas: Array = raw_data.datas
	for i in datas.size():
		var data: Dictionary = datas[i]
		if data.base_resource_path == null or data.base_resource_path.empty():
			continue
		var effect: Resource = load(data.base_resource_path)
		effects.append(effect)
		
		if not data.changed_key_values.empty():
			default_key_values[i] = data.changed_key_values
	
	init_editor_effects(effects, default_key_values)
	
	for entry in _last_entries:
		entry._on_add_button_pressed()
	
	refresh_preview_text()


func refresh_preview_text()->void :
	preview_text.clear()
	preview_text.append_bbcode("%s\n" % tr(name_editor.text))
	match role_editor.get_selected_id():
		0:
			preview_text.append_bbcode("[color=#%s]%s[/color]" % [Utils.SECONDARY_FONT_COLOR.to_html(false), tr("CHARACTER")])
		_:
			var max_nb: int = int(max_nb_editor.text)
			if max_nb > 1:
				preview_text.append_bbcode("[color=#%s]%s[/color]" % [Utils.SECONDARY_FONT_COLOR.to_html(false), Text.text("LIMITED", [str(max_nb), str(max_nb)])])
			elif max_nb == 1:
				preview_text.append_bbcode("[color=#%s]%s[/color]" % [Utils.SECONDARY_FONT_COLOR.to_html(false), tr("UNIQUE")])
			else:
				preview_text.append_bbcode("[color=#%s]%s[/color]" % [Utils.SECONDARY_FONT_COLOR.to_html(false), tr("ITEM")])
	preview_text.append_bbcode("\n")
	preview_text.append_bbcode("%s: %d" % [tr("BROLAB_SET_PRICE"), max(1, int(price_editor.text))])


# default_key_values is Dictionary, schema is {$index$: {$key$: value}}
func init_editor_effects(effects: Array, default_key_values: Dictionary = {}, only_preview: bool = false)->void :
	if not _last_entries.empty():
		for _last_entry in _last_entries:
			if is_instance_valid(_last_entry):
				_last_entry.queue_free()
		_last_entries.clear()
	
	for i in effects.size():
		var effect = effects[i]
		
		var default_key_value: Dictionary = {}
		if default_key_values.has(i):
			default_key_value = default_key_values[i]
		
		var datas: Array = BrolabManager.get_editable_datas_from_resource(effect, default_key_value)
		
		var duplicated_entry: VBoxContainer = example_entry.duplicate()
		_last_entries.append(duplicated_entry)
		editor_entries_container.add_child(duplicated_entry)
		duplicated_entry.set_only_preview(only_preview)
		duplicated_entry.init(effect.get_text(0), datas, effect, default_key_value.keys())
		
		var _error_connect_add = duplicated_entry.connect("want_to_add_effect", self, "_on_want_to_add_effect")


func _on_item_element_pressed(element)->void :
	if _current_edit == "items":
		var item_data = element.item
		
		var tags_text: = ""
		for tag in item_data.tags:
			tags_text += "%s\n" % tag
		tags_preview.text = tags_text.trim_suffix("\n")
		
		if item_data is CharacterData:
			if not _starting_weapons_selected:
				_selected_starting_weapons = item_data.starting_weapons
				
				starting_weapons_preview.text = ""
				var starting_weapons = item_data.starting_weapons
				var text_array: Array = []
				if starting_weapons and not starting_weapons.empty():
					for weapon_data in starting_weapons:
						text_array.append(weapon_data.get_name_text())
					starting_weapons_preview.text = ",".join(text_array)
			
			var wanted_tags_text: = ""
			for tag in item_data.wanted_tags:
				wanted_tags_text += "%s\n" % tag
			wanted_tags_preview.text = wanted_tags_text.trim_suffix("\n")
		else:
			wanted_tags_preview.text = ""
			
			if not _starting_weapons_selected:
				starting_weapons_preview.text = ""
				_selected_starting_weapons = []
		
		name_preview.text = tr(item_data.name)
		price_preview.text = str(item_data.value)
		id_preview.text = str(item_data.my_id)
		
		var effects: Array = item_data.effects
		
		if item_data.my_id.begins_with("character_brolab_") or item_data.my_id.begins_with("item_brolab_"):
			init_editor_effects(effects, {}, true)
		else:
			init_editor_effects(effects)
		
		weapon_effect_label.hide()
	elif _current_edit == "weapons":
		var weapon_data = element.item
		
		_current_selected_weapon = weapon_data
		
		init_editor_effects([])
		
		id_preview.text = weapon_data.my_id
		name_preview.text = weapon_data.get_name_text()
		price_preview.text = str(weapon_data.value)
		tags_preview.text = ""
		wanted_tags_preview.text = ""
		
		weapon_effect_label.bbcode_text = "\n"
		weapon_effect_label.append_bbcode(weapon_data.get_weapon_stats_text(0))
		weapon_effect_label.append_bbcode("\n\n")
		weapon_effect_label.append_bbcode(weapon_data.get_effects_text(0))
		weapon_effect_label.show()


func _on_want_to_add_effect(effect: Resource, entry: VBoxContainer, changed_keys: Array = [], original_resource_path: String = "", non_effect_values: Dictionary = {})->void :
	var duplicated_entry: VBoxContainer = example_entry.duplicate()
	
	added_entries_container.add_child(duplicated_entry)
	
	_selected_effects.append(effect)
	
	_changed_keys_dict[effect] = changed_keys.duplicate()
	if not non_effect_values.empty():
		_changed_key_values_dict[effect] = non_effect_values
	
	_orginal_resource_paths_dict[effect] = original_resource_path
	
	duplicated_entry.set_description(entry.get_description())
	duplicated_entry.set_editable(false)
	duplicated_entry.set_enabled(true)
	duplicated_entry._effect = effect
	
	_selected_effects_entries.append(duplicated_entry)
	
	var _error_connect_remove = duplicated_entry.connect("want_to_remove_effect", self, "_on_want_to_remove_effect")


func _on_want_to_remove_effect(effect: Resource, entry: VBoxContainer = null)->void :
	for i in _selected_effects.size():
		if _selected_effects[i] == effect:
			_selected_effects.remove(i)
			break
	if not _selected_effects.has(effect):
		_changed_key_values_dict.erase(effect)
		_changed_keys_dict.erase(effect)
		_orginal_resource_paths_dict.erase(effect)
	
	if not entry == null:
		_selected_effects_entries.erase(entry)


func _on_SearchButton_pressed():
	var search_keyword: String = search_edit.text
	if search_keyword.empty():
		return
	
	search_keyword = search_keyword.to_lower()
	
	if _current_edit == "items":
		for element in _characters_items_element_select_cache:
			var tr_name: String = tr(element.item.name).to_lower()
			if not tr_name.find(search_keyword) == -1:
				if not element.visible:
					element.show()
			else:
				if element.visible:
					element.hide()
	elif _current_edit == "weapons":
		for element in _weapons_element_select_cache:
			var tr_name: String = element.item.get_name_text().to_lower()
			if not tr_name.find(search_keyword) == -1:
				if not element.visible:
					element.show()
			else:
				if element.visible:
					element.hide()


func _on_SearchEdit_text_changed(new_text: String):
	if new_text == "":
		if _current_edit == "items":
			for element in _characters_items_element_select_cache:
				if not element.visible:
					element.show()
		elif _current_edit == "weapons":
			for element in _weapons_element_select_cache:
				if not element.visible:
					element.show()


func _on_GeneratorButton_pressed():
	generator_info.clear()
	var is_valid: bool = true
	if id_editor.text == "":
		is_valid = false
		generator_info.append_bbcode("[color=#ff0000]%s[/color]\n" % tr("BROLAB_NEED_ID_INFO"))
	if name_editor.text == "":
		is_valid = false
		generator_info.append_bbcode("[color=#ff0000]%s[/color]\n" % tr("BROLAB_NEED_NAME_INFO"))
	if price_editor.text == "":
		is_valid = false
		generator_info.append_bbcode("[color=#ff0000]%s[/color]\n" % tr("BROLAB_NEED_PRICE_INFO"))
	
	if not is_valid:
		return
	
	var data_to_store: Dictionary = {}
	data_to_store["name"] = name_editor.text
	data_to_store["price"] = max(int(price_editor.text), 1) as int
	
	var max_nb: = int(max_nb_editor.text)
	if max_nb <= 0:
		max_nb = -1
	data_to_store["max_nb"] = max(max_nb, -1) as int
	
	data_to_store["tier"] = tier_editor.get_selected_id()
	data_to_store["item_type"] = role_editor.get_selected_id()
	data_to_store["unlocked_by_default"] = cursed_editor.get_item_id(cursed_editor.get_selected_id())
	
	var my_id: String = ""
	if data_to_store["item_type"] == 0:
		my_id = "character_brolab_" + id_editor.text + "_" + str(randi() % 512)
	else:
		my_id = "item_brolab_" + id_editor.text + "_" + str(randi() % 512)
	data_to_store["my_id"] = my_id
	
	data_to_store["tags"] = tags_editor.get_array()
	data_to_store["wanted_tags"] = wanted_tags_editor.get_array()
	
	data_to_store["datas"] = []
	
	if data_to_store["item_type"] == 0 and _starting_weapons_selected and _selected_starting_weapons and not _selected_starting_weapons.empty():
		var starting_weapons_id_array = []
		for weapon_data in _selected_starting_weapons:
			if weapon_data:
				starting_weapons_id_array.append(weapon_data.my_id)
		data_to_store["starting_weapons"] = starting_weapons_id_array
	
	for effect in _selected_effects:
		if effect == null or not is_instance_valid(effect) or not _changed_keys_dict.has(effect):
			continue
		var original_resource_path: String = _orginal_resource_paths_dict[effect]
		var changed_keys: Array = _changed_keys_dict[effect]
		
		var data: Dictionary = {}
		var changed_key_values: Dictionary = {}
		data["base_resource_path"] = original_resource_path
		
		var non_effect_changed_key_values: Dictionary = {}
		if _changed_key_values_dict.has(effect):
			non_effect_changed_key_values = _changed_key_values_dict[effect]
		
		for key in changed_keys:
			if key.ends_with("_RESOURCE"):
				if non_effect_changed_key_values.has(key):
					changed_key_values[key] = non_effect_changed_key_values[key]
			else:
				changed_key_values[key] = effect.get(key)
		data["changed_key_values"] = changed_key_values
		
		data_to_store.datas.append(data)
	
	var file_name: String
	file_name = str(int(Time.get_unix_time_from_system()))
	if not _icon_image_path.empty():
		var image: = Image.new()
		var error_load_image = image.load(_icon_image_path)
		if error_load_image == OK:
			var icon_name: = file_name + ".png"
			var save_icon_success: bool = BrolabManager.save_buffer(image.save_png_to_buffer(), icon_name, "icons")
			if not save_icon_success:
				generator_info.append_bbcode(tr("BROLAB_SAVE_ICON_FAILED"))
			else:
				data_to_store["relative_icon_path"] = "icons/" + icon_name
	
	# Hot apply
	var item_data = BrolabManager.deserialize_item_data_from_data(data_to_store)
	if not item_data == null:
		if item_data is CharacterData:
			BrolabManager.add_item(item_data, "character")
		else:
			BrolabManager.add_item(item_data, "item")
		var translation: Translation = Translation.new()
		translation.add_message(item_data.my_id.to_upper(), tr(item_data.name))
		TranslationServer.add_translation(translation)
	
	var save_string: = JSON.print(data_to_store)
	var save_file_name: String = "%s.json" % file_name
	var save_success: bool = BrolabManager.save_file(save_string, save_file_name)
	if save_success:
		generator_info.append_bbcode(tr("BROLAB_SAVE_SUCCESS"))
	else:
		generator_info.append_bbcode(tr("BROLAB_SAVE_FAILED"))


func _on_BackButton_pressed():
	emit_signal("back_button_pressed")


func _on_SelectIconButton_pressed():
	file_dialog.popup()


func _on_FileDialog_file_selected(path: String):
	var ext_name: = path.get_extension()
	
	if (ext_name == "png" or 
		ext_name == "jpg" or 
		ext_name == "jpeg"):
		
		generator_info.clear()
		
		_icon_image_path = path
		
		var image: = Image.new()
		var error_load = image.load(path)
		if error_load == OK:
			var texture: = ImageTexture.new()
			texture.create_from_image(image)
			
			preview_inventory_element.set_icon(texture)
	else:
		generator_info.clear()
		generator_info.append_bbcode(tr("BROLAB_WRONG_IMAGE_TYPE"))


func _on_item_cursed_selected(index: int, editor: OptionButton):
	var selected_id = editor.get_item_id(index)
	match selected_id:
		0:
			_preview_item_data.unlocked_by_default = false
		1:
			_preview_item_data.unlocked_by_default = true
	
	preview_inventory_element.set_unlocked(_preview_item_data.unlocked_by_default)
	
	refresh_preview_text()


func _on_item_type_selected(index: int):
	match index:
		0:
			price_editor.text = "1"
			max_nb_editor.text = "-1"
			
			price_editor.editable = false
			max_nb_editor.editable = false
			
			tier_editor.select(0)
			tier_editor.emit_signal("item_selected", 0)
			tier_editor.disabled = true
			
			cursed_editor.disabled = true
			_preview_item_data.is_cursed = false
			preview_inventory_element.set_element(_preview_item_data)
			cursed_editor.selected = 0
			cursed_editor.emit_signal("item_selected", cursed_editor.selected)
			
			if _icon_image_path.empty():
				preview_inventory_element.set_icon(DEFAULT_CHARACTER_ICON)
		
			_current_type = "characters"
			weapon_selection_button.show()
			if _current_edit == "weapons":
				_on_WeaponSelectionButton_pressed()
		_:
			price_editor.editable = true
			price_editor.text = ""
			
			max_nb_editor.editable = true
			tier_editor.disabled = false
			
			cursed_editor.disabled = false
			
			if _icon_image_path.empty():
				preview_inventory_element.set_icon(DEFAULT_ITEM_ICON)
			
			_current_type = "items"
			weapon_selection_button.hide()
			if _current_edit == "weapons":
				_on_WeaponSelectionButton_pressed()
	
	refresh_preview_text()


func _on_item_tier_selected(index: int):
	_preview_item_data.tier = BrolabManager.get_tier_from_number(index)
	preview_inventory_element.update_background_color()


func _on_item_name_changed(_new_text):
	refresh_preview_text()


# Add Starting Weapons
func _on_AddWeaponButton_pressed():
	if not _current_type == "characters":
		return
	if not _current_selected_weapon:
		return
	if not _starting_weapons_selected:
		return
	
	for weapon_data in _selected_starting_weapons:
		if weapon_data.my_id == _current_selected_weapon.my_id:
			return
	
	_selected_starting_weapons.append(_current_selected_weapon)
	update_starting_weapons_preview()


# Remove Starting Weapons
func _on_RemoveWeaponButton_pressed():
	if not _current_type == "characters":
		return
	if not _current_selected_weapon:
		return
	if not _starting_weapons_selected:
		return
	
	for i in _selected_starting_weapons.size():
		var weapon_data = _selected_starting_weapons[i]
		if weapon_data.my_id == _current_selected_weapon.my_id:
			_selected_starting_weapons.remove(i)
			update_starting_weapons_preview()
			
			return


func update_starting_weapons_preview()->void :
	var text_array = []
	for weapon_data in _selected_starting_weapons:
		text_array.append(weapon_data.get_name_text())
	starting_weapons_preview.text = ",".join(text_array)


func _on_WeaponSelectionButton_pressed():
	if not _starting_weapons_selected:
		starting_weapons_preview.get_parent().get_node("Label").text = tr("BROLAB_STARTING_WEAPONS_LOCKED")
		
		_starting_weapons_selected = true
		# Duplicate to ensure not reference, beacause of directly get from CharacterData.starting_weapons
		_selected_starting_weapons = _selected_starting_weapons.duplicate()
	
	if _current_edit == "items":
		_current_edit = "weapons"
		
		add_weapon_button.show()
		remove_weapon_button.show()
		
		for ele in _characters_items_element_select_cache:
			ele.hide()
		
		if _weapons_element_select_cache.empty():
			for weapon_data in ItemService.weapons:
				if weapon_data.my_id.begins_with("brolab_"):
					continue
		
				var element = INVENTORY_ELEMENT_SCENE.instance()
				element._icon = element.get_node("Icon")
				element._curse = element.get_node("MarginContainer/Curse")
				element._baned = element.get_node("Baned")
				element.set_element(weapon_data)
				element.connect("element_pressed", self, "_on_item_element_pressed")
				
				base_characters_container.add_child(element)
				
				_weapons_element_select_cache.append(element)
		else:
			for ele in _weapons_element_select_cache:
				ele.show()
				
		weapon_selection_button.text = tr("BROLAB_SELECT_BASE")
		select_base_label.text = tr("WEAPON_SELECTION")
	else:
		_current_edit = "items"
		
		add_weapon_button.hide()
		remove_weapon_button.hide()
		
		for ele in _weapons_element_select_cache:
			ele.hide()
		for ele in _characters_items_element_select_cache:
			ele.show()
		
		weapon_selection_button.text = tr("WEAPON_SELECTION")
		select_base_label.text = tr("BROLAB_SELECT_BASE")


func _on_RefreshButton_pressed():
	refresh_base_element_container()


func _on_ApplyButton_pressed():
	pass # Replace with function body.
