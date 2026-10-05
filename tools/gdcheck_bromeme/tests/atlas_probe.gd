extends SceneTree

const PARTS := ["body", "collar", "head_down", "head_top_0", "shadow", "tongue", "head_peted"]


func _init() -> void:
	for p in PARTS:
		var r = load("res://atlasres/%s.res" % p)
		if r == null:
			print("%-12s MISSING" % p)
			continue
		var reg = r.get("region")
		print("%-12s region=%s  size=%s" % [p, str(reg), str(reg.size) if reg != null else "-"])
	quit(0)
