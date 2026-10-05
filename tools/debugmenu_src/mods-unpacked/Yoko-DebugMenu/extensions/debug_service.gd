extends "res://singletons/debug_service.gd"

var mod_debug_menu = null

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _input(_event) -> void:
    var viewport: Viewport = get_viewport()
    var focused: Control = viewport.gui_get_focus_owner() if viewport else null
    if focused != null and (focused is LineEdit or focused is TextEdit): return

    var keyboard_pressed = Input.is_physical_key_pressed(KEY_T)

    var triggers_pressed = false
    if Input.is_joy_button_pressed(0, JOY_BUTTON_6) and Input.is_joy_button_pressed(0, JOY_BUTTON_7):
        triggers_pressed = true
    else:
        var left_trigger: float = Input.get_joy_axis(0, JOY_AXIS_6)
        var right_trigger: float = Input.get_joy_axis(0, JOY_AXIS_7)
        triggers_pressed = (left_trigger > 0.5) and (right_trigger > 0.5)

    if (not keyboard_pressed and not triggers_pressed) or is_instance_valid(mod_debug_menu): return

    mod_debug_menu = load("res://mods-unpacked/Yoko-DebugMenu/content/scenes/debug_menu.tscn").instance()
    if get_tree().current_scene is Main: get_tree().current_scene.get_node("UI").add_child(mod_debug_menu)
    else: get_tree().current_scene.add_child(mod_debug_menu)
