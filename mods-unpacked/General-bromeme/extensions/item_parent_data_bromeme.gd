extends "res://items/global/item_parent_data.gd"

# =============================================================================
#  道具图标持久化（退出重进后不丢图）
#
#  问题：本 mod 的贴图是**运行时**用 png 字节解码出来的 ImageTexture，
#        `resource_path` 为空；而原版 ItemParentData.serialize() 根本不存 Texture，
#        读档时靠 my_id 去 ItemService 反查 —— 但**读档发生在本 mod 装完之前**
#        （实测那一刻 ItemService.items 只有 377 件原版道具），
#        所以本 mod 道具 / 4选1 卡道具的图标就丢了。
#        日志实证：卡道具贴图来源解析失败（kind=exclusive tag=item_bromeme_meme_quantum）
#
#  做法（照抄卡皮巴拉 Dbear-Capybara）：把图标的**资源路径**写进存档，读档时 load 回来，
#        完全不依赖内容装载顺序。
#
#  ⚠️ 为什么用扩展而不是"给卡道具挂专用脚本"：
#       2.42.22 用过给已实例化 Resource set_script() 的方案，会重建脚本实例并留下
#       悬空引用 —— 实测引发原生访问违例崩溃（Brotato.exe 0xc0000005）。
#       脚本扩展是**类级**的，不碰实例脚本，没有这个风险。
#
#  性能：my_id -> relative_icon_path 的索引表**只建一次**（静态缓存）。
#       否则每件道具 serialize() 都要重扫 118 个 json，存档一次就是上千次文件读。
# =============================================================================

const BROMEME_ICON_SIZE: int = 96
const BROMEME_MOD_ROOT: String = "res://mods-unpacked/General-bromeme/"
const BROMEME_RES_DIR: String = BROMEME_MOD_ROOT + "resources/"
const BROMEME_CARD_ITEM_ID_PREFIX: String = "item_bromeme_pick_"
const BROMEME_LOGO_PATH: String = BROMEME_MOD_ROOT + "meme/content/ui/bromeme_logo.png"
const BROMEME_LOGO_ALPHA: float = 0.35

# my_id -> [relative_icon_path, json 主干]，进程内只建一次。
# ⚠️ 这个引擎版本的 GDScript 3 **不支持 static var**（只支持 static func），
#    所以缓存挂在 Engine 的 meta 上（跨实例、跨脚本重载都保留）。
const BROMEME_INDEX_META: String = "bromeme_item_icon_index"

var _bromeme_icon_path_memo: String = ""
var _bromeme_icon_is_card: bool = false


func serialize() -> Dictionary:
	var serialized = .serialize()
	# 只给"本 mod 的道具 / 本 mod 生成的卡道具"记录路径，原版道具一律不动
	var info: Array = _bromeme_icon_info()
	if info[1] != "":
		serialized["bromeme_card_icon"] = info[2]      # true = 卡道具（读档要再套一次水印）
		serialized["bromeme_icon_path"] = info[1]
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	if not serialized.has("bromeme_icon_path"):
		return
	var path: String = String(serialized["bromeme_icon_path"])
	if path == "":
		return
	_bromeme_icon_path_memo = path
	_bromeme_icon_is_card = bool(serialized.get("bromeme_card_icon", false))
	var tex = _bromeme_load_icon(path)
	if tex != null:
		icon = _bromeme_apply_card_watermark(tex) if _bromeme_icon_is_card else tex


# -----------------------------------------------------------------------------
#  索引表（只建一次）
# -----------------------------------------------------------------------------

func _bromeme_index() -> Dictionary:
	if Engine.has_meta(BROMEME_INDEX_META):
		return Engine.get_meta(BROMEME_INDEX_META)
	var out: Dictionary = {}
	var idx_file := File.new()
	if idx_file.open(BROMEME_RES_DIR + "_index.json", File.READ) != OK:
		return out
	var idx = parse_json(idx_file.get_as_text())
	idx_file.close()
	if idx == null or typeof(idx) != TYPE_DICTIONARY:
		return out
	var files = idx.get("files")
	if typeof(files) != TYPE_ARRAY:
		return out
	for name in files:
		var stem: String = String(name).replace(".json", "")
		var f := File.new()
		if f.open(BROMEME_RES_DIR + String(name), File.READ) != OK:
			continue
		var d = parse_json(f.get_as_text())
		f.close()
		if d == null or typeof(d) != TYPE_DICTIONARY:
			continue
		var mid: String = String(d.get("my_id", ""))
		if mid == "":
			continue
		out[mid] = [String(d.get("relative_icon_path", "")), stem]
	Engine.set_meta(BROMEME_INDEX_META, out)
	return out


func _bromeme_icon_info() -> Array:
	var my_id: String = String(self.my_id)

	# 卡道具：走 id 解析（来源图 + 水印）
	if my_id.begins_with(BROMEME_CARD_ITEM_ID_PREFIX):
		return [true, _bromeme_guess_card_source_path(my_id), true]

	# 普通本 mod 道具：按 id 在索引里找 relative_icon_path
	var entry = _bromeme_index().get(my_id, null)
	if entry != null and String(entry[0]) != "":
		# 与构建脚本同优先级：resources/edited/<stem>.png 优先
		var edited: String = BROMEME_MOD_ROOT + "resources/edited/" + String(entry[1]) + ".png"
		if _bromeme_file_exists(edited):
			return [true, edited, false]
		return [true, BROMEME_RES_DIR + String(entry[0]), false]

	return [false, "", false]


