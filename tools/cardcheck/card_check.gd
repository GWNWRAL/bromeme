extends "res://items/upgrades/upgrade_data.gd"

# =============================================================================
#  卡道具（4 选 1 面板做出来的那件）专用脚本
#
#  为什么要单独挂脚本：卡道具的图标是**运行时合成**的（来源图 + mod logo 水印），
#  而原版 ItemParentData.serialize() 只存固定字段、**不存 Texture**。
#  于是退出重进后道具本身能读回来（靠 my_id 注册），图标却没了。
#
#  原版读档还发生在 mod 内容装载**之前**（实测：那一刻 ItemService.items 只有
#  377 件原版道具），所以"读档时按 my_id 反查来源图标"这条路也不可靠。
#
#  卡皮巴拉（Dbear-Capybara）的做法：把图标的**资源路径**存进存档，
#  读档时直接 load 回来 —— 不依赖内容装载顺序。这里照做：
#    · 存下 mod 自己的 png 字节 → 用 Image.load_png_from_buffer 解码
#      （mod 里的 png 多数没有 .import 缓存，直接 load 拿不到）
#    · 已经是资源（带 resource_path）就直接 load
# =============================================================================

const BROMEME_CARD_ITEM_ID_PREFIX: String = "item_bromeme_pick_"
const BROMEME_CARD_ICON_SIZE: int = 96
const BROMEME_LOG: String = "bromeme"

# 每次 serialize 都算一遍太浪费，缓存一次
var _bromeme_saved_icon_path: String = ""


func serialize() -> Dictionary:
	var serialized = .serialize()
	var icon_path: String = _bromeme_icon_path()
	if icon_path != "":
		serialized["bromeme_icon_path"] = icon_path
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	var icon_path: String = String(serialized.get("bromeme_icon_path", ""))
	if icon_path != "":
		_bromeme_saved_icon_path = icon_path
		icon = _bromeme_load_icon(icon_path)


# 当前图标对应的资源路径：优先 resource_path，否则反查该贴图在 mod 里的原始路径。
func _bromeme_icon_path() -> String:
	if _bromeme_saved_icon_path != "":
		var again = _bromeme_load_icon(_bromeme_saved_icon_path)
		if again != null:
			return _bromeme_saved_icon_path
	if icon == null:
		return ""
	var rp: String = ""
	if icon is Resource:
		rp = String(icon.resource_path)
	if rp != "":
		return rp
	return _bromeme_guess_icon_path()


# 反查：按本道具 id 里的 tag，在 mod 的图标表里找来源内容的图标路径。
# （图标是"来源图 + 水印"合成出来的，保存来源图即可，读档后再合成一次）
func _bromeme_guess_icon_path() -> String:
	var my_id: String = String(my_id)
	if not my_id.begins_with(BROMEME_CARD_ITEM_ID_PREFIX):
		return ""
	var rest: String = my_id.substr(BROMEME_CARD_ITEM_ID_PREFIX.length())
	var card_prefix: String = "bromeme_pick_"
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return ""
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)

	var source_id: String = ""
	if kind == "job":
		var gt: int = tag.find(">")
		source_id = tag if gt < 0 else tag.substr(0, gt)
	else:
		var plus: int = tag.find("+")
		source_id = tag if plus < 0 else tag.substr(0, plus)
	if source_id == "":
		return ""

	# 属性（转职卡）：用 ItemService 的小图标资源路径
	if kind == "job":
		var stat = ItemService.get_stat(Keys.generate_hash(source_id))
		if stat != null and stat.small_icon != null and stat.small_icon is Resource:
			return String(stat.small_icon.resource_path)
		return ""

	# 道具 / 角色：从 resources/_index.json 的图标表里查
	var res_dir: String = "res://mods-unpacked/General-bromeme/resources/"
	var idx_file := File.new()
	if idx_file.open(res_dir + "_index.json", File.READ) != OK:
		return ""
	var idx = parse_json(idx_file.get_as_text())
	idx_file.close()
	if idx == null or typeof(idx) != TYPE_DICTIONARY:
		return ""
	var files = idx.get("files")
	if typeof(files) != TYPE_ARRAY:
		return ""
	for name in files:
		var f := File.new()
		if f.open(res_dir + String(name), File.READ) != OK:
			continue
		var d = parse_json(f.get_as_text())
		f.close()
		if d == null or typeof(d) != TYPE_DICTIONARY:
			continue
		if int(d.get("item_type", 1)) == 0:
			continue
		if String(d.get("my_id", "")) == source_id:
			var rel: String = String(d.get("relative_icon_path", ""))
			return res_dir + rel if rel != "" else ""
	return ""


# 按路径取回贴图：mod 内的 png 走字节解码（多数没有 .import），其余走 load
func _bromeme_load_icon(path: String):
	if path == "":
		return null
	if not path.begins_with("res://mods-unpacked/General-bromeme/"):
		return load(path)

	var file := File.new()
	if file.open(path, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != BROMEME_CARD_ICON_SIZE or image.get_height() != BROMEME_CARD_ICON_SIZE:
		image.resize(BROMEME_CARD_ICON_SIZE, BROMEME_CARD_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex
