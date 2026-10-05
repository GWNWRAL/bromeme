extends "res://singletons/run_data.gd"


func remove_item(item, player_index, by_id = false)->void :
	if not item:
		return
	
	.remove_item(item, player_index, by_id)
