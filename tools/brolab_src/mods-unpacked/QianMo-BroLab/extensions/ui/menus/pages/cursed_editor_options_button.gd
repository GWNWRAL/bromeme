extends OptionButton


func _ready()->void :
	add_item("BROLAB_YES", 1)
	add_item("BROLAB_NO", 0)
	
	selected = 0
	emit_signal("item_selected", selected)
