extends VBoxContainer


signal value_changed(new_value)


export (bool) var emit_signal_when_changed: bool = true
export (bool) var enable_validate: bool = true

onready var items_container: VBoxContainer = $ItemsContainer
onready var add_button: Button = $AddButton
onready var remove_button: Button = $RemoveButton
onready var show_button: Button = $ShowButton
onready var confirm_button: Button = $ConfirmButton

var array_editor_scene: PackedScene
var BrolabManager
var _array_item_type: int = -1
var _items: Array = []
var _is_displaying: = false
var _layer: = 0
var _first_item = null
var _complex_array_item_type: = [] # e.g. item is ["abc", 1.2], this value will be [TYPE_STRING, TYPE_REAL]
var _valid_keys: = []
var _array_size: = -1


func _ready()->void :
	array_editor_scene = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/brolab_array_editor.tscn")
	
	for player_data in RunData.players_data:
		var effects = player_data.effects
		for k in effects.keys():
			if not _valid_keys.has(k):
				_valid_keys.append(k)
	
	if not _valid_keys.has("materials"):
		_valid_keys.append("materials")
	
	BrolabManager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")


func init(from_array: Array, layer: int = 0, init_show: bool = false)->void :
	_layer = layer
	
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	
	if not layer == 0:
		add_button.queue_free()
		remove_button.queue_free()
		confirm_button.queue_free()
#		show_button.queue_free()
		
		var splitter: Label = Label.new()
		splitter.text = "----------"
		splitter.align = Label.ALIGN_CENTER
		add_child(splitter)
		move_child(splitter, 0)
		
		for item in from_array:
			if item is int:
				_complex_array_item_type.append(TYPE_INT)
			elif item is float:
				_complex_array_item_type.append(TYPE_REAL)
			elif item is String:
				_complex_array_item_type.append(TYPE_STRING)
	else:
		if not enable_validate and is_instance_valid(confirm_button):
			confirm_button.queue_free()
		
		if not from_array.empty():
			_first_item = from_array[0]
			
			if _first_item is String:
				_array_item_type = TYPE_STRING
			elif _first_item is int:
				_array_item_type = TYPE_INT
			elif _first_item is float:
				_array_item_type = TYPE_REAL
			elif _first_item is Array:
				_array_item_type = TYPE_ARRAY
		else:
			_array_item_type = TYPE_STRING
			_first_item = ""
	
	_array_size = from_array.size()
	for i in _array_size:
		add_item(from_array[i], i)
	
	if init_show:
		_on_ShowButton_pressed()
	else:
		_is_displaying = true
		_on_ShowButton_pressed()


func add_item(item, index: int = 0)->void :
	# Handle (Array, Array)
	if _array_item_type == TYPE_ARRAY:
		var new_editor = array_editor_scene.instance()
		items_container.add_child(new_editor)
		
		new_editor.init(item, 1, true)
#		var _error_connect = new_editor.connect("value_changed", self, "_on_child_editor_value_changed", [new_editor])
		
		_items.append(new_editor)
	else:
		var line_edit: LineEdit = LineEdit.new()
		line_edit.context_menu_enabled = false
		line_edit.text = str(item)
		items_container.add_child(line_edit)
		
		_items.append(line_edit)
		
		var _error_connect = line_edit.connect("text_changed", self, "_on_item_text_changed", [line_edit, index])


#func _on_child_editor_value_changed(value, instace)->void :
#	_on_ConfirmButton_pressed()


func _on_item_text_changed(value: String, instance: LineEdit, index: int)->void :
	if not enable_validate:
		if emit_signal_when_changed:
			emit_signal("value_changed", get_array())
		return
	
	# 1D Array if _complex_array_item_type.empty()
	if _complex_array_item_type.empty():
		if _array_item_type == TYPE_INT:
			if not value.begins_with("-") and not value.is_valid_integer():
				instance.delete_char_at_cursor()
		elif _array_item_type == TYPE_REAL:
			if not value.begins_with("-") and not value.ends_with(".") and not value.is_valid_float():
				instance.delete_char_at_cursor()
	else:
		var is_valid: = true
		_array_item_type = _complex_array_item_type[index]
		if _array_item_type == TYPE_INT:
			if not value.begins_with("-") and not value.is_valid_integer():
				instance.delete_char_at_cursor()
				is_valid = false
		elif _array_item_type == TYPE_REAL:
			if not value.begins_with("-") and not value.ends_with(".") and not value.is_valid_float():
				instance.delete_char_at_cursor()
				is_valid = false
		
		if is_valid:
			if emit_signal_when_changed:
				emit_signal("value_changed", get_array())


