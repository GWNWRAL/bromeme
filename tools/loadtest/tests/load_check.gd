extends SceneTree
func _init():
	var p = "res://art/char/test.png"
	print("file_exists: ", (File.new().file_exists(p)))
	var t = load(p)
	print("load() 结果类型: ", typeof(t), " 是否 Resource: ", t is Resource, " 是否 Texture: ", t is Texture)
	if t != null:
		print("resource_path: '", str(t.resource_path), "'")
		if t is Texture:
			print("尺寸: ", t.get_width(), "x", t.get_height())
	quit(0)
