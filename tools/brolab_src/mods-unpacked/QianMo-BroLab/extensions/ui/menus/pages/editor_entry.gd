extends VBoxContainer


signal want_to_add_effect(effect, instance, changed_keys, orginal_resource_path, non_effect_key_values)
signal want_to_remove_effect(effect, instance)

onready var description: RichTextLabel = $Description
onready var space_control: Control = $Space
onready var add_button: Button = $AddButton
onready var apply_button: Button = $ApplyButton
onready var example_key_values_container: HBoxContainer = $HBoxContainer

var _duplicated_effect: Resource = null
var _effect: Resource
var _changed_key_values: Dictionary = {}
var _need_to_refresh_effect: = false
var _key_value_editors: Array = []
var BrolabManager


func _ready()->void :
	BrolabManager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")


func init(desc: String, datas: Array, effect: Resource = null, changed_keys: Array = [])->void :
	set_enabled(true)
	
	_effect = effect
	
	description.bbcode_text = desc
	for data in datas:
		var key_value_editor = add_key_value(data, -1, changed_keys)
		if not key_value_editor.is_to_be_destroyed:
			_key_value_editors.append(key_value_editor)
		
	add_button.connect("pressed", self, "_on_add_button_pressed")
	apply_button.connect("pressed", self, "_on_apply_button_pressed")
	
	move_child(apply_button, get_child_count()-1)
	move_child(add_button, get_child_count()-1)
	move_child(space_control, get_child_count()-1)


func add_key_value(data: Dictionary, index: int, changed_keys: Array = [], connect_signal: bool = true)->HBoxContainer :
	var duplicated_key_values_container = example_key_values_container.duplicate()
	if not duplicated_key_values_container.visible:
		duplicated_key_values_container.show()
	
	add_child(duplicated_key_values_container)
	duplicated_key_values_container.init(data)
	
	if index > 0:
		move_child(duplicated_key_values_container, index)
	
	if connect_signal:
		duplicated_key_values_container.connect("on_value_changed", self, "_on_value_changed")
	
	var converted_key: String = data.key
	if data.type == BrolabManager.TYPE_WEAPON_STATS:
		converted_key += "_RESOURCE"
	if converted_key in changed_keys:
		var value = null
		if data.type == TYPE_INT or data.type == TYPE_REAL or data.type == TYPE_STRING or data.type == BrolabManager.TYPE_ENUM:
			value = str(data.value)
		elif data.type == TYPE_BOOL:
			value = data.value
		else:
			if data.type == TYPE_ARRAY:
				value = data.value
			elif data.type == BrolabManager.TYPE_WEAPON_STATS:
				var new_value = data.value
				
				if data.has("child_resource_key_values"):
					duplicated_key_values_container.set_child_resource_key_values(data.child_resource_key_values)
				
				value = duplicated_key_values_container.get_resource_value()
		if not data.type == BrolabManager.TYPE_WEAPON_STATS:
			_on_value_changed(value, data.key, data.type)
	
	return duplicated_key_values_container


func set_editor_type(type: String = "effect")->void :
	match type:
		"weapon_stats":
			add_button.hide()


func set_enabled(enabled: bool)->void :
	if enabled and not visible:
		show()
	elif not enabled and visible:
		hide()


func set_description(text: String)->void :
	description.append_bbcode(text)


func get_description()->String :
	return description.bbcode_text


func set_only_preview(only_preview: bool = false) -> void:
	if only_preview:
		add_button.hide()
		apply_button.hide()


