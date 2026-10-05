extends SceneTree

# 这是**当前这个文件自身**的复制品：stub_pet.gd 里没有实现，所以这里直接
# 用源码 + stub 基类跑一次实例化，看 _ready/_physics_process 会不会炸。
func _init():
	var scene = load("res://orb_cang.tscn")
	print("场景载入:", scene != null, " 是PackedScene:", scene is PackedScene)
	if scene == null:
		quit(1)
		return
	var inst = scene.instance()
	print("实例化:", inst != null)
	if inst == null:
		quit(1)
		return
	print("根节点类型:", inst.get_class())
	root.add_child(inst)
	print("add_child 完成")
	# 跑几帧
	for i in 5:
		inst._physics_process(0.016)
		print("  第", i + 1, "帧 physics 完成")
	print("全部完成")
	quit(0)
