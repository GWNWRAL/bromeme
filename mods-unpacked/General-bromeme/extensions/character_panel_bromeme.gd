extends "res://ui/menus/ingame/character_panel_ui.gd"

# =============================================================================
#  bromeme - 角色信息面板（局内暂停 / 背包里那个角色预览）
#
#  这个面板和 player.tscn 一样，角色本体是 %Character/Sprite 这张原版土豆图，
#  外观贴图挂在它下面。所以只在显示本 mod 的角色时才把土豆换透明、把腿藏起来；
#  面板是复用的，切到别的角色/物品时要还原。
# =============================================================================

const BROMME_POTATO_PATH: String = "res://entities/units/player/potato.png"

var _bromeme_blank: Texture = null


func apply_items_appearance(all_items: Array) -> void:
	_bromeme_show_default_body()
	.apply_items_appearance(all_items)
	if _bromeme_is_our_character(item_data):
		_bromeme_hide_default_body()


func _bromeme_is_our_character(data) -> bool:
	if data == null or not (data is ItemData):
		return false
	for appearance in data.item_appearances:
		if appearance == null:
			continue
		var sprite = appearance.get("sprite")
		if sprite != null and sprite.has_meta("bromeme_art"):
			return true
	return false


func _bromeme_potato():
	var character_node = get_node_or_null("%Character")
	if character_node == null:
		return null
	return character_node.get_node_or_null("Sprite")


func _bromeme_legs():
	var character_node = get_node_or_null("%Character")
	if character_node == null:
		return null
	return character_node.get_node_or_null("Legs")


func _bromeme_show_default_body() -> void:
	var potato = _bromeme_potato()
	if potato != null:
		potato.texture = load(BROMME_POTATO_PATH)
		potato.self_modulate = Color(1, 1, 1, 1)
	var legs = _bromeme_legs()
	if legs != null:
		legs.visible = true


func _bromeme_hide_default_body() -> void:
	var potato = _bromeme_potato()
	if potato != null:
		potato.texture = _bromeme_blank_texture()
		potato.self_modulate = Color(1, 1, 1, 0)
	var legs = _bromeme_legs()
	if legs != null:
		legs.visible = false


func _bromeme_blank_texture() -> Texture:
	if _bromeme_blank != null:
		return _bromeme_blank
	var image := Image.new()
	image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	_bromeme_blank = ImageTexture.new()
	_bromeme_blank.create_from_image(image, 0)
	return _bromeme_blank
