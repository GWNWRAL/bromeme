extends "res://singletons/player_run_data.gd"


static func init_effects()->Dictionary:
	var all_effects = .init_effects()
	var new_effects: = {
		Keys.generate_hash("brolab_effect_receive_item_at_wave"): [],
		Keys.generate_hash("brolab_effect_receive_stat_at_wave"): [],
		Keys.generate_hash("brolab_effect_midas_hand"): [],
		Keys.generate_hash("brolab_stats_end_of_wave_after_wave"): [],
		Keys.generate_hash("brolab_effect_convert_stats_at_wave"): [],
	}

	all_effects.merge(new_effects)

	return all_effects


# =============================================================================
#  读档时把「卡做成的道具」补回 ItemService.items
#
#  原版 deserialize() 是用存档里的 my_id 去 ItemService.items 里查同 id 的道具
#  （`get_element_safe`），**查不到就静默丢弃**（就是这一段 → items 里少一件）。
#
#  而"4 选 1"面板做出来的卡道具是**运行时** append 进 ItemService.items 的：
#  进程一退出，那个条目就没了；下次启动只有 resources/*.json 的固定内容会重新注册。
#  → 读档时查不到 → 卡道具全部消失（用户报告的 SL / 退出重进丢奖励道具）。
#
#  所以这里在调用父类之前，先把存档里出现的卡道具按 my_id 重建并注册进
#  ItemService.items，父类那段"按 id 查回"就能命中，道具和它的效果都会恢复。
# =============================================================================
func deserialize(data: Dictionary) -> PlayerRunData:
	_bromeme_preregister_cards(data)
	var result: PlayerRunData = .deserialize(data)
	_bromeme_restore_body_appearances()
	return result


# =============================================================================
#  读档后把本 mod 角色的**身体贴图**挂回去
#
#  原版 ItemAppearanceData.serialize() 存的是 `sprite.resource_path`，
#  而本 mod 的身体贴图是运行时从 png 字节解码出来的 ImageTexture（resource_path 为空）
#  → 存档里连 sprite 字段都没有 → 读档后角色是隐形的（用户报告"角色贴图消失"）。
#
#  修法（配合 extensions/item_appearance_bromeme.gd）：
#    外观对象里多存一个 bromeme_sprite_stem（art/char/<stem>.png），
#    读档时按它重新解码贴图、赋给 appearance.sprite。
# =============================================================================
const BROMEME_CHAR_DIR: String = "res://mods-unpacked/General-bromeme/art/char/"

func _bromeme_restore_body_appearances() -> void:
	var restored: int = 0
	for appearance in appearances:
		if appearance == null or not is_instance_valid(appearance):
			continue
		if appearance.get("bromeme_sprite_stem") == null:
			continue          # 扩展没装上（安全兜底）
		var stem: String = String(appearance.get("bromeme_sprite_stem"))
		if stem == "":
			continue
		if appearance.sprite != null:
			continue          # 已经有图（例如皮肤系统提供了）就不动
		var path: String = BROMEME_CHAR_DIR + stem + ".png"
		var tex: Texture = _bromeme_decode_png(path)
		if tex == null:
			ModLoaderLog.info("角色贴图重建失败: %s（外观 %s）" % [path, stem], "bromeme")
			continue
		appearance.sprite = tex
		restored += 1
	if restored > 0:
		ModLoaderLog.info("读档后重建角色身体贴图 %d 张" % restored, "bromeme")


# 运行时解码 mod 里的 png（这些 png 没有 .import，load() 拿不到）
func _bromeme_decode_png(path: String) -> Texture:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex


func _bromeme_preregister_cards(data: Dictionary) -> void:
	if not ItemService.has_method("register_runtime_item"):
		return
	var serialized_items = data.get("items")
	if typeof(serialized_items) != TYPE_ARRAY:
		return

	var restored: int = 0
	var icon_pending: Array = []
	for serialized in serialized_items:
		if typeof(serialized) != TYPE_DICTIONARY:
			continue
		var my_id: String = String(serialized.get("my_id", ""))
		if not my_id.begins_with("item_bromeme_pick_"):
			continue
		if _bromeme_find_item(my_id) != null:
			continue          # 已经注册过（同一局内重复读档）
		var item := UpgradeData.new()
		item.my_id = my_id
		item.my_id_hash = Keys.generate_hash(my_id)
		# upgrade_id 只用于"同一强化是否已拥有"的统计，跟 my_id 保持一致即可
		item.upgrade_id = my_id
		item.upgrade_id_hash = item.my_id_hash
		item.name = String(serialized.get("name", my_id))
		item.tier = int(String(serialized.get("tier", "1")))
		item.value = 60
		# 与生成时一致：图鉴不登记、不进商店池/宝箱，只是"能被查回来"
		item.unlocked_by_default = false
		item.can_be_looted = false
		item.is_lockable = false
		item.max_nb = 0
		item.tracking_text = ""
		var tags = serialized.get("tags")
		item.tags = tags if typeof(tags) == TYPE_ARRAY else []
		# 先注册"壳"（父类马上要按 id 查它），再把存档数据合并进来（恢复名字/全部效果）
		ItemService.register_runtime_item(item)
		if item.has_method("deserialize_and_merge"):
			item.deserialize_and_merge(serialized)
		# 贴图不在存档里（Texture 没法序列化），按卡 id 里的 tag 反查来源、重新做水印图。
		# ⚠️ 读档**发生在我们 mod 装完之前**（日志实测：读档时 ItemService.items 只有 377 件
		# 原版道具，我们的 95 件还没注册完），所以这里常常查不到来源 →
		# 把这类卡记下来，等下一帧内容装载完再补一次贴图。
		item.icon = _bromeme_rebuild_card_icon(my_id)
		if item.icon == null:
			icon_pending.append(my_id)
		restored += 1

	if restored > 0:
		ModLoaderLog.info("读档前补注册卡道具 %d 件（原版按 id 找不到会静默丢弃）" % restored, "bromeme")
	if not icon_pending.empty():
		_bromeme_defer_icon_retry(icon_pending, 0)


# 贴图重建的重试队列：等 mod 内容装载完（下一帧 / 再下一帧）再补。
# 每次重试都从 ItemService.items 实时查找，所以只要内容装好就能成功。
func _bromeme_defer_icon_retry(pending: Array, attempt: int) -> void:
	call_deferred("_bromeme_apply_icon_retry", pending, attempt)


func _bromeme_apply_icon_retry(pending: Array, attempt: int) -> void:
	var still: Array = []
	for my_id in pending:
		var card = _bromeme_find_item(String(my_id))
		if card == null:
			still.append(my_id)
			continue
		if card.icon != null:
			continue          # 已经有图了
		card.icon = _bromeme_rebuild_card_icon(String(my_id))
		if card.icon == null:
			still.append(my_id)
	if still.empty():
		return
	if attempt >= 8:
		ModLoaderLog.info("卡道具贴图重建失败 %d 件（会显示成无图）-> %s" % [
				still.size(), PoolStringArray(still).join(", ")], "bromeme")
		return
	call_deferred("_bromeme_apply_icon_retry", still, attempt + 1)


func _bromeme_find_item(my_id: String):
	for it in ItemService.items:
		if it != null and is_instance_valid(it) and String(it.my_id) == my_id:
			return it
	return null


# 按"来源卡 id"取回水印图标（记忆表里存的就是卡的 my_id）
func _bromeme_icon_from_source(source_card_id: String) -> Texture:
	if source_card_id == "":
		return null
	if not ItemService.has_method("bromeme_icon_for_card_id"):
		return null
	return ItemService.call("bromeme_icon_for_card_id", source_card_id)


# -----------------------------------------------------------------------------
#  兜底图标：不依赖 ItemService 是否装载完
#  （读档发生在我们 mod 装完之前，所以主路径那次反查常常失败）
# -----------------------------------------------------------------------------

const BROMEME_RES_DIR: String = "res://mods-unpacked/General-bromeme/resources/"
const BROMEME_INDEX: String = BROMEME_RES_DIR + "_index.json"
const BROMEME_ICON_SIZE: int = 96

var _bromeme_id_icon_map: Dictionary = {}
var _bromeme_icon_cache: Dictionary = {}


# my_id -> resources 里相对的图标路径（从每个 json 自己读，只建一次表）
func _bromeme_icon_map() -> Dictionary:
	if not _bromeme_id_icon_map.empty():
		return _bromeme_id_icon_map

	var idx_file := File.new()
	if idx_file.open(BROMEME_INDEX, File.READ) != OK:
		return _bromeme_id_icon_map
	var idx_text: String = idx_file.get_as_text()
	idx_file.close()
	var idx = parse_json(idx_text)
	if idx == null or typeof(idx) != TYPE_DICTIONARY:
		return _bromeme_id_icon_map
	var files = idx.get("files")
	if typeof(files) != TYPE_ARRAY:
		return _bromeme_id_icon_map

	for name in files:
		var f := File.new()
		var path: String = BROMEME_RES_DIR + String(name)
		if f.open(path, File.READ) != OK:
			continue
		var text: String = f.get_as_text()
		f.close()
		var d = parse_json(text)
		if d == null or typeof(d) != TYPE_DICTIONARY:
			continue
		if int(d.get("item_type", 1)) == 0:
			continue
		var mid: String = String(d.get("my_id", ""))
		var rel: String = String(d.get("relative_icon_path", ""))
		if mid != "" and rel != "":
			_bromeme_id_icon_map[mid] = rel
	return _bromeme_id_icon_map


# 卡 id → 来源道具 id → resources 内的相对图标路径 → 解码
# （不依赖 ItemService 里那张卡是否已注册，避免读档时序导致的"图标丢失"）
func _bromeme_icon_from_card_id(my_id: String) -> Texture:
	var item_prefix: String = "item_bromeme_pick_"
	var card_prefix: String = "bromeme_pick_"
	if not my_id.begins_with(item_prefix):
		return null
	var rest: String = my_id.substr(item_prefix.length())
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return null
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)
	if kind == "job":
		# 转职卡：tag = stat_a>stat_b，用第一条属性的小图标
		var gt: int = tag.find(">")
		var stat_name: String = tag if gt < 0 else tag.substr(0, gt)
		if stat_name == "":
			return null
		return ItemService.get_stat_small_icon(Keys.generate_hash(stat_name))
	# mix / comboswap / swap 等：tag 是 "a+b"，取第一件
	var plus: int = tag.find("+")
	var source_id: String = tag if plus < 0 else tag.substr(0, plus)
	if source_id == "":
		return null
	return _bromeme_card_own_icon(source_id)


# 卡自己的图标（= 来源道具的图标），直接读 PNG 解码，不经过 mod 的私有 helper
func _bromeme_card_own_icon(source_id: String) -> Texture:
	if source_id == "":
		return null
	var rel: String = String(_bromeme_icon_map().get(source_id, ""))
	if rel == "":
		return null
	var path: String = BROMEME_RES_DIR + rel
	if _bromeme_icon_cache.has(path):
		return _bromeme_icon_cache[path]

	var file := File.new()
	if file.open(path, File.READ) != OK:
		_bromeme_icon_cache[path] = null
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		_bromeme_icon_cache[path] = null
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != BROMEME_ICON_SIZE or image.get_height() != BROMEME_ICON_SIZE:
		image.resize(BROMEME_ICON_SIZE, BROMEME_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	_bromeme_icon_cache[path] = tex
	return tex


# 卡道具的 my_id 形如 item_bromeme_pick_<kind>_<tag>，而 <tag> 就是"来源内容"：#   job                → 两条属性名（stat_a>stat_b）→ 用来源属性的小图标
#   swap / exclusive   → 单件道具 id
#   mix / comboswap    → 两件道具 id（a+b）→ 用第一件的图标
#   character / draw   → 角色或道具 id
#
# ⚠️ 注意 id 里前缀会出现**两次**：卡本身是 "bromeme_pick|job|tag"，
#    做成道具时又加了 "item_bromeme_pick_"，并把 "|" 换成 "_" →
#    item_bromeme_pick_ bromeme_pick_job_tag。所以要先剥两层。
# 原始图标没存进存档（Texture 没法序列化），这里按 tag 反查回来，
# 再套一次水印，和生成时完全一致。
func _bromeme_rebuild_card_icon(my_id: String) -> Texture:
	# 优先用"记忆表"：里面直接记着这张卡的图标来自哪张卡（最准）。
	# 该表由 item_service 的 bromeme_remember_icon_path() 在选卡时写入 user://。
	if ItemService.has_method("bromeme_recall_icon_path"):
		var remembered: String = String(ItemService.call("bromeme_recall_icon_path", my_id))
		if remembered != "":
			var tex_mem = _bromeme_icon_from_source(remembered)
			if tex_mem != null:
				return tex_mem

	# 兜底（读档时序问题时会走到这里）：不再依赖"那张卡是否已注册"，
	# 而是从卡 id 解析出来源道具，直接按 resources 里的相对路径解码 PNG。
	# —— 这一步只看卡自己的 id 与 json 索引，和注册顺序无关。
	var fallback := _bromeme_icon_from_card_id(my_id)
	if fallback != null:
		return fallback

	var item_prefix: String = "item_bromeme_pick_"
	var card_prefix: String = "bromeme_pick_"
	if not my_id.begins_with(item_prefix):
		return null
	var rest: String = my_id.substr(item_prefix.length())
	if rest.begins_with(card_prefix):
		rest = rest.substr(card_prefix.length())
	var cut: int = rest.find("_")
	if cut < 0:
		return null
	var kind: String = rest.substr(0, cut)
	var tag: String = rest.substr(cut + 1)

	var base: Texture = null
	var src_missing: String = ""
	if kind == "job":
		# tag = stat_a>stat_b，用第一条属性的小图标
		var gt: int = tag.find(">")
		var stat_name: String = tag if gt < 0 else tag.substr(0, gt)
		if stat_name != "":
			var sh: int = Keys.generate_hash(stat_name)
			if sh != 0:
				base = ItemService.get_stat_small_icon(sh)
			if base == null:
				src_missing = "属性小图标缺失:" + stat_name
		else:
			src_missing = "tag 里没解析出属性名"
	else:
		# mix / comboswap 的 tag 是 "a+b"，取第一件
		var plus: int = tag.find("+")
		var source_id: String = tag if plus < 0 else tag.substr(0, plus)
		var src = null
		if source_id != "":
			src = _bromeme_find_item(source_id)
			if src == null:
				for ch in ItemService.characters:
					if ch != null and is_instance_valid(ch) and String(ch.my_id) == source_id:
						src = ch
						break
		if src == null and source_id != "":
			src_missing = "找不到来源内容:" + source_id
		elif src == null:
			src_missing = "找不到来源内容:" + source_id
		else:
			base = src.icon
			if base == null:
				src_missing = "来源内容没有图标:" + source_id

	if base == null:
		# 兜底：内容还没装载完时（读档就发生在这个时机），直接按卡 id 在 mod 的
		# resources/_index.json 里找它自己的图标 —— 这条路不依赖 ItemService 是否已装好，
		# 能给 UI 的第一帧渲染一张正确的图（等条目能查到时，重试会再用"来源图标"覆盖它）。
		var own: Texture = _bromeme_card_own_icon(my_id)
		if own != null:
			if ItemService.has_method("bromeme_watermark_icon"):
				return ItemService.call("bromeme_watermark_icon", own)
			return own
		ModLoaderLog.info("卡道具贴图来源解析失败（kind=%s tag=%s 原因=%s）" % [kind, tag, src_missing], "bromeme")
		return null
	if ItemService.has_method("bromeme_watermark_icon"):
		return ItemService.call("bromeme_watermark_icon", base)
	return base
