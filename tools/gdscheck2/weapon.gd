extends Node2D

var player_index := 0
var current_stats = null
var stats = null
var effects := []
var _parent = null
var _hitbox = null
var _current_cooldown := 0.0


func init_stats(at_wave_begin: bool = true) -> void:
	pass


func should_shoot() -> bool:
	return true
