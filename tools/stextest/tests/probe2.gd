extends SceneTree
func _init():
	var f = File.new()
	f.open("res://art/test.png", File.READ)
	var buf = f.get_buffer(f.get_len())
	f.close()
	var img = Image.new()
	img.load_png_from_buffer(buf)
	img.convert(Image.FORMAT_RGBA8)

	# A) ImageTexture 存 .tres
	var t1 = ImageTexture.new(); t1.create_from_image(img, Texture.FLAG_FILTER)
	print("A) save(ImageTexture -> .tres): ", ResourceSaver.save("res://art/a.tres", t1))
	var la = load("res://art/a.tres")
	print("   load 回来: ", (la is Texture), " path='", (la.resource_path if la else ""), "'")

	# B) Image 存 .tres
	print("B) save(Image -> .tres): ", ResourceSaver.save("res://art/b.tres", img))
	var lb = load("res://art/b.tres")
	print("   load 回来: ", (lb is Image), " path='", (lb.resource_path if lb else ""), "'")

	# C) Image.save_png 到 user:// 再 load 绝对路径
	var up = "user://t.png"
	print("C) Image.save_png(user://): ", img.save_png(up))
	var abs_path = ProjectSettings.globalize_path(up)
	print("   绝对路径: ", abs_path, "  存在: ", (File.new().file_exists(abs_path)))
	var lc = load(abs_path)
	print("   load(绝对路径): ", (lc is Texture), " 类型=", typeof(lc))

	# D) 不存在的路径 load 行为
	print("D) load(res://art/nonexist.png): ", typeof(load("res://art/nonexist.png")))
	quit(0)
