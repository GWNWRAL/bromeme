extends Node

const DUMMY_PLAYER_INDEX := 123

signal stat_added(stat_name, value, db_mod, player_index)
signal stat_removed(stat_name, value, db_mod, player_index)
signal stats_updated(player_index)


func get_player_character(player_index: int):
	return null


func get_player_effects(player_index: int) -> Dictionary:
	return {}


func get_player_effect(key: int, player_index: int):
	return null


func get_player_count() -> int:
	return 1


func add_stat(stat_hsh: int, value: int, player_index: int) -> void:
	pass


func remove_stat(stat_hsh: int, value: int, player_index: int) -> void:
	pass
