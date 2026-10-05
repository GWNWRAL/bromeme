extends Node

const empty_hash := 5381

var stat_armor_hash := generate_hash("stat_armor")
var stat_hp_regeneration_hash := generate_hash("stat_hp_regeneration")


func generate_hash(value: String) -> int:
	return value.hash()
