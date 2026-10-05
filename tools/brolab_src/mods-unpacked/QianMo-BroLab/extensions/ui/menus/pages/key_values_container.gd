extends HBoxContainer


signal on_value_changed(value, key, type, instance)


var ARRAY_EDITOR_SCENE: PackedScene
var ENUM_EDITOR_SCENE: PackedScene
var FONT_SMALL_BUTTON: DynamicFont

var BrolabManager
var key: Label
var value_edit: LineEdit
var value_bool: CheckButton
var data_resource: Resource
var is_to_be_destroyed: bool = false

var _children_key_values: Array = []
var _splitters: Array = []
var _weapon_stats_editor_ready: bool = false
var _weapon_stats_editor_enabled: bool = false
var _weapon_stats_controll_button: Button = null
var _duplicated_data_resource: Resource = null
var _raw_data: Dictionary = {}
var _base_resource_path: String
var _array_editor = null
var _changed_child_resource_key_values: Dictionary = {}


func _ready()->void :
	ARRAY_EDITOR_SCENE = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/brolab_array_editor.tscn")
	ENUM_EDITOR_SCENE = load("res://mods-unpacked/QianMo-BroLab/contents/ui/brolab_enum_editor.tscn")
	FONT_SMALL_BUTTON = load("res://resources/fonts/actual/base/font_smallest_text.tres")
	
	BrolabManager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")
	
	key = get_child(0)
	value_edit = get_child(1)
	value_bool = get_child(2)


func init(data: Dictionary)->void :
	_raw_data = data
	
	var enums_dict: Dictionary = BrolabManager.ENUMS
	var enums_names: Array = enums_dict.keys()
	if data.type == TYPE_INT or data.type == TYPE_REAL or data.type == TYPE_STRING or data.type == BrolabManager.TYPE_ENUM:
		if not data.key in enums_names:
			var value: LineEdit = value_edit
			value.show()
			value.name = data.key
			value.text = str(data.value)
			var _error_connect = value.connect("text_changed", self, "_on_value_changed", [data.key, data.type, value])
		else:
			value_edit.queue_free()
			
			var enum_editor = ENUM_EDITOR_SCENE.instance()
			add_child(enum_editor)
			enum_editor.init(enums_dict[data.key], data.value)
			var _error_connect = enum_editor.connect("item_selected", self, "_on_value_changed", [data.key, data.type, null])
		
		key.text = data.key
		key.show()
		
		value_bool.queue_free()
	elif data.type == TYPE_ARRAY:
		if BrolabManager.is_valid_array(data.value):
			_init_array_editor(data.value)
			
			value_edit.queue_free()
			value_bool.queue_free()
			
			key.valign = Label.VALIGN_TOP
			key.text = data.key
			key.show()
		else:
			is_to_be_destroyed = true
			queue_free()
	elif data.type == TYPE_BOOL:
		value_bool.show()
		value_bool.set_wrap_text(data.key)
		
		value_bool.set_pressed_no_signal(data.value)
		
		var _error_connect = value_bool.connect("toggled", self, "_on_value_changed", [data.key, data.type, null])
		
		value_edit.queue_free()
	elif data.type == BrolabManager.TYPE_WEAPON_STATS:
		value_edit.queue_free()
		value_bool.queue_free()
		
		key.text = data.key
		key.show()
		
		var button: = MyMenuButton.new()
		button.text = "BROLAB_SHOW_COMPLEX_VALUE"
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.size_flags_vertical = SIZE_FILL
		button.set("custom_fonts/font", FONT_SMALL_BUTTON)
		button.connect("pressed", self, "_on_weapon_stats_button_pressed")
		
		add_child(button)
		
		data_resource = data.value
		_base_resource_path = data_resource.resource_path
		
		_weapon_stats_controll_button = button


func _init_array_editor(init_value)->void :
	_array_editor = ARRAY_EDITOR_SCENE.instance()
	add_child(_array_editor)
	
	_array_editor.init(init_value)
	
	var _error_connect = _array_editor.connect("value_changed", self, "_on_value_changed", [_raw_data.key, _raw_data.type, null])


