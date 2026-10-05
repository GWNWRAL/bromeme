extends "res://weapons/weapon.gd"

# =============================================================================
# Aitato :: weapon behaviour
#
# Hooks used by the DeepSeek character:
#   1. `should_shoot()` returns false while her owner is asleep, so she cannot
#      attack while sleeping.
#   2. `init_stats()` re-applies the doubled Critical Damage from her charge
#      buff, because the vanilla code rebuilds `current_stats` from scratch
#      whenever player stats change.
# =============================================================================


func should_shoot() -> bool:
	if _aitato_owner_is_sleeping():
		return false
	return .should_shoot()


func init_stats(at_wave_begin: bool = true) -> void:
	.init_stats(at_wave_begin)

	# `current_stats.crit_damage` was just rebuilt from the weapon resource, so
	# the charge buff has to be written on top of it again.
	var owner_player = _aitato_get_owner()
	if owner_player != null:
		if ("aitato_reapply_crit_damage" in owner_player):
			owner_player.aitato_reapply_crit_damage(self)


func _aitato_get_owner():
	if _parent != null and is_instance_valid(_parent):
		return _parent
	return null


func _aitato_owner_is_sleeping() -> bool:
	var owner_player = _aitato_get_owner()
	if owner_player == null:
		return false
	if not ("_aitato_sleeping" in owner_player):
		return false
	return owner_player._aitato_sleeping
