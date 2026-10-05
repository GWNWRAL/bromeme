extends "res://entities/units/player/player.gd"

# =============================================================================
# Aitato :: DeepSeek (澶ц偉楸?
#
# Character mechanic:
#   * Stop moving -> she falls asleep.
#       - gains +10 HP Regeneration (the vanilla `temp_stats_while_not_moving`
#         effect on the character data handles the stat itself)
#       - cannot attack (enforced by extensions/weapon_aitato.gd)
#       - her body art is replaced by the "deepsleep" sprite
#       - a charge bar appears below her and fills up over CHARGE_DURATION
#   * Once the bar is full she gains, for BUFF_DURATION seconds:
#       - doubled Critical Damage
#       - doubled Armor
# =============================================================================

const AITATO_CHARACTER_ID := "character_aitato_deepseek"

const DEEPSLEEP_TEXTURE_PATH := "res://mods-unpacked/Aitato-Aitato/contents/characters/deepseek/deepsleep.png"

const CHARGE_DURATION := 1.0
const BUFF_DURATION := 10.0

# Grace period after the player stops moving before she is considered asleep.
const SLEEP_DELAY := 0.15

const BAR_WIDTH := 44.0
const BAR_HEIGHT := 6.0
const BAR_OFFSET := Vector2(0.0, 38.0)
const BAR_BACK_COLOR := Color(0.05, 0.05, 0.08, 0.8)
const BAR_FILL_COLOR := Color(0.25, 0.65, 1.0, 1.0)
const BAR_FULL_COLOR := Color(0.35, 1.0, 0.85, 1.0)

const CRIT_DAMAGE_META := "aitato_base_crit_damage"


var _aitato_active := false
var _aitato_sleeping := false
var _aitato_charge := 0.0
var _aitato_still_time := 0.0
var _aitato_buff_time := 0.0
var _aitato_buff_armor := 0

var _aitato_charge_bar: Node2D = null
var _aitato_charge_fill: Sprite = null
var _aitato_sleep_sprite: Sprite = null
var _aitato_body_sprites: Array = []
# Whether the vanilla potato legs should be visible for this character (they are
# hidden while she sleeps).
var _aitato_legs_visible := true


# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	var character = RunData.get_player_character(player_index)
	_aitato_active = character != null and character.my_id == AITATO_CHARACTER_ID

	if _aitato_active:
		_aitato_still_time = 0.0
		_aitato_charge = 0.0
		_aitato_buff_time = 0.0
		_aitato_buff_armor = 0
		_aitato_sleeping = false
		# DeepSeek ships full-body art, so the vanilla potato legs are hidden.
		_aitato_legs_visible = false
		# apply_items_effects() runs after init() and will place the art.
		call_deferred("_aitato_refresh_visuals")


# Vanilla calls this at the end of every wave. Reset the per-wave state so the
# next wave starts with a clean charge bar and no carried-over buff.
func on_room_cleanup() -> void:
	.on_room_cleanup()

	if not _aitato_active:
		return

	if _aitato_sleeping:
		_aitato_wake_up()
	if _aitato_buff_time > 0.0:
		_aitato_end_buff()

	_aitato_still_time = 0.0
	_aitato_charge = 0.0
	_aitato_refresh_visuals()


# Vanilla calls this after the player spawns and after every item change. It is
# where the mod's body art is placed and where the sleep state is re-applied.
func apply_items_effects() -> void:
	.apply_items_effects()

	if not _aitato_active:
		return

	_aitato_collect_body_sprites()
	_aitato_refresh_visuals()


func _aitato_collect_body_sprites() -> void:
	_aitato_body_sprites = []

	var character = RunData.get_player_character(player_index)
	if character == null:
		return

	for appearance in character.item_appearances:
		if appearance == null:
			continue
		var wanted = appearance.get_sprite()
		if wanted == null:
			continue
		for child in _animation_node.get_children():
			if child is Sprite and child.texture == wanted:
				if not _aitato_body_sprites.has(child):
					_aitato_body_sprites.append(child)


func _aitato_refresh_visuals() -> void:
	if _aitato_sleeping:
		_aitato_apply_sleep_visuals()
	else:
		_aitato_apply_awake_visuals()


# -----------------------------------------------------------------------------
# Per-frame logic
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	._physics_process(delta)

	if _aitato_active:
		_aitato_update(delta)


