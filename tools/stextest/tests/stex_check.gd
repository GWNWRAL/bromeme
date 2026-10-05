extends SceneTree
func _init():
	# 1) 从 png 字节造纹理
	var f = File.new()
	f.open("res://art/test.png", File.READ)
	var buf = f.get_buffer(f.get_len())
	f.close()
	var img = Image.new()
	img.load_png_from_buffer(buf)
	img.convert(Image.FORMAT_RGBA8)
	var tex = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	print("源纹理: ", tex.get_width(), "x", tex.get_height(), " resource_path='", tex.resource_path, "'")

	# 2) 存成 .stex
	var err = ResourceSaver.save("res://art/test.stex", tex)
	print("ResourceSaver.save 返回: ", err)

	# 3) 再 load 回来
	var t2 = load("res://art/test.stex")
	print("load(.stex) 类型: ", typeof(t2), " 是Texture: ", t2 is Texture)
	if t2 != null:
		print("  resource_path='", t2.resource_path, "'  尺寸=", t2.get_width(), "x", t2.get_height())
	quit(0)