func set_editable(editable: bool)->void :
	if not editable:
		if add_button.is_connected("pressed", self, "_on_add_button_pressed"):
			add_button.disconnect("pressed", self, "_on_add_button_pressed")
		if not add_button.is_connected("pressed", self, "_on_remove_button_pressed"):
			add_button.connect("pressed", self, "_on_remove_button_pressed")
		add_button.text = "BROLAB_REMOVE_EFFECT"
		apply_button.hide()
		
		var children: = get_children()
		var index: = 1
		var children_size: = children.size()
		while index < children_size - 3:
			children[index].queue_free()
			index += 1
	else:
		if not add_button.is_connected("pressed", self, "_on_add_button_pressed"):
			add_button.connect("pressed", self, "_on_add_button_pressed")
		if add_button.is_connected("pressed", self, "_on_remove_button_pressed"):
			add_button.disconnect("pressed", self, "_on_remove_button_pressed")
		add_button.text = "BROLAB_ADD_EFFECT"
		apply_button.show()
	
	var key_values_containers: Array = get_children()
	var size: int = key_values_containers.size()
	if size <= 5:
		return
	
	var i: int = 1
	while i < size - 3:
		key_values_containers[i].set_editable(editable)
		i += 1


func _on_value_changed(value, key: String, type: int, instance: LineEdit = null)->void :
	if type == TYPE_INT:
		if not value.begins_with("-") and not value.is_valid_integer():
			instance.delete_char_at_cursor()
	elif type == TYPE_REAL:
		if not value.begins_with("-") and not value.ends_with(".") and not value.is_valid_float():
			instance.delete_char_at_cursor()
	
	if _effect == null:
		return
	
	if _need_to_refresh_effect:
		_duplicated_effect = null
		
		for key_value_editor in _key_value_editors:
			key_value_editor.refresh()
	
	if _duplicated_effect == null:
		_duplicated_effect = _effect.duplicate()
		
		# Restore the last changed
		for key in _changed_key_values.keys():
			_duplicated_effect.set(key, _changed_key_values[key])
	
	var is_resource: bool = false
	var TYPE_WEAPON_STATS: int = BrolabManager.TYPE_WEAPON_STATS
	
	var base_resource_path: String
	var changed_key_value: Array # [key, value]
	var new_value = value
	match type:
		TYPE_INT, BrolabManager.TYPE_ENUM:
			new_value = int(value)
		TYPE_REAL:
			new_value = float(value)
		TYPE_WEAPON_STATS:
			is_resource = true
			
			base_resource_path = new_value[0]
			changed_key_value = new_value[2]
			
			new_value = new_value[1]
	
	var is_valid: = true
	
	# Validate key or custom key, but some effect key is item_id, it's hard to validate beacuse of performance
#	if key == "key" or key == "custom_key":
#		if not RunData.effects.has(new_value):
#			is_valid = false
	
	if is_valid:
		_duplicated_effect.set(key, new_value)
		
		if not is_resource:
			_changed_key_values[key] = new_value
		else:
			var current_kv: Dictionary
			var converted_key: String = key + "_RESOURCE"
			if not _changed_key_values.has(converted_key):
				current_kv = {}
			else:
				current_kv = _changed_key_values[converted_key].changed_key_values.duplicate()
			
			if not changed_key_value.empty():
				current_kv[changed_key_value[0]] = changed_key_value[1]
			
			_changed_key_values[converted_key] = {
				"base_resource_path": base_resource_path,
				"changed_key_values": current_kv
			}
		
#		description.bbcode_text = _duplicated_effect.get_text(0)


func get_current_effect()->Resource :
	if not _duplicated_effect == null:
		return _duplicated_effect
	return _effect


func get_base_effect()->Resource :
	return _effect


func _on_add_button_pressed()->void :
	var non_effect_key_values: Dictionary = {}
	for key in _changed_key_values.keys():
		if key.ends_with("_RESOURCE"):
			non_effect_key_values[key] = _changed_key_values[key]
	
	emit_signal("want_to_add_effect", get_current_effect(), self, _changed_key_values.keys(), _effect.resource_path, non_effect_key_values)
	
	_need_to_refresh_effect = true


func _on_apply_button_pressed() -> void:
	if _duplicated_effect:
		description.bbcode_text = _duplicated_effect.get_text(0)


func _on_remove_button_pressed()->void :
	emit_signal("want_to_remove_effect", get_current_effect(), self)
	
	queue_free()
