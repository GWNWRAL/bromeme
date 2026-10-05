extends Control

# =============================================================================
#  bromeme - 波次结束的「本 mod 物品 4 选 1」面板
#
#  做法照 Fantasy / Hextech：自己一套模态面板，不挤原版的升级面板
#  （原版那个面板卡皮巴拉等一堆 mod 都在用，会互相顶掉）。
#  卡直接复用原版升级卡场景（res://ui/menus/upgrades/upgrade_ui.tscn），
#  所以长相和原版一致：图标 + 名字 + 效果描述。
#  顶部是 Bromeme 的 logo（ai 画的，运行时读 png 字节），
#  下面两个按钮：重置（R）/ 取消。
#  选完 emit picked(卡) ；取消 emit picked(null)，外层 yield 这个信号。
# =============================================================================

signal picked(upgrade_data)

const CARD_SCENE_PATH: String = "res://ui/menus/upgrades/upgrade_ui.tscn"
const GOLD_ICON_SCENE_PATH: String = "res://ui/menus/run/gold_icon.tscn"
const LOGO_PATH: String = "res://mods-unpacked/General-bromeme/meme/content/ui/bromeme_logo.png"
const CARD_COUNT: int = 4
const CANCEL_TEXT: String = "取消"

# 刷新价格：(5 + 10 * 波次) * (1 + 波次 * 0.1)，每刷一次 ×1.25（选完/取消后重置）
# 最终再乘 REROLL_PRICE_FACTOR（0.25 = 在 2.42.14 的 0.5 基础上"再次减半"，
# 即相对最早版本共减到 1/4）
const REROLL_FLAT: float = 5.0
const REROLL_PER_WAVE: float = 10.0
const REROLL_WAVE_SCALE: float = 0.1
const REROLL_ESCALATION: float = 1.25
const REROLL_PRICE_FACTOR: float = 0.25

var player_index: int = 0

var _done: bool = false
var _row: HBoxContainer = null
var _reroll_button: Button = null
var _cancel_button: Button = null
var _rerolls: int = 0


func setup(cards: Array, p_player_index: int) -> void:
	player_index = p_player_index
	_build()
	_refresh_cards(cards)


func _build() -> void:
	# 铺满屏幕 + 吃鼠标：挡住底下的战斗 UI（切场景前那一瞬还在）
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	pause_mode = Node.PAUSE_MODE_PROCESS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_constant_override("separation", 14)
	add_child(box)

	var logo := _make_logo()
	if logo != null:
		box.add_child(logo)

	_row = HBoxContainer.new()
	_row.add_constant_override("separation", 14)
	_row.alignment = BoxContainer.ALIGN_CENTER
	box.add_child(_row)

	var buttons := HBoxContainer.new()
	buttons.add_constant_override("separation", 24)
	buttons.alignment = BoxContainer.ALIGN_CENTER
	box.add_child(buttons)

	var reroll_row := HBoxContainer.new()
	reroll_row.add_constant_override("separation", 6)
	reroll_row.alignment = BoxContainer.ALIGN_CENTER
	buttons.add_child(reroll_row)

	# 金币图标：直接复用原版那个（GoldIcon 场景）
	var gold_scene = load(GOLD_ICON_SCENE_PATH)
	if gold_scene != null:
		var gold_icon = gold_scene.instance()
		gold_icon.rect_min_size = Vector2(28, 28)
		gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reroll_row.add_child(gold_icon)

	var reroll := Button.new()
	reroll.rect_min_size = Vector2(180, 46)
	reroll.connect("pressed", self, "_on_reroll_pressed")
	reroll_row.add_child(reroll)
	_bromeme_style_button(reroll)
	_reroll_button = reroll

	var cancel := Button.new()
	cancel.text = tr(CANCEL_TEXT)
	cancel.rect_min_size = Vector2(180, 46)
	cancel.connect("pressed", self, "_on_cancel_pressed")
	buttons.add_child(cancel)
	_bromeme_style_button(cancel)
	_cancel_button = cancel

	_bromeme_update_reroll_button()


# 刷新价格：(5 + 10*波次) * (1 + 波次*0.1)，每刷一次 ×1.25（选完/取消后重置），最后 ×0.5
func _bromeme_reroll_price() -> int:
	var wave: float = float(RunData.current_wave)
	var base: float = (REROLL_FLAT + REROLL_PER_WAVE * wave) * (1.0 + wave * REROLL_WAVE_SCALE)
	var price: int = int(round(base * pow(REROLL_ESCALATION, float(_rerolls)) * REROLL_PRICE_FACTOR))
	if price < 1:
		price = 1
	return price


func _bromeme_update_reroll_button() -> void:
	if _reroll_button == null:
		return
	var price: int = _bromeme_reroll_price()
	_reroll_button.text = "%d (R)" % price
	var gold: int = RunData.get_player_gold(player_index)
	_reroll_button.disabled = gold < price
	_reroll_button.hint_tooltip = ""


