extends Node2D
var current_target = null
var current_stats = null
var max_stats = null
var stats = null
var dead = false
var enemy_id = ""
var _can_move = true
var _move_locked = false
var _current_movement = Vector2.ZERO
func init(zone_min_pos = null, zone_max_pos = null, players_ref = [], entity_spawner_ref = null): pass
func register_attack_behavior(x): pass
func _projectile_damage(): return 1
func respawn(): pass
func _physics_process(delta): pass
