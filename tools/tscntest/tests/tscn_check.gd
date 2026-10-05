extends SceneTree
func _init():
	var s = load("res://sub/thing.tscn")
	print("load(.tscn) 类型:", typeof(s), " 是PackedScene:", s is PackedScene)
	if s is PackedScene:
		var inst = s.instance()
		print("instance 成功:", inst != null, " name=", inst.name if inst else "-")
		print("脚本方法/属性读取:", inst.get("marker") if inst else "-")
		print("resource_path:", s.resource_path)
	quit(0)