func get_key()->String :
	return _raw_data.key


func set_value(new_value)->void :
	var data = _raw_data
	if data.type == TYPE_INT or data.type == TYPE_REAL or data.type == TYPE_STRING:
		value_edit.text = str(new_value)
		value_edit.emit_signal("text_changed", str(new_value))
	elif data.type == TYPE_ARRAY:
		if is_instance_valid(_array_editor):
			_array_editor.set_array(new_value)
	elif data.type == TYPE_BOOL:
		value_bool.pressed = new_value
		value_bool.emit_signal("toggled", new_value)


func get_resource_value():
	return _duplicated_data_resource if not _duplicated_data_resource == null else data_resource


func set_child_resource_key_values(key_values: Dictionary)->void :
	_on_weapon_stats_button_pressed()
	_on_weapon_stats_button_pressed()
	
	var keys: Array = key_values.keys()
	for key_value_editor in _children_key_values:
		var child_key: String = key_value_editor.get_key()
		if child_key in keys:
			key_value_editor.set_value(key_values[child_key])


func _init_resource_editor()->void :
	if not _weapon_stats_editor_ready:
		_weapon_stats_editor_ready = true
		
		var parent: VBoxContainer = get_parent()
		var init_index: int = get_index()
		var last_index: int = init_index
		var datas: Array = BrolabManager.get_editable_datas_from_resource(data_resource)
		for data in datas:
			last_index = get_index()
			var new_key_values: HBoxContainer = parent.add_key_value(data, last_index, [], false)
			
			if new_key_values.is_to_be_destroyed:
				continue
			
			_children_key_values.append(new_key_values)
			
			new_key_values.connect("on_value_changed", self, "_on_child_value_changed")
		
		parent.move_child(self, init_index)
		
		var splitter: ColorRect = ColorRect.new()
		splitter.color = Color(0.08, 1, 0)
		splitter.rect_min_size = Vector2(0, 10)
		splitter.size_flags_horizontal = SIZE_EXPAND_FILL
		parent.add_child(splitter)
		parent.move_child(splitter, last_index + 2)
		
		_splitters.append(splitter)


func _on_weapon_stats_button_pressed()->void :
	_init_resource_editor()
	
	if _weapon_stats_editor_ready:
		_weapon_stats_editor_enabled = not _weapon_stats_editor_enabled
		
		if _weapon_stats_editor_enabled:
			_weapon_stats_controll_button.text = "BROLAB_HIDE_ARRAY"
			for key_value in _children_key_values:
				key_value.show()
			for splitter in _splitters:
				splitter.show()
		else:
			_weapon_stats_controll_button.text = "BROLAB_SHOW_COMPLEX_VALUE"
			for key_value in _children_key_values:
				key_value.hide()
			for splitter in _splitters:
				splitter.hide()


func refresh()->void :
	if _raw_data.type == (BrolabManager.TYPE_WEAPON_STATS):
		if _duplicated_data_resource == null:
			return 
		
		_duplicated_data_resource = data_resource.duplicate()
		
		for key in _changed_child_resource_key_values.keys():
			var value = _changed_child_resource_key_values[key]
			if value is Array:
				value = value.duplicate()
			_duplicated_data_resource.set(key, value)


func _on_child_value_changed(value, key, type, _instance)->void :
	if _duplicated_data_resource == null:
		_duplicated_data_resource = data_resource.duplicate()
	
	var new_value = value
	match type:
		TYPE_INT:
			new_value = int(new_value)
		TYPE_REAL:
			new_value = float(new_value)
		TYPE_ARRAY:
			new_value = value.duplicate()
	_duplicated_data_resource.set(key, new_value)
	_changed_child_resource_key_values[key] = new_value
	
	emit_signal("on_value_changed", [_base_resource_path, _duplicated_data_resource, [key, new_value]], _raw_data.key, _raw_data.type, null)


func set_editable(editable: bool)->void :
	if not editable:
		hide()
	else:
		show()


func _on_value_changed(value, key, type, instance)->void :
	emit_signal("on_value_changed", value, key, type, instance)
