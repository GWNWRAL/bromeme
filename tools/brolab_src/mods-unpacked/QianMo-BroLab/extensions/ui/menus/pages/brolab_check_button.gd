extends CheckButton


var _custom_label: Label


func _ready()->void :
	_custom_label = Label.new()
	_custom_label.mouse_filter = MOUSE_FILTER_IGNORE
	_custom_label.set("custom_fonts/font", get("custom_fonts/font"))
	_custom_label.autowrap = true
	_custom_label.text = text
	_custom_label.valign = VALIGN_CENTER
	_custom_label.rect_size.x = rect_size.x * 1.8
	_custom_label.rect_min_size.y = rect_size.y * 0.5
	add_child(_custom_label)
	
	text = ""


func set_wrap_text(p_text: String)->void :
	_custom_label.text = p_text
	
	yield(get_tree(), "idle_frame")
	rect_min_size.y = _custom_label.rect_size.y * 0.5
