extends VBoxContainer


signal want_to_switch(from, to)
signal back_button_pressed


export (PackedScene) var brolab_editor_scene: PackedScene
export (PackedScene) var brolab_manager_scene: PackedScene
export (PackedScene) var brolab_guide_scene: PackedScene

var _parent_menus = null
var menu_brolab_editor = null
var menu_brolab_manager = null
var menu_brolab_guide = null


func init()->void :
	pass


func set_parent_menus(parent_menus)->void :
	_parent_menus = parent_menus


func _on_EditorButton_pressed()->void :
	if not is_instance_valid(menu_brolab_editor):
		menu_brolab_editor = brolab_editor_scene.instance()
		menu_brolab_editor.hide()
		_parent_menus.add_child(menu_brolab_editor)
		menu_brolab_editor.connect("back_button_pressed", self, "_on_editor_back_button_pressed")
	
	emit_signal("want_to_switch", self, menu_brolab_editor)


func _on_editor_back_button_pressed()->void :
	emit_signal("want_to_switch", menu_brolab_editor, self)


func _on_ManagerButton_pressed()->void :
	if not is_instance_valid(menu_brolab_manager):
		menu_brolab_manager = brolab_manager_scene.instance()
		menu_brolab_manager.hide()
		_parent_menus.add_child(menu_brolab_manager)
		menu_brolab_manager.connect("back_button_pressed", self, "_on_manager_back_button_pressed")
	
	emit_signal("want_to_switch", self, menu_brolab_manager)


func _on_manager_back_button_pressed()->void :
	emit_signal("want_to_switch", menu_brolab_manager, self)


func _on_BackButton_pressed():
	emit_signal("back_button_pressed")


func _on_GuideButton_pressed():
	if not is_instance_valid(menu_brolab_guide):
		menu_brolab_guide = brolab_guide_scene.instance()
		menu_brolab_guide.hide()
		_parent_menus.add_child(menu_brolab_guide)
		menu_brolab_guide.connect("back_button_pressed", self, "_on_guide_back_button_pressed")
	
	emit_signal("want_to_switch", self, menu_brolab_guide)


func _on_guide_back_button_pressed()->void :
	emit_signal("want_to_switch", menu_brolab_guide, self)
