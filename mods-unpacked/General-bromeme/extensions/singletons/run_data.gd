extends "res://singletons/run_data.gd"

# 本局是不是"接着上一局/上一波"来的（SL、重试都算）—— meme 入侵的盐值靠它区分
var bromeme_run_resumed: bool = false


func reset(restart: bool = false) -> void:
	.reset(restart)
	bromeme_run_resumed = restart


func reset_to_start_wave_state() -> void:
	.reset_to_start_wave_state()
	bromeme_run_resumed = true


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	bromeme_run_resumed = true
