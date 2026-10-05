extends "res://entities/units/player/player.gd"

# =============================================================================
# Aitato :: DeepSeek (大肥鱼)
#
# Only this character is affected:
#   * stop moving -> she falls asleep
#       - HP Regeneration +10
#       - body art is swapped for the "deepsleep" sprite
#   * moving again -> she wakes up and the art is restored
#
# The +10 HP Regeneration is a normal character effect (stat_hp_regeneration),
# so it is applied by the vanilla effect system; this extension only handles the
# per-frame sleep/wake state and the art swap.
#
# The starting Scared Sausage is a normal character effect as well
# (custom_key = "starting_item"), which vanilla grants in
# RunData.add_starting_items_and_weapons() - exactly like the Mage's sausage.
#
# The body art ships at 96x96, which is the size it is meant to render at, so no
# scaling is applied anywhere. Vanilla creates appearance sprites with no scaling
# (player.gd) and the selection preview does the same (character_panel_ui.gd), so
# keeping the texture at its intended size is what makes both paths correct
# without any code.
# =============================================================================

const AITATO_CHARACTER_ID := "character_aitato_deepseek"

# Sleeping art. The file is named deepsleep - do not rename it.
const DEEPSLEEP_TEXTURE_PATH := "res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/deepsleep.png"

const SLEEP_DELAY := 0.15


var _aitato_active := false
var _aitato_sleeping := false
var _aitato_still_time := 0.0

var _aitato_art_sprites: Array = []
var _aitato_sleep_sprite: Sprite = null
var _aitato_legs_were_visible := true


# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	var character = RunData.get_player_character(player_index)
	_aitato_active = character != null and character.my_id == AITATO_CHARACTER_ID

	if not _aitato_active:
		return

	_aitato_sleeping = false
	_aitato_still_time = 0.0

	if _legs != null:
		_aitato_legs_were_visible = _legs.visible


# Called after the player spawns and after every item change: (re)place the art.
func apply_items_effects() -> void:
	.apply_items_effects()

	if not _aitato_active:
		return

	_aitato_collect_art_sprites()
	_aitato_apply_visuals()


func _aitato_collect_art_sprites() -> void:
	_aitato_art_sprites = []

	var character = RunData.get_player_character(player_index)
	if character == null or _animation_node == null:
		return

	for appearance in character.item_appearances:
		if appearance == null:
			continue
		var wanted = appearance.get_sprite()
		if wanted == null:
			continue
		for child in _animation_node.get_children():
			if child is Sprite and child.texture == wanted and not _aitato_art_sprites.has(child):
				_aitato_art_sprites.append(child)


# -----------------------------------------------------------------------------
# Per frame
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	._physics_process(delta)

	if not _aitato_active:
		return

	if dead or cleaning_up or _pending_die:
		if _aitato_sleeping:
			_aitato_wake_up()
		return

	var is_still: bool = _current_movement == Vector2.ZERO

	if is_still:
		_aitato_still_time += delta
		if not _aitato_sleeping and _aitato_still_time >= SLEEP_DELAY:
			_aitato_fall_asleep()
	else:
		_aitato_still_time = 0.0
		if _aitato_sleeping:
			_aitato_wake_up()


# -----------------------------------------------------------------------------
# Sleep / wake
# -----------------------------------------------------------------------------

func _aitato_fall_asleep() -> void:
	if _aitato_sleeping:
		return

	_aitato_sleeping = true
	_aitato_apply_visuals()


func _aitato_wake_up() -> void:
	if not _aitato_sleeping:
		return

	_aitato_sleeping = false
	_aitato_apply_visuals()


# Vanilla calls this at the end of every wave; drop the per-wave state.
func on_room_cleanup() -> void:
	.on_room_cleanup()

	if not _aitato_active:
		return

	_aitato_sleeping = false
	_aitato_still_time = 0.0
	_aitato_apply_visuals()


# -----------------------------------------------------------------------------
# Visuals
#
# The character's body art is an ItemAppearanceData that vanilla adds as a child
# of the potato body sprite, so the potato cannot be hidden with `visible = false`
# (that would hide the child art too). Instead the potato itself is made fully
# transparent while the art is shown, which removes the "blank potato" that
# would otherwise show behind the sleeping sprite.
# -----------------------------------------------------------------------------

func _aitato_apply_visuals() -> void:
	if _aitato_sleeping:
		_aitato_apply_sleep_visuals()
	else:
		_aitato_apply_awake_visuals()


func _aitato_apply_awake_visuals() -> void:
	if _aitato_sleep_sprite != null and is_instance_valid(_aitato_sleep_sprite):
		_aitato_sleep_sprite.visible = false

	for sprite in _aitato_art_sprites:
		if is_instance_valid(sprite):
			sprite.visible = true

	# Hide the vanilla potato only when we actually have art to show instead.
	if _animation_node != null and not _aitato_art_sprites.empty():
		_animation_node.self_modulate = Color(1, 1, 1, 0)
	elif _animation_node != null:
		_animation_node.self_modulate = Color(1, 1, 1, 1)

	if _legs != null:
		_legs.visible = _aitato_legs_were_visible


func _aitato_apply_sleep_visuals() -> void:
	for sprite in _aitato_art_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false

	if _animation_node != null:
		_animation_node.self_modulate = Color(1, 1, 1, 1)

	if _legs != null:
		_legs.visible = false

	if _aitato_sleep_sprite == null or not is_instance_valid(_aitato_sleep_sprite):
		_aitato_create_sleep_sprite()

	if _aitato_sleep_sprite != null and is_instance_valid(_aitato_sleep_sprite):
		_aitato_sleep_sprite.visible = true
		if _animation_node != null:
			_animation_node.move_child(_aitato_sleep_sprite, _animation_node.get_child_count() - 1)


func _aitato_create_sleep_sprite() -> void:
	if _animation_node == null:
		return
	if not ResourceLoader.exists(DEEPSLEEP_TEXTURE_PATH):
		return

	var texture = load(DEEPSLEEP_TEXTURE_PATH)
	if texture == null:
		return

	var sleep_sprite := Sprite.new()
	sleep_sprite.name = "AitatoSleepSprite"
	sleep_sprite.texture = SkinManager.get_skin(texture)
	sleep_sprite.centered = _animation_node.centered
	sleep_sprite.visible = false
	_animation_node.add_child(sleep_sprite)
	_aitato_sleep_sprite = sleep_sprite
