extends "res://singletons/text.gd"

# =============================================================================
#  属性说明行的实时数字
#
#  原版属性详情按 INFO_POS_STAT_<属性> / INFO_NEG_STAT_<属性> 查翻译，
#  护甲那种"减少 X% 伤害"就是在这层把数值算进文本里的。
#  meme值我们也这么做：识别到这两个 key 时，按当前 meme值 现算入侵概率：
#
#      chance = 1 - exp(-(max(x,0)/100)^0.9)   （和 main.gd 的
#      bromeme_meme_invasion_chance() 完全一致：9 点 → 20.0%，100 点 → 63.2%）
#
#  文本模板走 mod 的翻译表（BROMEME_INFO_MEME_CHANCE，中英日韩俄）。
# =============================================================================

const MEME_STAT_NAME: String = "stat_meme"
const CHANCE_KEY: String = "BROMEME_INFO_MEME_CHANCE"


func text(key: String, args: Array = [], arg_signs: Array = []) -> String:
	var k: String = String(key)
	if k == "INFO_POS_STAT_MEME" or k == "INFO_NEG_STAT_MEME":
		return _bromeme_meme_info(args)
	return .text(key, args, arg_signs)


func _bromeme_meme_info(args: Array) -> String:
	var value: float = -1.0

	# 1) 优先用调用方传进来的属性数值
	if args != null and args.size() > 0:
		var raw: String = String(args[0])
		if raw.is_valid_integer():
			value = float(raw.to_int())

	# 2) 没传就读玩家当前的 meme值（原始点数）
	if value < 0.0:
		var stat_hash: int = Keys.generate_hash(MEME_STAT_NAME)
		value = RunData.get_player_effect(stat_hash, 0)

	var chance: float = 0.0
	if value > 0.0:
		# 与 main.gd 的 bromeme_meme_invasion_chance() 同一条曲线：
		# y = 1 - exp(-(max(x,0)/100)^0.9)
		chance = 1.0 - exp(-pow(value / 100.0, 0.9))

	var template: String = String(tr(CHANCE_KEY))
	if template.empty() or template == CHANCE_KEY:
		template = "{0}%"
	return template.format({"0": "%.1f" % (chance * 100.0)})
