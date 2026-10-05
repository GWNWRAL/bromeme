# -*- coding: utf-8 -*-
"""用完好的基线重做 item_service_bromeme.gd 的改动。

背景：一次 PowerShell Set-Content 改写把「中文注释行 + 紧随代码行」合并了
（43 处），所以丢弃当前文件，回到 zip 里那份 943 行的干净基线，再重新加：

  1) 顶部常量 BROMEME_CARD_SCRIPT_PATH / BROMEME_RES_DIR
  2) bromeme_pick_icon_for_source() + bromeme_raw_icon_for()（按卡 id 出图标）
  3) bromeme_make_pick_item() 里给卡道具挂 card_item.gd 脚本

全程 Python 严格 UTF-8 + LF，不经 PowerShell。
"""
import io, re, shutil, zipfile, os, time

TGT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\extensions\item_service_bromeme.gd"
ZIP = r"D:\DSH\Bromeme\Bromeme.zip"
BAK = r"D:\DSH\_aitato_work\corrupt_item_service_backup"

# 1) 先备份当前（损坏的）文件，再从 zip 取干净基线
os.makedirs(BAK, exist_ok=True)
shutil.copy2(TGT, os.path.join(BAK, "item_service_bromeme.corrupt_%s.gd" % time.strftime("%H%M%S")))

z = zipfile.ZipFile(ZIP)
name = [n for n in z.namelist() if n.endswith("extensions/item_service_bromeme.gd")][0]
src = z.read(name).decode("utf-8")
z.close()
src = src.replace("\r\n", "\n").replace("\r", "\n")
assert "bromeme_stat_label" in src, "基线里没有 bromeme_stat_label，拿错文件了"
assert "BROMEME_CARD_SCRIPT_PATH" not in src
print("基线行数:", src.count("\n") + 1)

# 2) 顶部常量
src = src.replace(
    'const BROMEME_ITEM_PREFIX: String = "item_bromeme_"\n',
    'const BROMEME_ITEM_PREFIX: String = "item_bromeme_"\n'
    'const BROMEME_CARD_SCRIPT_PATH: String = "res://mods-unpacked/General-bromeme/brolab_compat/contents/items/card_item.gd"\n'
    'const BROMEME_RES_DIR: String = "res://mods-unpacked/General-bromeme/resources/"\n',
    1)

# 3) 卡道具挂脚本（在 bromeme_make_pick_item 里 my_id 赋值之后）
old_item = """	item.my_id = _bromeme_available_pick_id(base_id)
	item.my_id_hash = Keys.generate_hash(item.my_id)
	item.name = String(card.name)"""
new_item = """	item.my_id = _bromeme_available_pick_id(base_id)
	item.my_id_hash = Keys.generate_hash(item.my_id)
	# 卡道具专用脚本：把图标路径存进存档、读档时直接 load 回来。
	# 图标是运行时合成的（来源图 + logo 水印），原版 serialize 不存 Texture，
	# 不这么做退出重进后图标就没了 —— 这是照抄卡皮巴拉 Dbear-Capybara 的做法。
	var card_script = load(BROMEME_CARD_SCRIPT_PATH)
	if card_script != null:
		item.set_script(card_script)
	item.name = String(card.name)"""
assert old_item in src, "找不到 make_pick_item 的插入点"
src = src.replace(old_item, new_item, 1)

