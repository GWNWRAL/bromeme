extends "res://stubs/pet_bonk_dog_stub.gd"

# =============================================================================
#  bromeme - 雪豹宠物换皮
#
#  雪豹（item_bromeme_xb_478）用的是原版 Bonk 狗的效果，只是改了数值，
#  所以局内跑出来的是那只戴尖刺项圈的狗。这里把它换成雪豹贴图：
#    · 身体 Sprite 的贴图换成 meme/content/pets/xuebao.png（运行时读 png 字节，
#      mod 里的 png 没有导入缓存，直接 load 拿不到）
#    · 项圈节点下面挂着 head_down / tongue / head_top，隐藏它就把狗头整组收掉
#    · 位置往上挪一点，让豹头大致落在狗原来的整体范围内
#
#  只对「custom_key == bromeme_xuebao_pet」的宠物生效——这个标记写在
#  resources/1762954457.json 里，存读档时 Effect.serialize() 会带上，
#  所以读档回来的雪豹也还是雪豹；原版 Bonk 狗不受影响。
#
#  update_data 里会把拿到的 custom_key 打进日志，方便定位"换了没生效"。
#  换皮逻辑单独放在 bromeme_apply_xuebao_art()，自检会直接调它（不需要场景树）。
# =============================================================================

const ART_PATH: String = "res://mods-unpacked/General-bromeme/meme/content/pets/xuebao.png"
const MARKER: String = "bromeme_xuebao_pet"
const LOG_NAME: String = "bromeme"
# 身体 Sprite 在 SubViewport 里的位置：原版是 (0,-33.778)，豹头大一些所以往上让
const BODY_POSITION: Vector2 = Vector2(0, -62)

var _bromeme_pet_art_done: bool = false


func update_data(effect) -> void:
	.update_data(effect)

	var marker: String = ""
	if effect != null:
		var raw = effect.get("custom_key")
		if raw != null:
			marker = String(raw)

	if marker != MARKER:
		return

	if bromeme_apply_xuebao_art():
		ModLoaderLog.info("雪豹宠物换皮成功", LOG_NAME)
	else:
		ModLoaderLog.error("雪豹宠物换皮失败（贴图读不到或节点找不到）", LOG_NAME)


# 只做换皮，不依赖场景树；成功返回 true
func bromeme_apply_xuebao_art() -> bool:
	if _bromeme_pet_art_done:
		return true

	var offset = bromeme_get_offset_node()
	if offset == null:
		return false

	var body = offset.get_node_or_null("body")
	if body == null:
		return false

	var texture: Texture = _bromeme_load_pet_art()
	if texture == null:
		return false

	body.texture = texture
	body.position = BODY_POSITION

	# 项圈下面挂着 head_down / tongue / head_top，隐藏它就把狗头整组收掉
	var collar = offset.get_node_or_null("collar")
	if collar != null:
		collar.visible = false

	_bromeme_pet_art_done = true
	return true


# 2026-09-29 实测：bonk_dog.tscn 里写的是 SubViewport，但这个定制引擎
# （3.7.dev）实例化之后节点名是 Viewport，两条路径都试一遍。
func bromeme_get_offset_node():
	var viewport = get_node_or_null("Animation/Viewport")
	if viewport == null:
		viewport = get_node_or_null("Animation/SubViewport")
	if viewport == null:
		return null
	return viewport.get_node_or_null("offset")


func _bromeme_load_pet_art() -> Texture:
	var file := File.new()
	if file.open(ART_PATH, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null

	var texture := ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	return texture