# 卡道具 id: item_bromeme_pick_[bromeme_pick_]<kind>_<tag> → 来源内容 → 图标路径
func _bromeme_guess_card_source_path(my_id: String) -> String:
	var rest: String = my_id.substr(BROMEME_CARD_ITEM_ID_PREFIX.length())
	var card_prefix: String = "bromeme_pick_"
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return ""
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)

	if kind == "job":
		# 转职卡：用第一条属性的小图标
		var gt: int = tag.find(">")
		var stat_name: String = tag if gt < 0 else tag.substr(0, gt)
		if stat_name == "":
			return ""
		var small = ItemService.get_stat_small_icon(Keys.generate_hash(stat_name)) if ItemService != null else null
		if small != null and small is Resource:
			return String(small.resource_path)
		return ""

	var plus: int = tag.find("+")
	var source_id: String = tag if plus < 0 else tag.substr(0, plus)
	if source_id == "":
		return ""

	# 来源是本 mod 的道具 / 角色：直接查索引（不依赖 ItemService 是否装完）
	var entry = _bromeme_index().get(source_id, null)
	if entry != null and String(entry[0]) != "":
		return BROMEME_RES_DIR + String(entry[0])

	# 来源是别的 mod / 原版：让 ItemService 帮忙（已装好时可用）
	var src = null
	if ItemService != null and ItemService.has_method("get_item_from_id"):
		src = ItemService.get_item_from_id(Keys.generate_hash(source_id))
	if src == null and ItemService != null:
		for ch in ItemService.characters:
			if ch != null and is_instance_valid(ch) and String(ch.my_id) == source_id:
				src = ch
				break
	if src != null and src.icon != null and src.icon is Resource:
		return String(src.icon.resource_path)
	return ""


# -----------------------------------------------------------------------------
#  读图
# -----------------------------------------------------------------------------

func _bromeme_file_exists(path: String) -> bool:
	var f := File.new()
	return f.file_exists(path)


# mod 目录里的 png 走字节解码（没有 .import 缓存，load 拿不到）；其余走 load
func _bromeme_load_icon(path: String):
	if path == "":
		return null
	if not path.begins_with(BROMEME_MOD_ROOT):
		if not ResourceLoader.exists(path):
			return null
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
	if image.get_width() != BROMEME_ICON_SIZE or image.get_height() != BROMEME_ICON_SIZE:
		image.resize(BROMEME_ICON_SIZE, BROMEME_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex


# -----------------------------------------------------------------------------
#  卡道具水印：与 item_service.bromeme_watermark_icon() 完全同款
#  （logo 压到 BROMEME_LOGO_ALPHA，blend_rect 到底部居中）
#  自己实现一份：读档可能早于 ItemService 装修，不能依赖它的方法/缓存
# -----------------------------------------------------------------------------

func _bromeme_apply_card_watermark(tex):
	if tex == null:
		return null
	var logo: Image = _bromeme_logo_image()
	if logo == null:
		return tex
	var base: Image = tex.get_data() if tex.has_method("get_data") else null
	if base == null:
		return tex
	base = base.duplicate()
	base.convert(Image.FORMAT_RGBA8)
	if base.get_width() != BROMEME_ICON_SIZE or base.get_height() != BROMEME_ICON_SIZE:
		base.resize(BROMEME_ICON_SIZE, BROMEME_ICON_SIZE, Image.INTERPOLATE_LANCZOS)

	var logo_img: Image = logo.duplicate()
	logo_img.convert(Image.FORMAT_RGBA8)
	var w: int = BROMEME_ICON_SIZE - 10
	var h: int = max(1, int(round(float(logo_img.get_height()) * float(w) / float(logo_img.get_width()))))
	if h > BROMEME_ICON_SIZE / 2:
		h = BROMEME_ICON_SIZE / 2
		w = max(1, int(round(float(logo_img.get_width()) * float(h) / float(logo_img.get_height()))))
	logo_img.resize(w, h, Image.INTERPOLATE_LANCZOS)

	base.lock()
	base.blend_rect(logo_img, Rect2(0, 0, w, h),
			Vector2((BROMEME_ICON_SIZE - w) / 2, BROMEME_ICON_SIZE - h - 3))
	base.unlock()

	var out := ImageTexture.new()
	out.create_from_image(base, Texture.FLAG_FILTER)
	return out


func _bromeme_logo_image() -> Image:
	var file := File.new()
	if file.open(BROMEME_LOGO_PATH, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	image.lock()
	for y in image.get_height():
		for x in image.get_width():
			var c: Color = image.get_pixel(x, y)
			c.a = c.a * BROMEME_LOGO_ALPHA
			image.set_pixel(x, y, c)
	image.unlock()
	return image
