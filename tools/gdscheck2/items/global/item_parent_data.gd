extends Resource

export (String) var my_id := ""
export (bool) var unlocked_by_default := true
export (bool) var can_be_looted := true
export (Resource) var icon = null
export (String) var name := ""
export (int) var tier := 0
export (int) var value := 1
export (Array, Resource) var effects = []
export (String) var tracking_text := ""
export (bool) var is_lockable := true
export (int) var unlock_codex_descr_after_get_it := 1
export (bool) var is_cursed := false
export (float) var curse_factor := 0.0

var my_id_hash := 0


func get_my_id_hash() -> int:
	return my_id_hash
