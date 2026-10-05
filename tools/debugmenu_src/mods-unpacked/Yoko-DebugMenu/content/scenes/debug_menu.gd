extends "res://ui/menus/debug/debug_menu.gd"

onready var cross_button: Button = $"%cross_button"

var focus_before_created: Control = null

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _on_cross_button_pressed() -> void:
    if is_instance_valid(focus_before_created): focus_before_created.grab_focus()
    queue_free()

func _ready() -> void:
    focus_before_created = get_focus_owner()
    cross_button.grab_focus()

    var enemies: Array = []
    for entity in ItemService.entities:
        if not entity is ItemEnemy: continue

        enemies.append(entity)

    inventory_enemies._elements.set_elements(enemies)

func _on_clickOnItemInventory(element: InventoryElement) -> void:
    if remove_items:
        var new_item: ItemData = element.item.duplicate()
        if cursed_items: new_item = dm_curse_item(element.item, player_index)

        RunData.remove_item(new_item, player_index)

    else:
        var new_item: ItemData = element.item.duplicate()
        if cursed_items: new_item = dm_curse_item(element.item, player_index)

        if item_next_shop: RunData.add_item_next_shop(new_item, player_index)
        else: RunData.add_item(new_item, player_index)

    _update_itemsInventory_count()

func _update_itemsInventory_count() -> void:
    var all_player_items: Array = RunData.get_player_items(player_index)
    var all_player_items_count: Dictionary = {}
    for item in all_player_items:
        if all_player_items_count.has(item.my_id_hash): all_player_items_count[item.my_id_hash] += 1
        else: all_player_items_count[item.my_id_hash] = 1

    for element in inventory_items._elements.get_children():
        element.current_number = 0
        if all_player_items_count.has(element.item.my_id_hash):
            var count: int = all_player_items_count[element.item.my_id_hash]
            element.add_to_number(count, true)
        else:
            element.current_number = 0
            element._number_label.hide()

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
func dm_curse_item(item_data: ItemParentData, player_index: int, turn_randomization_off: bool = false, min_modifier: float = 0.0) -> ItemParentData:
    var dlc_1: DLCData = ProgressData.get_dlc_data("abyssal_terrors")
    if dlc_1 == null: return item_data
    return dlc_1.curse_item(item_data, player_index, turn_randomization_off, min_modifier)
