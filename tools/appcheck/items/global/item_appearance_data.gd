extends Resource
class_name ItemAppearanceData
export(Resource) var sprite = null
export(int) var position = 0
export(int) var display_priority = 0
export(float) var depth = 1.0
export(bool) var is_character_appearance = false
func get_sprite() -> Resource: return sprite
func serialize() -> Dictionary:
	var d = {}
	if sprite != null:
		d.sprite = sprite.resource_path
	return d
func deserialize_and_merge(s: Dictionary) -> void:
	if s.has("sprite"):
		sprite = load(s.sprite)