func _aitato_update(delta: float) -> void:
	if dead or cleaning_up:
		if _aitato_sleeping:
			_aitato_wake_up()
		return

	# Buff countdown.
	if _aitato_buff_time > 0.0:
		_aitato_buff_time = max(0.0, _aitato_buff_time - delta)
		if _aitato_buff_time <= 0.0:
			_aitato_end_buff()

	# Movement tracking. `_current_movement` is refreshed every physics frame by
	# Unit._physics_process().
	var is_still: bool = _current_movement == Vector2.ZERO

	if is_still:
		_aitato_still_time += delta
		if not _aitato_sleeping and _aitato_still_time >= SLEEP_DELAY:
			_aitato_sleep()
	else:
		_aitato_still_time = 0.0
		if _aitato_sleeping:
			_aitato_wake_up()

	if not _aitato_sleeping:
		return

	# Charge the bar; a full bar grants the buff once per charge cycle.
	if _aitato_charge < 1.0:
		_aitato_charge = min(1.0, _aitato_charge + delta / CHARGE_DURATION)
		_aitato_update_charge_bar()
		if _aitato_charge >= 1.0:
			_aitato_start_buff()


# -----------------------------------------------------------------------------
# Sleep / wake
# -----------------------------------------------------------------------------

func _aitato_sleep() -> void:
	if _aitato_sleeping:
		return

	_aitato_sleeping = true
	_aitato_charge = 0.0
	_aitato_apply_sleep_visuals()
	_aitato_show_charge_bar()


func _aitato_wake_up() -> void:
	if not _aitato_sleeping:
		return

	_aitato_sleeping = false
	_aitato_charge = 0.0
	_aitato_apply_awake_visuals()
	_aitato_hide_charge_bar()


# -----------------------------------------------------------------------------
# Buff
# -----------------------------------------------------------------------------

func _aitato_start_buff() -> void:
	_aitato_buff_time = BUFF_DURATION

	# Double Armor: add the player's current armor on top of itself. TempStats
	# is reset automatically at the end of every wave.
	_aitato_buff_armor = int(Utils.get_stat(Keys.stat_armor_hash, player_index))
	if _aitato_buff_armor > 0:
		TempStats.add_stat(Keys.stat_armor_hash, _aitato_buff_armor, player_index)

	_aitato_set_crit_damage_bonus(true)
	_aitato_popup("AITATO_BUFF_START")


func _aitato_end_buff() -> void:
	_aitato_buff_time = 0.0

	if _aitato_buff_armor > 0:
		TempStats.remove_stat(Keys.stat_armor_hash, _aitato_buff_armor, player_index)
		_aitato_buff_armor = 0

	_aitato_set_crit_damage_bonus(false)


# Weapon critical damage is a plain multiplier copied off the weapon resource
# when a weapon initialises, so it is applied to the live weapon stats and to
# their hitboxes. The original value is remembered on the weapon's metadata so
# it can be restored when the buff ends.
func _aitato_set_crit_damage_bonus(enable: bool) -> void:
	for weapon in current_weapons:
		if not is_instance_valid(weapon):
			continue
		_aitato_apply_crit_damage(weapon, enable)


func _aitato_apply_crit_damage(weapon, enable: bool) -> void:
	if enable:
		var base: float
		if weapon.has_meta(CRIT_DAMAGE_META):
			base = float(weapon.get_meta(CRIT_DAMAGE_META))
		else:
			base = float(weapon.current_stats.crit_damage)
			weapon.set_meta(CRIT_DAMAGE_META, base)
		_aitato_write_crit_damage(weapon, base * 2.0)
	elif weapon.has_meta(CRIT_DAMAGE_META):
		_aitato_write_crit_damage(weapon, float(weapon.get_meta(CRIT_DAMAGE_META)))


func _aitato_write_crit_damage(weapon, value: float) -> void:
	weapon.current_stats.crit_damage = value
	if "_hitbox" in weapon and weapon._hitbox != null:
		weapon._hitbox.crit_damage = value


# Called by the weapon extension right after Weapon.init_stats() rebuilt
# `current_stats`, which happens whenever player stats change (levelling up,
# armour changes, wave start, ...).
func aitato_reapply_crit_damage(weapon) -> void:
	if _aitato_buff_time <= 0.0 or not is_instance_valid(weapon):
		return
	_aitato_apply_crit_damage(weapon, true)


