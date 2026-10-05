extends Resource
class_name PlayerRunData

var items = []
var effects = {}
var weapons = []

func deserialize(data: Dictionary) -> PlayerRunData:
	var r = PlayerRunData.new()
	return r if r != null else self

static func init_effects() -> Dictionary:
	return {}
