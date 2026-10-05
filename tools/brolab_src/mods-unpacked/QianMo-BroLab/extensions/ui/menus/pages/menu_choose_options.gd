extends "res://ui/menus/title_screen/title_screen.gd"


signal menu_brolab_menus_page_switched(from, to)


var menu_brolab_menus
var menu_brolab_index: int
var menu_brolab_manager_index: int
var menu_brolab_tab_button
var menu_brolab_manager_tab_button

onready var brolab_menu_options = $Menus/MenuOptions

func _ready():
	var brolab_option_tab = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/menu_brolab.tscn")
	var brolab_manager_tab = load("res://mods-unpacked/QianMo-BroLab/extensions/ui/menus/pages/menu_brolab_manager.tscn")
	
	menu_brolab_menus = get_node("/root/TitleScreen/Menus")
	menu_brolab_menus.connect("menu_page_switched", self, "_on_menu_brolab_menus_page_switched")
	
	var button_container = brolab_menu_options.get_node_or_null("Buttons/HBoxContainer2")
	var button_controller = brolab_menu_options.get_node_or_null("Buttons")
	
	var last_button_index = button_container.get_child_count() - 2
	var accessibility_button = button_container.get_child(last_button_index)
	menu_brolab_tab_button = accessibility_button.duplicate()
	button_container.add_child_below_node(accessibility_button, menu_brolab_tab_button)
	menu_brolab_tab_button.connect("pressed", button_controller, "_change_tab", [last_button_index])
	menu_brolab_index = last_button_index
	menu_brolab_tab_button.text = "MENU_BROLAB_BUTTON"
	menu_brolab_tab_button.icon = null
	button_controller.buttons_tab_np.push_back(menu_brolab_tab_button.get_path())
	
	var brolab_instance = brolab_option_tab.instance()
	button_controller.tab_container.add_child(brolab_instance)
	brolab_instance.call_deferred("init")
	menu_brolab_tab_button.connect("pressed", self, "refresh_brolab_menu", [brolab_instance.get_node("MenuBroLab")])
	
	last_button_index = button_container.get_child_count() - 2
	accessibility_button = button_container.get_child(last_button_index)
	menu_brolab_manager_tab_button = accessibility_button.duplicate()
	button_container.add_child_below_node(accessibility_button, menu_brolab_manager_tab_button)
	menu_brolab_manager_tab_button.connect("pressed", button_controller, "_change_tab", [last_button_index])
	menu_brolab_manager_index = last_button_index
	menu_brolab_manager_tab_button.text = "BROLAB_TO_MANAGER"
	menu_brolab_manager_tab_button.icon = null
	button_controller.buttons_tab_np.push_back(menu_brolab_manager_tab_button.get_path())
	
	brolab_instance = brolab_manager_tab.instance()
	button_controller.tab_container.add_child(brolab_instance)
	brolab_instance.call_deferred("init")
	menu_brolab_manager_tab_button.connect("pressed", self, "refresh_brolab_manager", [brolab_instance.get_node("MenuBrolabManager")])
	
	connect("menu_brolab_menus_page_switched", self, "_on_menu_brolab_menus_page_switched")


func refresh_brolab_menu(instance) -> void:
	instance.refresh_base_element_container()


func refresh_brolab_manager(instance) -> void:
	instance.refresh()


func _on_menu_brolab_menus_page_switched(from: Control, to: Control) -> void:
	var path: String = to.get_script().resource_path
	if path.ends_with("menu_brolab.gd"):
		menu_brolab_tab_button.pressed = true
		menu_brolab_tab_button.emit_signal("pressed")
	elif path.ends_with("menu_brolab_manager.gd"):
		menu_brolab_manager_tab_button.pressed = true
		menu_brolab_manager_tab_button.emit_signal("pressed")


#extends "res://ui/menus/pages/menu_options.gd"
#
#
#signal brolab_navigation_button_pressed
#signal brolab_back_button_pressed
#
#var _brolab_button: Button
#var _horizontal_container: HBoxContainer
#
#
#func _ready():
#	_horizontal_container = get_node("Buttons/HBoxContainer2")
#
#	var last_button = _horizontal_container.get_children()[-2]
#
#	_brolab_button = last_button.duplicate()
#	_brolab_button.connect("pressed", self, "_on_BrolabButton_pressed")
#
#	var sig_list = _brolab_button.get_signal_connection_list("pressed")
#	print(sig_list)
#
#	_brolab_button.disconnect("pressed", self, "_on_BackButton_pressed")
#	_brolab_button.text = "MENU_BROLAB_BUTTON"
#
#	var option_buttons = $Buttons.get_children()
#	var before_to_last_index = $Buttons.get_child_count() - 2
#	var before_to_last = option_buttons[before_to_last_index]
#
#	$Buttons.add_child_below_node(before_to_last, _brolab_button)
#
#
#func _on_BrolabButton_pressed()->void :
#	emit_signal("brolab_navigation_button_pressed")