func _aitato_popup(text_key: String) -> void:
	var main = get_tree().current_scene
	if main == null or not ("_floating_text_manager" in main):
		return
	var manager = main._floating_text_manager
	if manager == null or not manager.has_method("display"):
		return
	var text: String = tr(text_key)
	if text == text_key or text == "":
		return
	manager.display(text, global_position + Vector2(0, -60), Color(0.35, 1.0, 0.85, 1.0))


# -----------------------------------------------------------------------------
# Visuals
#
# The character's body art is an ItemAppearanceData, which vanilla adds as a
# child of the potato body sprite - so it already covers the potato and no
# extra hiding is needed. Sleeping simply swaps that art out for the dedicated
# "deepsleep" sprite, which is drawn on top of everything else.
# -----------------------------------------------------------------------------

func _aitato_apply_awake_visuals() -> void:
	if _aitato_sleep_sprite != null and is_instance_valid(_aitato_sleep_sprite):
		_aitato_sleep_sprite.visible = false

	for sprite in _aitato_body_sprites:
		if is_instance_valid(sprite):
			sprite.visible = true

	if _legs != null:
		_legs.visible = _aitato_legs_visible


func _aitato_apply_sleep_visuals() -> void:
	for sprite in _aitato_body_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false

	if _legs != null:
		_legs.visible = false

	if _aitato_sleep_sprite == null or not is_instance_valid(_aitato_sleep_sprite):
		_aitato_create_sleep_sprite()

	# Keep the sleeping art as the last child so it is drawn on top.
	if _aitato_sleep_sprite != null and is_instance_valid(_aitato_sleep_sprite):
		_aitato_sleep_sprite.visible = true
		_animation_node.move_child(_aitato_sleep_sprite, _animation_node.get_child_count() - 1)


func _aitato_create_sleep_sprite() -> void:
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


# -----------------------------------------------------------------------------
# Charge bar
# -----------------------------------------------------------------------------

func _aitato_build_charge_bar() -> void:
	if _aitato_charge_bar != null and is_instance_valid(_aitato_charge_bar):
		return

	# Lives next to the body sprite so it follows the character but does not
	# inherit the sprite's left/right mirroring or idle squash-and-stretch.
	var parent_node: Node = _animation_node.get_parent()
	if parent_node == null:
		parent_node = self

	var root := Node2D.new()
	root.name = "AitatoChargeBar"
	root.position = BAR_OFFSET
	root.visible = false
	parent_node.add_child(root)

	var white := _aitato_create_white_texture()

	var back := Sprite.new()
	back.name = "Back"
	back.centered = true
	back.texture = white
	back.scale = Vector2(BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0)
	back.modulate = BAR_BACK_COLOR
	root.add_child(back)

	var fill := Sprite.new()
	fill.name = "Fill"
	fill.centered = false
	fill.texture = white
	fill.position = Vector2( - BAR_WIDTH / 2.0, - BAR_HEIGHT / 2.0)
	fill.scale = Vector2(0.0, BAR_HEIGHT)
	fill.modulate = BAR_FILL_COLOR
	root.add_child(fill)

	_aitato_charge_bar = root
	_aitato_charge_fill = fill


func _aitato_create_white_texture() -> ImageTexture:
	var image := Image.new()
	image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.lock()
	image.set_pixel(0, 0, Color(1, 1, 1, 1))
	image.unlock()

	var texture := ImageTexture.new()
	texture.create_from_image(image, 0)
	return texture


func _aitato_show_charge_bar() -> void:
	_aitato_build_charge_bar()
	if _aitato_charge_bar != null and is_instance_valid(_aitato_charge_bar):
		_aitato_charge_bar.visible = true
	_aitato_update_charge_bar()


func _aitato_hide_charge_bar() -> void:
	if _aitato_charge_bar != null and is_instance_valid(_aitato_charge_bar):
		_aitato_charge_bar.visible = false


func _aitato_update_charge_bar() -> void:
	if _aitato_charge_fill == null or not is_instance_valid(_aitato_charge_fill):
		return

	var ratio: float = clamp(_aitato_charge, 0.0, 1.0)
	_aitato_charge_fill.scale = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)
	_aitato_charge_fill.modulate = BAR_FULL_COLOR if ratio >= 1.0 else BAR_FILL_COLOR
