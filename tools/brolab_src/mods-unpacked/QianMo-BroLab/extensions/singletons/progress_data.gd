extends "res://singletons/progress_data.gd"


var brolab_lock_save: = false


func save_run_state(
	shop_items: = [], 
	reroll_count: = [], 
	paid_reroll_count: = [], 
	initial_free_rerolls: = [], 
	free_rerolls: = [], 
	item_steals: = []
)->void :
	if brolab_lock_save:
		brolab_lock_save = false
		return
	
	saved_run_state = get_run_state(
		shop_items, 
		reroll_count, 
		paid_reroll_count, 
		initial_free_rerolls, 
		free_rerolls, 
		item_steals
	)
	last_saved_run_state = saved_run_state
	save()


#var _qianmo_brolab_manager = null
#
#
#func _ready():
#	_qianmo_brolab_manager = get_node("/root/ModLoader/QianMo-BroLab/BrolabManager")


#func load_game_file(try_fallback: = true) -> void:
#	.load_game_file(try_fallback)
#
#	if _qianmo_brolab_manager == null:
#		return
#
#	_qianmo_brolab_manager.fix_lag_save()
