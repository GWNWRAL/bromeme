extends Node

# 临时诊断：挂到场景树上，在游戏启动后把 set 名与关键翻译打印到 Godot 日志，
# 用来确认 TOY_SET_NAME / BALL_SET_NAME 在当前语言下能解析。
# 检索关键字: AITATO_TRPROBE

const TAG := "AITATO_TRPROBE"

func _ready() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var locale := TranslationServer.get_locale()
	print(TAG, " locale=", locale)
	for key in ["TOY_SET_NAME", "BALL_SET_NAME", "TOY_SET_XP", "BALL_BOUNCE_DAMAGE"]:
		print(TAG, " tr(", key, ") = '", tr(key), "'")

	# set 名本身经过 tr(set.name) 渲染
	for set_data in ItemService.sets:
		if set_data == null:
			continue
		if str(set_data.my_id) == "set_toy" or str(set_data.my_id) == "set_ball":
			print(TAG, " set ", set_data.my_id, " name='", set_data.name,
				"' -> tr() = '", tr(set_data.name), "'")
	print(TAG, " done")
