extends Reference
class_name TakeDamageArgs
var from_player_index: int = 0
var from = null
func _init(_from_player_index: int = 0, _hitbox = null) -> void:
	from_player_index = _from_player_index
