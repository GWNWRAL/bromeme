extends Resource
export(String) var key := ""
var key_hash: int = 0
export(String) var text_key := ""
export(int) var value := 0
export(String) var custom_key := ""
var custom_key_hash: int = 0
export(Array, Resource) var custom_args
func get_args(player_index: int) -> Array:
	return []
func get_text(player_index: int, colored: bool = true) -> String:
	return ""
