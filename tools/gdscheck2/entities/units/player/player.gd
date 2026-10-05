extends RigidBody2D

var player_index := 0
var dead := false
var cleaning_up := false
var current_weapons := []
var current_stats = null
var max_stats = null
var stats = null
var _current_movement := Vector2.ZERO
var _legs = null
var _animation_node = null
var _hitbox = null
var _parent = null


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
	pass


func _physics_process(delta: float) -> void:
	pass


func apply_items_effects() -> void:
	pass


func update_animation(movement: Vector2) -> void:
	pass


func check_not_moving_stats(movement: Vector2) -> void:
	pass


func on_room_cleanup() -> void:
	pass
