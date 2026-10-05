extends "res://stubs/upgrades_container_stub.gd"

# =============================================================================
#  bromeme - 4 选 1 的「不选」按钮
#
#  原版这个界面只有 4 张升级卡 + 重随按钮；卡皮巴拉的做法是把自己的晶化选择
#  复制一个重随按钮当「拒绝」，这里照抄同一套做法：
#    · level == BROMEME_PICK_LEVEL 时，隐藏重随按钮，在原位置放一个「不选」按钮
#    · 点「不选」= 选一张空升级卡（效果 key 为空 → apply() 直接 return，什么也不做）
#
#  BROMEME_PICK_LEVEL 与 extensions/item_service_bromeme.gd、main.gd 扩展里一致。
# =============================================================================

const BROMEME_PICK_LEVEL: int = -7777
const BROMEME_SKIP_ID: String = "bromeme_skip"

var _bromeme_skip_button: ButtonWithIcon = null
var _bromeme_skip_upgrade: UpgradeData = null


func show_upgrades_for_level(level: int) -> void:
	.show_upgrades_for_level(level)

	if level != BROMEME_PICK_LEVEL:
		if is_instance_valid(_bromeme_skip_button):
			_bromeme_skip_button.visible = false
		return

	if not is_instance_valid(_bromeme_skip_button):
		_bromeme_skip_button = _reroll_button.duplicate()
		_bromeme_skip_button.name = "BromemeSkipButton"
		var button_parent = _reroll_button.get_parent()
		var reroll_index: int = _reroll_button.get_index()
		button_parent.add_child(_bromeme_skip_button)
		button_parent.move_child(_bromeme_skip_button, reroll_index)
		if _bromeme_skip_button.is_connected("pressed", self, "_on_RerollButton_pressed"):
			_bromeme_skip_button.disconnect("pressed", self, "_on_RerollButton_pressed")
		_bromeme_skip_button.connect("pressed", self, "_bromeme_on_skip_pressed")

	_reroll_button.visible = false
	_bromeme_skip_button.visible = true
	_bromeme_skip_button.set_text("不选")


func _bromeme_on_skip_pressed() -> void:
	if _bromeme_skip_upgrade == null:
		_bromeme_skip_upgrade = _bromeme_make_skip_upgrade()
	_on_choose_button_pressed(_bromeme_skip_upgrade)


func _bromeme_make_skip_upgrade() -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.my_id = BROMEME_SKIP_ID
	upgrade.my_id_hash = Keys.generate_hash(BROMEME_SKIP_ID)
	upgrade.name = "不选"
	upgrade.tier = 0
	upgrade.value = 0
	upgrade.upgrade_id = BROMEME_SKIP_ID
	upgrade.upgrade_id_hash = upgrade.my_id_hash

	# key 为空 → key_hash == empty_hash → Effect.apply() 直接返回，什么也不加
	var effect := Effect.new()
	effect.key = ""
	effect.text_key = ""
	effect.value = 0
	upgrade.effects = [effect]
	return upgrade
