extends SceneTree

# Reproduces the scaling the extension applies, using the REAL compiled
# textures, and reports the resulting on-screen size.
#
# Mimics vanilla player.gd:
#     _animation_node = $Animation/Sprite
#     var item_sprite = Sprite.new()
#     item_sprite.texture = appearance.get_sprite()
#     _animation_node.add_child(item_sprite)          # - centred, scale 1,1
#
# then applies the extension's derived factor (ART_TARGET_SIZE / art width).

const CHAR := "res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/"
const ART_TARGET_SIZE := 96.0     # must match extensions/player_aitato.gd

func _init():
	var root = Node2D.new()
	get_root().add_child(root)

	# $Animation
	var animation = Node2D.new()
	animation.name = "Animation"
	root.add_child(animation)
	# siblings that must NOT be scaled
	var legs = Sprite.new(); legs.name = "Legs"; animation.add_child(legs)
	var shadow = Sprite.new(); shadow.name = "Shadow"; animation.add_child(shadow)
	# $Animation/Sprite == _animation_node
	var animation_node = Sprite.new()
	animation_node.name = "Sprite"
	animation.add_child(animation_node)

	# --- standing art, exactly as vanilla adds it ---
	var standing = Sprite.new()
	standing.texture = load(CHAR + "deepseek.png")
	animation_node.add_child(standing)

	# --- extension: derive the factor from the art and scale the node ---
	var factor = ART_TARGET_SIZE / float(standing.texture.get_width())
	animation_node.scale = Vector2(factor, factor)

	# --- extension: the sleeping sprite (child; inherits, so no scale of its own)
	var sleep = Sprite.new()
	sleep.texture = load(CHAR + "deepsleep.png")
	sleep.centered = animation_node.centered
	animation_node.add_child(sleep)

	var tex_stand = standing.texture.get_size()
	var tex_sleep = sleep.texture.get_size()

	var out_stand = tex_stand * standing.scale * animation_node.scale
	var out_sleep = tex_sleep * sleep.scale * animation_node.scale

	print("standing texture      : ", tex_stand)
	print("sleeping texture      : ", tex_sleep)
	print("derived factor        : ", factor)
	print("_animation_node.scale : ", animation_node.scale)
	print("")
	print("standing rendered     : ", out_stand)
	print("sleeping rendered     : ", out_sleep, "   <- must equal standing")
	print("legs scale            : ", legs.scale, "  (must stay 1,1)")
	print("shadow scale          : ", shadow.scale, "  (must stay 1,1)")
	print("standing own scale    : ", standing.scale, "  (inherits node scale)")
	print("sleeping own scale    : ", sleep.scale, "  (inherits node scale)")
	print("centered stand/sleep  : ", standing.centered, " / ", sleep.centered)

	var ok = true
	if abs(out_stand.x - out_sleep.x) > 0.01 or abs(out_stand.y - out_sleep.y) > 0.01:
		print("FAIL: standing and sleeping art render at different sizes")
		ok = false
	if abs(out_stand.x - ART_TARGET_SIZE) > 0.01:
		print("FAIL: art does not render at the intended target size")
		ok = false
	if legs.scale != Vector2(1, 1) or shadow.scale != Vector2(1, 1):
		print("FAIL: sibling nodes were scaled")
		ok = false
	if standing.scale != Vector2(1, 1) or sleep.scale != Vector2(1, 1):
		print("FAIL: child sprites set their own scale (double scaling)")
		ok = false
	if standing.centered != sleep.centered:
		print("FAIL: centering differs, the swap would jump")
		ok = false

	print("")
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
