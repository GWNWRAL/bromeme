extends SceneTree

const SCRIPTS := [
	"res://meme/pet_bonk_dog_check.gd",
]


func _init() -> void:
	var failures := 0
	for path in SCRIPTS:
		var s = load(path)
		if s == null:
			printerr("FAILED script: ", path)
			failures += 1
			continue
		print("OK script: ", path)
		# load() 对"解析报错但仍返回脚本"的情况不会返回 null，
		# 这里再真实例化一次，解析失败会当场报错。
		if s.can_instance():
			var inst = s.new()
			if inst == null:
				printerr("FAILED instantiate: ", path)
				failures += 1
			else:
				print("OK instantiate: ", path)
				inst.free()
		else:
			print("    (不能实例化，跳过) ", path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