# 字体：这个游戏默认主题里没有 Button 字体，直接拿游戏自己的中文字体建一个
const FONT_PATH: String = "res://resources/fonts/raw/NotoSansSC-Medium.otf"
const THEME_PATH: String = "res://resources/themes/base_theme.tres"
const FONT_SIZE: int = 22

var _bromeme_font_cache: Font = null


func _bromeme_font() -> Font:
	if _bromeme_font_cache != null:
		return _bromeme_font_cache

	var font_data = load(FONT_PATH)
	if font_data is DynamicFontData:
		var font := DynamicFont.new()
		font.font_data = font_data
		font.size = FONT_SIZE
		font.use_filter = true
		_bromeme_font_cache = font
		return _bromeme_font_cache

	# 退路：从上层节点扒一个字体
	var node = get_parent()
	var depth: int = 0
	while node != null and depth < 8:
		if node is Control:
			var f = node.get_font("font")
			if f != null:
				_bromeme_font_cache = f
				return _bromeme_font_cache
		node = node.get_parent()
		depth += 1
	return null


func _bromeme_style_button(button: Button) -> void:
	var theme_res = load(THEME_PATH)
	if theme_res != null:
		button.theme = theme_res
	var font := _bromeme_font()
	if font != null:
		button.add_font_override("font", font)
	button.add_constant_override("font_size", FONT_SIZE)
	button.add_color_override("font_color", Color(1, 1, 1))
	button.add_color_override("font_color_disabled", Color(0.55, 0.55, 0.55))
	button.focus_mode = Control.FOCUS_ALL


# 手柄/键盘的焦点邻居：4 张卡左右串起来，往下是重置/取消
func _bromeme_setup_focus() -> void:
	if _row == null:
		return
	var card_buttons: Array = []
	for card in _row.get_children():
		var btn = card.get("button")
		if btn != null:
			btn.focus_mode = Control.FOCUS_ALL
			card_buttons.append(btn)

	for i in card_buttons.size():
		var btn = card_buttons[i]
		if i > 0:
			btn.focus_neighbour_left = btn.get_path_to(card_buttons[i - 1])
		if i < card_buttons.size() - 1:
			btn.focus_neighbour_right = btn.get_path_to(card_buttons[i + 1])
		if _reroll_button != null:
			btn.focus_neighbour_bottom = btn.get_path_to(_reroll_button)
		if _cancel_button != null:
			btn.focus_neighbour_top = btn.get_path_to(_cancel_button)

	if _reroll_button != null and card_buttons.size() > 0:
		_reroll_button.focus_neighbour_top = _reroll_button.get_path_to(card_buttons[0])
		_reroll_button.focus_neighbour_bottom = _reroll_button.get_path_to(card_buttons[0])
	if _reroll_button != null and _cancel_button != null:
		_reroll_button.focus_neighbour_right = _reroll_button.get_path_to(_cancel_button)
		_cancel_button.focus_neighbour_left = _cancel_button.get_path_to(_reroll_button)
	if _cancel_button != null and card_buttons.size() > 0:
		_cancel_button.focus_neighbour_top = _cancel_button.get_path_to(card_buttons[card_buttons.size() - 1])
		_cancel_button.focus_neighbour_bottom = _cancel_button.get_path_to(card_buttons[card_buttons.size() - 1])


func _make_logo() -> TextureRect:
	var file := File.new()
	if file.open(LOGO_PATH, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null

	var texture := ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand = true
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.rect_min_size = Vector2(460, 116)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _refresh_cards(cards: Array) -> void:
	if _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

	var card_scene = load(CARD_SCENE_PATH)
	if card_scene == null:
		return

	for i in min(cards.size(), CARD_COUNT):
		var card = card_scene.instance()
		card.connect("choose_button_pressed", self, "_on_card_chosen")
		# 先进树再 set_upgrade：卡里的描述面板是 onready 变量，进树前是 null
		_row.add_child(card)
		card.set_upgrade(cards[i], player_index)

	_bromeme_setup_focus()

	if _row.get_child_count() > 0:
		var first = _row.get_child(0)
		if first != null and first.get("button") != null:
			first.button.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.scancode == KEY_R:
			_on_reroll_pressed()
			get_tree().set_input_as_handled()


func _on_reroll_pressed() -> void:
	if _done:
		return

	var price: int = _bromeme_reroll_price()
	if RunData.get_player_gold(player_index) < price:
		return

	var cards = ItemService.call("bromeme_build_pick_cards", player_index)
	if cards == null or cards.empty():
		return

	RunData.remove_gold(price, player_index)
	_rerolls += 1
	_refresh_cards(cards)
	_bromeme_update_reroll_button()
	ModLoaderLog.info("4 选 1 刷新：花费 %d 金（第 %d 次）" % [price, _rerolls], "bromeme")


func _on_card_chosen(upgrade_data) -> void:
	if _done:
		return
	_done = true
	emit_signal("picked", upgrade_data)


func _on_cancel_pressed() -> void:
	if _done:
		return
	_done = true
	emit_signal("picked", null)