# 4) 追加"按卡 id 出图标"的公开函数（放在 bromeme_stat_name 之前）
anchor = "func bromeme_stat_name(stat_hash: int) -> String:"
assert anchor in src
addition = '''# 卡道具的 my_id（item_bromeme_pick_…）→ 它该有的水印图标。
# 卡道具的贴图不在存档里（Texture 没法序列化），读档后要靠这个函数重建；
# 调用时机要在内容装载完之后（例如进商店前），否则来源可能查不到。
# 真正可靠的那条路是卡道具自带的 card_item.gd：它把图标路径写进存档。
var _bromeme_pick_icon_cache: Dictionary = {}
var _bromeme_raw_icon_map: Dictionary = {}
var _bromeme_raw_icon_cache: Dictionary = {}


func bromeme_pick_icon_for_source(card_item_id: String) -> Texture:
	if _bromeme_pick_icon_cache.has(card_item_id):
		return _bromeme_pick_icon_cache[card_item_id]

	var item_prefix: String = "item_bromeme_pick_"
	var card_prefix: String = "bromeme_pick_"
	if not card_item_id.begins_with(item_prefix):
		return null
	var rest: String = card_item_id.substr(item_prefix.length())
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return null
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)

	var base: Texture = null
	var source_id: String = ""
	if kind == "job":
		# tag = stat_a>stat_b，用来源属性的小图标
		var gt: int = tag.find(">")
		source_id = tag if gt < 0 else tag.substr(0, gt)
		if source_id != "":
			base = get_stat_small_icon(Keys.generate_hash(source_id))
	else:
		# mix / comboswap 的 tag 是 "a+b"，取第一件
		var plus: int = tag.find("+")
		source_id = tag if plus < 0 else tag.substr(0, plus)
		var src = get_item_from_id(Keys.generate_hash(source_id))
		if src == null:
			for ch in characters:
				if ch != null and is_instance_valid(ch) and String(ch.my_id) == source_id:
					src = ch
					break
		if src != null:
			base = src.icon

	if base == null:
		# 兜底：直接从 resources 的图标表里读来源内容自己的图标（不依赖是否已注册）
		base = bromeme_raw_icon_for(source_id)
	if base == null:
		return null

	var tex: Texture = bromeme_watermark_icon(base)
	_bromeme_pick_icon_cache[card_item_id] = tex
	return tex


# 从 resources/*.json 的图标表里取某个 id 的原始图标（不经过 ItemService）
func bromeme_raw_icon_for(source_id: String) -> Texture:
	if source_id == "":
		return null
	if _bromeme_raw_icon_map.empty():
		var idx_file := File.new()
		if idx_file.open(BROMEME_RES_DIR + "_index.json", File.READ) != OK:
			return null
		var idx = parse_json(idx_file.get_as_text())
		idx_file.close()
		if idx == null or typeof(idx) != TYPE_DICTIONARY:
			return null
		var files = idx.get("files")
		if typeof(files) == TYPE_ARRAY:
			for name in files:
				var f := File.new()
				if f.open(BROMEME_RES_DIR + String(name), File.READ) != OK:
					continue
				var d = parse_json(f.get_as_text())
				f.close()
				if d == null or typeof(d) != TYPE_DICTIONARY:
					continue
				if int(d.get("item_type", 1)) == 0:
					continue
				var mid: String = String(d.get("my_id", ""))
				var rel: String = String(d.get("relative_icon_path", ""))
				if mid != "" and rel != "":
					_bromeme_raw_icon_map[mid] = rel

	var rel2: String = String(_bromeme_raw_icon_map.get(source_id, ""))
	if rel2 == "":
		return null
	var path: String = BROMEME_RES_DIR + rel2
	if _bromeme_raw_icon_cache.has(path):
		return _bromeme_raw_icon_cache[path]

	var file2 := File.new()
	if file2.open(path, File.READ) != OK:
		_bromeme_raw_icon_cache[path] = null
		return null
	var buffer: PoolByteArray = file2.get_buffer(file2.get_len())
	file2.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		_bromeme_raw_icon_cache[path] = null
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != BROMEME_PICK_ICON_SIZE or image.get_height() != BROMEME_PICK_ICON_SIZE:
		image.resize(BROMEME_PICK_ICON_SIZE, BROMEME_PICK_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex2 := ImageTexture.new()
	tex2.create_from_image(image, Texture.FLAG_FILTER)
	_bromeme_raw_icon_cache[path] = tex2
	return tex2


'''
src = src.replace(anchor, addition + anchor, 1)

io.open(TGT, "w", encoding="utf-8", newline="\n").write(src)

# 校验
chk = io.open(TGT, encoding="utf-8").read()
print("写回后行数:", chk.count("\n") + 1)
for k in ["BROMEME_CARD_SCRIPT_PATH", "BROMEME_RES_DIR",
          "func bromeme_pick_icon_for_source", "func bromeme_raw_icon_for",
          "item.set_script(card_script)", "func bromeme_stat_label",
          "func _bromeme_fix_stat_effect_text"]:
    print("  %-38s %s" % (k, k in chk))
print("BOM:", io.open(TGT, "rb").read()[:3] == b"\xef\xbb\xbf")
