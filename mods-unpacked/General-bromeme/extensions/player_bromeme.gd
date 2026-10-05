extends "res://entities/units/player/player.gd"

# =============================================================================
#  bromeme - 让本 mod 的角色用图标当身体贴图
#
#  游戏里外观贴图是挂在 $Animation/Sprite（原版土豆）下面的子 Sprite，
#  父节点先画、子节点后画，所以只要把土豆贴图换成全透明、再把腿藏起来，
#  整只角色就完全由我们的贴图呈现（做法和 Dbear-Capybara 一致）。
#
#  只对带 bromeme 标记的角色生效，原版角色和其它 mod 的角色不受影响。
# =============================================================================

var _bromeme_blank_texture: Texture = null
var _bromeme_potato_texture: Texture = null
var _bromeme_logged: bool = false

func apply_items_effects() -> void:
	.apply_items_effects()
	_bromeme_hide_default_body()


func _bromeme_hide_default_body() -> void:
	if _animation_node == null:
		return

	var character = RunData.get_player_character(player_index)
	if not _bromeme_is_our_character(character):
		return

	# 贴图换透明（动画不会动 texture，所以一次就够）
	if _animation_node is Sprite:
		if _bromeme_potato_texture == null:
			_bromeme_potato_texture = _animation_node.texture
		_animation_node.texture = _bromeme_get_blank_texture()
		# self_modulate 只影响本节点，不影响挂在下面的外观子节点
		_animation_node.self_modulate = Color(1, 1, 1, 0)

	var legs = _bromeme_get_legs()
	if legs != null:
		legs.visible = false

	if not _bromeme_logged:
		_bromeme_logged = true
		ModLoaderLog.info("已在局内隐藏原版身体: " + str(character.my_id), "bromeme")


func _bromeme_is_our_character(character) -> bool:
	if character == null:
		return false
	if character.has_meta("bromeme_character"):
		return true
	# 兜底：存档里恢复出来的角色对象可能丢 meta，这时看贴图标记
	var appearances = character.get("item_appearances")
	if appearances == null or typeof(appearances) != TYPE_ARRAY:
		return false
	for appearance in appearances:
		if appearance == null:
			continue
		var sprite = appearance.get("sprite")
		if sprite != null and sprite.has_meta("bromeme_art"):
			return true
	return false


func _bromeme_get_legs():
	var parent = _animation_node.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Legs")


func _bromeme_get_blank_texture() -> Texture:
	if _bromeme_blank_texture != null:
		return _bromeme_blank_texture
	var image := Image.new()
	image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	_bromeme_blank_texture = ImageTexture.new()
	_bromeme_blank_texture.create_from_image(image, 0)
	return _bromeme_blank_texture
