extends Node

# =============================================================================
# Aitato :: weapon behaviour
#
# While DeepSeek is asleep she cannot attack, so should_shoot() is blocked.
# Every other character is unaffected.
# =============================================================================


func should_shoot() -> bool:
	if _aitato_owner_is_sleeping():
		return false
	return .should_shoot()


func _aitato_owner_is_sleeping() -> bool:
	if _parent == null or not is_instance_valid(_parent):
		return false
	if not ("aitato_is_sleeping" in _parent):
		return false
	return _parent.aitato_is_sleeping()
