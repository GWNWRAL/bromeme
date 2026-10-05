extends Node

var player_stats = [{}, {}, {}, {}]
var are_player_stats_dirty = [false, false, false, false]


func add_stat(stat_hsh: int, value: int, player_index: int) -> void:
	pass


func remove_stat(stat_hsh: int, value: int, player_index: int) -> void:
	pass


func get_stat(stat_hash: int, player_index: int) -> float:
	return 0.0


func reset() -> void:
	pass
