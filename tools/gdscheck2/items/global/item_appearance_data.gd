extends Resource

export (Resource) var sprite = null
export (int) var position := 0
export (int) var display_priority := 0
export (float) var depth := 1.0
export (bool) var is_character_appearance := false


func get_sprite() -> Resource:
	return sprite