func set_array(array: Array)->void :
	var arr_size: int = array.size()
	var current_size: int = _items.size()
	var diff: int = abs(arr_size - current_size)
	if arr_size > current_size:
		for i in diff:
			_on_AddButton_pressed()
	else:
		for i in diff:
			_on_RemoveButton_pressed()
	
	for i in arr_size:
		var item = _items[i]
		if item is LineEdit:
			item.text = str(array[i])
			item.emit_signal("text_changed", item.text)
		else:
			item.set_array(array[i])
	
	_on_ConfirmButton_pressed()


func get_array(excluded_items: Array = [])->Array :
	var result: = []
	
	if _complex_array_item_type.empty():
		for item in _items:
			if item in excluded_items:
				continue
			match _array_item_type:
				TYPE_INT:
					result.append(int(item.text))
				TYPE_REAL:
					result.append(float(item.text))
				TYPE_STRING:
					result.append(item.text)
				TYPE_ARRAY:
					var child_result_array: Array = item.get_array(excluded_items)
					if not child_result_array.empty():
						result.append(child_result_array)
	else:
		for i in _items.size():
			_array_item_type = _complex_array_item_type[i]
			var item = _items[i]
			if item in excluded_items:
				return []
			match _array_item_type:
				TYPE_INT:
					result.append(int(item.text))
				TYPE_REAL:
					result.append(float(item.text))
				TYPE_STRING:
					result.append(item.text)
	
	return result


func _on_AddButton_pressed():
	add_item(_first_item)
	
	_on_ConfirmButton_pressed()


func _on_RemoveButton_pressed():
	if enable_validate and _items.size() <= 1:
		return
	
	var last_item = _items.pop_back()
	if is_instance_valid(last_item):
		last_item.queue_free()
	
	_on_ConfirmButton_pressed()


func _on_ShowButton_pressed():
	_is_displaying = not _is_displaying
	
	_array_size = _items.size()
	
	if _is_displaying:
		show_button.text = "BROLAB_HIDE_ARRAY"
		
		items_container.show()
		if _layer == 0:
			add_button.show()
			remove_button.show()
			
			if enable_validate:
				confirm_button.show()
	else:
		show_button.text = Text.text("BROLAB_SHOW_ARRAY", [str(_array_size)])
		
		items_container.hide()
		if _layer == 0:
			add_button.hide()
			remove_button.hide()
			
			if enable_validate:
				confirm_button.hide()


func validate_key() :
	if _complex_array_item_type.empty():
		if _array_item_type == TYPE_STRING:
			for item in _items:
				var item_text: String = item.text
				if not _valid_keys.has(item_text):
					return item
	else:
		for i in _items.size():
			_array_item_type = _complex_array_item_type[i]
			var item = _items[i]
			
			if _array_item_type == TYPE_STRING:
				var item_text: String = item.text
				if not _valid_keys.has(item_text):
					return item
	return null


func _on_ConfirmButton_pressed():
	var excluded_items: = []
	if enable_validate:
		if _array_item_type == TYPE_STRING:
			var invalid_item = validate_key()
			if not invalid_item == null:
				invalid_item.text = "BROLAB_INVALID_STAT"
				excluded_items.append(invalid_item)
		elif _array_item_type == TYPE_ARRAY:
			for item in _items:
				var invalid_item = item.validate_key()
				if not invalid_item == null:
					invalid_item.text = "BROLAB_INVALID_STAT"
					excluded_items.append(invalid_item)
	
	emit_signal("value_changed", get_array(excluded_items))
