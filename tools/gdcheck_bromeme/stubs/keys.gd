extends Node
var hash_to_string := {}
var empty_hash := 0
func generate_hash(s: String) -> int:
	return int(hash(s))
