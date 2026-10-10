extends Node

# =============================================================================
#  bromeme - 直接把内容注册进游戏，不再写入 brolab 目录
#
#  旧实现把 resources/ 下的 107 个 json + 109 张图标 **拷贝** 到
#  user://<steamid>/brolab/ ，由 BroLab 读进来。问题是：
#    * 删掉 mod 之后 brolab 里全是孤儿文件（残留）；
#    * BroLab 用 unix 时间戳当文件名 + 手打名字 + randi()%512 当 id，
#      和其他用 BroLab 做的内容极易撞车。
#
#  现在改成：这个 mod 自己读 resources/*.json，自己造 CharacterData /
#  ItemData，直接 append 到 ItemService。brolab 目录完全不碰。
#  my_id 沿用原来的值（全局唯一），所以老存档依然有效。
# =============================================================================

const MOD_NAME: String = "bromeme"
const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"

const RES_DIR: String = MOD_DIR + "resources/"
const RES_ICON_DIR: String = RES_DIR + "icons/"
const INDEX_FILE: String = RES_DIR + "_index.json"
const ART_CHAR_DIR: String = MOD_DIR + "art/char/"
const ART_ITEM_DIR: String = MOD_DIR + "art/item/"
const ART_BODY_DIR: String = MOD_DIR + "art/body/"

const COMPAT_DIR: String = MOD_DIR + "brolab_compat/"
const COMPAT_EFFECTS_DIR: String = COMPAT_DIR + "contents/effects/"
const PLAYER_EXTENSION: String = MOD_DIR + "extensions/player_bromeme.gd"
# 炮塔（character_bromeme_pt_431）的"按下移动键"机制：护甲翻倍 / 无法回复生命 / 0.25s 无敌
const PLAYER_TURRET_EXTENSION: String = MOD_DIR + "extensions/player_turret.gd"
const PANEL_EXTENSION: String = MOD_DIR + "extensions/character_panel_bromeme.gd"
const RUN_DATA_EXTENSION: String = COMPAT_DIR + "extensions/singletons/player_run_data.gd"
# 真正的 RunData 单例脚本（autoload 场景 res://singletons/run_data.tscn 用的就是它）；
# meme 盐值判断"接着打 / 全新一局"必须装在这个上面，装到 player_run_data.gd 上不生效
const RUN_DATA_SINGLETON_EXTENSION: String = MOD_DIR + "extensions/singletons/run_data.gd"
const MAIN_EXTENSION: String = COMPAT_DIR + "extensions/main.gd"
# 雪豹宠物换皮：只对带 bromeme_xuebao_pet 标记的 Bonk 狗生效
const PET_BONK_DOG_EXTENSION: String = MOD_DIR + "extensions/pet_bonk_dog.gd"
const PET_BASE_SCENE_PATH: String = "res://entities/units/pet/bonk_dog/bonk_dog.tscn"
# 波次结束的「本 mod 物品 4 选 1」：出卡函数挂在 ItemService 上
const ITEM_SERVICE_EXTENSION: String = MOD_DIR + "extensions/item_service_bromeme.gd"
const PICK_UI_SCRIPT_PATH: String = MOD_DIR + "extensions/ui/bromeme_pick_ui.gd"
const PICK_LOGO_PATH: String = MOD_DIR + "meme/content/ui/bromeme_logo.png"
# meme核心：商店购买钩子
const SHOP_EXTENSION: String = MOD_DIR + "extensions/base_shop_bromeme.gd"
# 外套外观扩展：存"贴图来源名"，读档后由 player_run_data 扩展把贴图挂回去
const APPEARANCE_EXTENSION: String = MOD_DIR + "extensions/item_appearance_bromeme.gd"

# BroLab 自己的效果资源 -> 本 mod 内置的副本
const BROLAB_RES_PREFIX: String = "res://mods-unpacked/QianMo-BroLab/"
const COMPAT_RES_PREFIX: String = COMPAT_DIR

# 让本 mod 的物品/角色在肉鸽里正确的贴图尺寸（原版也是 96）
const ICON_SIZE: int = 96

# 启动时清理 brolab 里属于本 mod 的旧文件（只删能确认是自己那份的，见 _clean_brolab_leftovers）
const BROLAB_CLEANUP_ENABLED: bool = true

# 与 BroLab 完全一致的默认资源
const DEFAULT_CHARACTER_ICON_PATH: String = "res://items/characters/well_rounded/well_rounded_icon.png"
const DEFAULT_ITEM_ICON_PATH: String = "res://items/all/acid/acid_icon.png"
const DEFAULT_STARTING_WEAPON_PATHS: Array = [
	"res://weapons/melee/cactus_mace/1/cactus_mace_data.tres",
	"res://weapons/melee/chopper/1/chopper_data.tres",
	"res://weapons/melee/claw/1/claw_data.tres",
	"res://weapons/melee/dagger/1/dagger_data.tres",
	"res://weapons/melee/ghost_axe/1/ghost_axe_data.tres",
	"res://weapons/melee/hand/1/hand_data.tres",
	"res://weapons/melee/pruner/1/pruner_data.tres",
	"res://weapons/melee/screwdriver/1/screwdriver_data.tres",
	"res://weapons/melee/wrench/1/wrench_data.tres",
	"res://weapons/ranged/crossbow/1/crossbow_data.tres",
	"res://weapons/ranged/double_barrel_shotgun/1/double_barrel_shotgun_data.tres",
	"res://weapons/ranged/shredder/1/shredder_data.tres",
	"res://weapons/ranged/slingshot/1/slingshot_data.tres",
	"res://weapons/ranged/taser/1/taser_data.tres",
	"res://weapons/ranged/wand/1/wand_data.tres",
]

const EFFECT_SCRIPTS: Array = [
	"convert_stats_at_wave.gd",
	"effect_midas_hand.gd",
	"receive_items_at_wave.gd",
	"receive_stat_at_wave.gd",
	"stats_end_of_wave_after_wave.gd",
]

var _default_character_icon: Texture = null
var _default_item_icon: Texture = null
var _default_starting_weapons: Array = []

var _texture_cache: Dictionary = {}
var _installed: bool = false

# 名字 key -> 显示名。
#
# 原版 Effect.get_args() 是这么拿"被引用的物品名"的：
#     return [str(value), tr(key.to_upper())]
# 也就是说只要某个效果的 key 指向一个物品 id（例如把渔夫的
# effect_guaranteed_shop_item 的 key 改成 item_bromeme_yan_262），
# 这个 id 的**全大写形式必须是一个已注册的翻译键**，否则描述里就会
# 直接显示成 key —— 也就是「商店通常销售一件ITEM_BROLAB_YAN_262」。
#
# 原版物品自带 ITEM_XXX 的翻译，所以原版内容引用原版物品没问题；
# 本 mod 的物品 id 是 BroLab 生成的，没人给它注册过，于是漏出 key。
# 这里按同样的约定补上：<my_id>.to_upper() -> 显示名。
var _name_keys: Dictionary = {}

# Godot 3 的 TranslationServer 只查"locale 与当前设置完全相同"的翻译对象，
# 所以每个可能用到的语言各注册一份（名字本身是中文，和现在的显示一致）。
const NAME_LOCALES: Array = [
	"en", "en_US", "zh", "zh_CN", "zh_Hans_CN", "zh_TW", "zh_Hant_TW",
	"ja", "ko", "ko_KR", "fr", "fr_FR", "de", "de_DE", "es", "pt", "it", "pl", "ru", "tr",
]


func _init() -> void:
	# 角色身体贴图 + 隐藏原版土豆/腿（局内 + 角色信息面板）
	ModLoaderMod.install_script_extension(PLAYER_EXTENSION)
	ModLoaderMod.install_script_extension(PANEL_EXTENSION)
	# 炮塔：按下移动键 → 护甲翻倍 / 无法回复生命 / 0.25s 无敌（只对带标记的角色生效）
	ModLoaderMod.install_script_extension(PLAYER_TURRET_EXTENSION)
	# BroLab 自定义效果在肉鸽里的运行逻辑（天元鼎 / 丁真 需要）
	ModLoaderMod.install_script_extension(RUN_DATA_EXTENSION)
	# meme 入侵盐值：判断这一局是"接着打（SL/重试）"还是"全新一局"
	ModLoaderMod.install_script_extension(RUN_DATA_SINGLETON_EXTENSION)
	ModLoaderMod.install_script_extension(MAIN_EXTENSION)
	# 雪豹宠物：把 Bonk 狗的身体贴图换成雪豹图（其他 Bonk 狗不受影响）
	ModLoaderMod.install_script_extension(PET_BONK_DOG_EXTENSION)
	# 波次结束的「本 mod 物品 4 选 1」
	ModLoaderMod.install_script_extension(ITEM_SERVICE_EXTENSION)
	# meme核心：每买一件东西 meme值 +1（商店购买钩子）
	ModLoaderMod.install_script_extension(SHOP_EXTENSION)
	# 属性说明行里的实时数字（meme值 → 当前入侵概率）
	ModLoaderMod.install_script_extension(MOD_DIR + "extensions/text_bromeme.gd")
	# 外套外观：补一个"贴图来源名"，让动态生成的角色贴图能扛过读档
	# （原版只存 sprite.resource_path，而运行时纹理没有路径 → 读档后角色贴图消失）
	ModLoaderMod.install_script_extension(APPEARANCE_EXTENSION)
	# 和 FengLiu-FengAddMods（土豆随想）一起跑
	_install_fengaddmods_compat()


# =============================================================================
#  土豆随想（FengLiu-FengAddMods）适配
#
#  它的功能之一是「阻断别的 mod 的脚本扩展」。开着它的时候，它会把
#  The-BossRush 对 res://items/global/item_parent_data.gd 的扩展撤掉：
#
#    FengLiu-FengAddMods: Blocked item_parent_data.gd extension from The-BossRush
#
#  而这条扩展被撤掉之后，Godot 3 那边 ItemData / CharacterData 与
#  item_parent_data.gd 的继承关系就对不上了，原版一堆脚本会编译失败：
#
#    Parse Error: A value of type "item_parent_data.gd" will never be an instance of "ItemData"
#    （item_service / run_data / base_shop / item_description / tags_container …共 160+ 条）
#
#  结果就是整个游戏的核心单例加载不出来，商店、背包、我们的选择面板全都没了。
#
#  它在自己的 _init 里做阻断；各 mod 的 _init 顺序按目录名排（F 在 G 前面），
#  所以我们在自己的 _init 末尾把那条扩展重新装回去，正好赶在 ModLoader
#  统一应用扩展之前，把扩展链恢复成能跑的状态。
# =============================================================================
const FENG_MOD_DIR: String = "res://mods-unpacked/FengLiu-FengAddMods"
const BLOCKED_PARENT_EXTENSION: String = "res://mods-unpacked/The-BossRush/extensions/items/global/item_parent_data.gd"


func _install_fengaddmods_compat() -> void:
	var dir := Directory.new()
	if not dir.dir_exists(FENG_MOD_DIR):
		return

	var file := File.new()
	if not file.file_exists(BLOCKED_PARENT_EXTENSION):
		return

	ModLoaderMod.install_script_extension(BLOCKED_PARENT_EXTENSION)
	ModLoaderLog.info("检测到 FengLiu-FengAddMods（土豆随想）：重新装回它阻断的 item_parent_data 扩展", MOD_NAME)


# =============================================================================
#  中 / 英 / 日 / 韩 / 俄 翻译（效果文本）
#
#  角色名/道具名本来就有 NAME_LOCALES 那套多语言表。
#  这里补的是「效果说明」：专属/混沌道具、反抗孙笑川、挑战者成长，
#  以及 UI 的「取消」「入侵奖励」（中文本身当 key，调用点只需包一层 tr）。
# =============================================================================
const EFFECT_LOCALES: Array = ["zh", "en", "ja", "ko", "ru"]

const EFFECT_TEXTS: Dictionary = {
	"BROMEME_EFF_MEME_CORE": {
		"zh": "每购买一个道具，meme值 +3",
		"en": "Gain +3 meme value for every item you buy",
		"ja": "アイテムを1つ購入するごとにmeme値 +3",
		"ko": "아이템을 하나 구매할 때마다 meme 수치 +3",
		"ru": "+3 к meme за каждую купленную вещь",
	},
	"BROMEME_EFF_CHAOS": {
		"zh": "随机交换你的所有主属性，然后每项 +5",
		"en": "Randomly shuffle all your primary stats, then +5 to each",
		"ja": "主要ステータスを全てランダムに入れ替え、その後それぞれ +5",
		"ko": "모든 주 능력치를 무작위로 교환한 뒤 각각 +5",
		"ru": "Случайно перемешать все основные характеристики, затем +5 к каждой",
	},
	"BROMEME_EFF_RANDOM": {
		"zh": "随机获得两个 meme 道具（组合 / 改造属性）",
		"en": "Gain two random meme items (fusion / modified stats)",
		"ja": "ランダムなmemeアイテムを2つ獲得（合成／ステータス改変）",
		"ko": "meme 아이템 두 개를 무작위로 획득 (조합 / 능력치 개조)",
		"ru": "Получить два случайных meme-предмета (слияние / изменённые характеристики)",
	},
	"BROMEME_EFF_SELL": {
		"zh": "以 100% 的价格回收你的所有道具，额外 +25 收获、+35 meme值、全部主要属性 +5",
		"en": "Recycle all your items for 100% of their price, plus +25 harvesting, +35 meme value and +5 to every primary stat",
		"ja": "所持アイテムを全て100%の価格で換金、さらに収穫 +25・meme値 +35・全主要ステータス +5",
		"ko": "모든 아이템을 100% 가격으로 환급, 추가로 수확 +25, meme 수치 +35, 모든 주요 능력치 +5",
		"ru": "Продать все предметы за 100% их цены, плюс +25 к сбору, +35 к meme и +5 ко всем основным характеристикам",
	},
	"BROMEME_EFF_ENTROPY": {
		"zh": "每条主属性独立随机 ×0~3 倍（可能清零，也可能暴涨）",
		"en": "Every primary stat rolls x0~3 independently (may zero out or explode)",
		"ja": "各主要ステータスが独立に×0～3倍（0になることも急増することも）",
		"ko": "각 주 능력치가 독립적으로 ×0~3 (0이 되거나 폭증할 수 있음)",
		"ru": "Каждая основная характеристика случайно ×0~3 (может обнулиться или взлететь)",
	},
	"BROMEME_EFF_GAMBLER": {
		"zh": "50% 材料翻倍，50% 材料全部打水漂，额外 +30 meme值",
		"en": "50% chance to double your materials, 50% to lose them all, plus +30 meme value",
		"ja": "50%で素材が倍増、50%で全て失う、さらに meme値 +30",
		"ko": "50% 확률로 재료 두 배, 50% 확률로 전부 잃음, 추가로 meme 수치 +30",
		"ru": "50% — удвоить материалы, 50% — потерять всё, плюс +30 к meme",
	},
	"BROMEME_EFF_QUANTUM": {
		"zh": "把背包里所有道具换成同稀有度的另一件道具，额外获得 1~8 件道具、+25 meme值",
		"en": "Turns every item in your inventory into another item of the same tier, plus 1-8 extra items and +25 meme value",
		"ja": "所持アイテムを全て同じレアリティの別アイテムに変化させ、さらに1~8個のアイテムとmeme値 +25",
		"ko": "가방 속 모든 아이템을 같은 등급의 다른 아이템으로 바꾸고, 추가로 1~8개 아이템과 meme 수치 +25",
		"ru": "Превращает все предметы в другие предметы того же уровня, плюс 1-8 предметов и +25 к meme",
	},
	"BROMEME_EFF_SACRIFICE": {
		"zh": "随机两条主属性清零，其余每条 +5~+25",
		"en": "Two random primary stats are zeroed, every other one gains +5~+25",
		"ja": "ランダムな主要ステータス2つが0になり、他はそれぞれ +5～+25",
		"ko": "무작위 주 능력치 두 개가 0이 되고 나머지는 각각 +5~+25",
		"ru": "Две случайные основные характеристики обнуляются, остальные +5~+25",
	},
	"BROMEME_EFF_FKCS": {
		"zh": "下一波敌袭一开始必定触发孙笑川入侵",
		"en": "The next wave starts with a guaranteed Sun Xiaochuan invasion",
		"ja": "次のウェーブ開始時に必ず孫笑川の侵攻が発生",
		"ko": "다음 웨이브 시작 시 손샤오촨 침공이 반드시 발생",
		"ru": "Следующая волна начинается с гарантированного вторжения Сунь Сяочуаня",
	},
	"BROMEME_EFF_CHALLENGER": {
		"zh": "每击杀一个精英或首领：生命再生 +5、伤害 +5%",
		"en": "Every elite or boss kill: HP regeneration +5, damage +5%",
		"ja": "エリートまたはボスを撃破するごとに：HP再生 +5、ダメージ +5%",
		"ko": "정예 또는 보스를 처치할 때마다: 체력 재생 +5, 피해량 +5%",
		"ru": "За каждое убийство элиты или босса: регенерация HP +5, урон +5%",
	},
	"BROMEME_EFF_CHALLENGER_TEST": {
		"zh": "测试角色：与挑战者相同，但不携带苍与赫",
		"en": "Test character: same as the Challenger, but without Cang and He",
		"ja": "テスト用キャラ：挑戦者と同じだが、蒼と赫を所持しない",
		"ko": "테스트 캐릭터: 챌린저와 동일하지만 창과 혜가 없음",
		"ru": "Тестовый персонаж: как Претендент, но без Цан и Хэ",
	},
	"BROMEME_EFF_CHALLENGER_KNOCKBACK": {
		"zh": "每 1 秒击退周围的怪物",
		"en": "Knocks back nearby enemies once per second",
		"ja": "1秒ごとに周囲の敵をノックバックさせる",
		"ko": "1초마다 주변 적을 밀어냅니다",
		"ru": "Каждую секунду отбрасывает врагов вокруг",
	},	# 苍：引力球
	"BROMEME_EFF_CANG": {
		"zh": "对怪物和子弹有吸引力，对触碰到的怪物持续造成{0}（{1}）的伤害",
		"en": "Pulls in enemies and bullets; deals {0} ({1}) damage continuously to enemies it touches",
		"ja": "敵と弾を引き寄せ、触れた敵に{0}（{1}）の継続ダメージを与える",
		"ko": "적과 탄환을 끌어당기고, 닿은 적에게 {0}({1})의 지속 피해를 줍니다",
		"ru": "Притягивает врагов и пули, нанося касающимся врагам {0} ({1}) постоянного урона",
	},
	# 赫：斥力球
	"BROMEME_EFF_HE": {
		"zh": "对怪物和子弹有排斥力，对触碰到的怪物持续造成{0}（{1}）的伤害",
		"en": "Pushes away enemies and bullets; deals {0} ({1}) damage continuously to enemies it touches",
		"ja": "敵と弾を弾き飛ばし、触れた敵に{0}（{1}）の継続ダメージを与える",
		"ko": "적과 탄환을 밀어내고, 닿은 적에게 {0}({1})의 지속 피해를 줍니다",
		"ru": "Отталкивает врагов и пули, нанося касающимся врагам {0} ({1}) постоянного урона",
	},
	# 实时概率的文本模板（由 extensions/text_bromeme.gd 填 {0}）
	"BROMEME_INFO_MEME_CHANCE": {
		"zh": "当前 meme 入侵概率：{0}%",
		"en": "Current meme invasion chance: {0}%",
		"ja": "現在のmeme侵攻確率：{0}%",
		"ko": "현재 meme 침공 확률: {0}%",
		"ru": "Текущий шанс вторжения meme: {0}%",
	},
	# 属性详情的说明行：原版按 INFO_POS_STAT_<属性> / INFO_NEG_STAT_<属性> 查翻译，
	# 以前没登记所以直接显示 key（截图里那行 INFO_POS_STAT_MEME）。
	# 实测 meme=9 → 入侵概率 8.3%，约 0.92%/点。
	"INFO_POS_STAT_MEME": {
		"zh": "meme值越高，敌方 meme 入侵概率越高（每 1 点约 +0.92%）",
		"en": "Higher meme value means a higher chance of a meme invasion (about +0.92% per point)",
		"ja": "meme値が高いほど敵のmeme侵攻確率が上がる（1ポイントにつき約 +0.92%）",
		"ko": "meme 수치가 높을수록 적의 meme 침공 확률이 올라갑니다 (1포인트당 약 +0.92%)",
		"ru": "Чем выше meme, тем выше шанс вторжения meme (около +0.92% за единицу)",
	},
	"INFO_NEG_STAT_MEME": {
		"zh": "meme值越低，敌方 meme 入侵概率越低（每 1 点约 +0.92%）",
		"en": "Lower meme value means a lower chance of a meme invasion (about +0.92% per point)",
		"ja": "meme値が低いほど敵のmeme侵攻確率が下がる（1ポイントにつき約 +0.92%）",
		"ko": "meme 수치가 낮을수록 적의 meme 침공 확률이 낮아집니다 (1포인트당 약 +0.92%)",
		"ru": "Чем ниже meme, тем ниже шанс вторжения meme (около +0.92% за единицу)",
	},
	# UI 文案：中文本身当 key，调用点包一层 tr 即可
	"取消": {
		"zh": "取消", "en": "Cancel", "ja": "キャンセル", "ko": "취소", "ru": "Отмена",
	},
	"入侵奖励": {
		"zh": "入侵奖励", "en": "Invasion Reward", "ja": "侵攻ボーナス", "ko": "침공 보상", "ru": "Награда за вторжение",
	},
}


func _register_effect_translations() -> void:
	for locale in EFFECT_LOCALES:
		var translation := Translation.new()
		translation.locale = String(locale)
		for key in EFFECT_TEXTS.keys():
			var entry: Dictionary = EFFECT_TEXTS[key]
			var text: String = String(entry.get(String(locale), entry.get("en", "")))
			if text.empty():
				continue
			translation.add_message(String(key), text)
		TranslationServer.add_translation(translation)
	ModLoaderLog.info("效果文本翻译：%d 个 key × %d 种语言" % [EFFECT_TEXTS.size(), EFFECT_LOCALES.size()], MOD_NAME)


func _ready() -> void:
	_load_defaults()
	_register_effect_scripts()
	_register_effect_translations()
	call_deferred("_install_content")


func _load_defaults() -> void:
	_default_character_icon = load(DEFAULT_CHARACTER_ICON_PATH)
	_default_item_icon = load(DEFAULT_ITEM_ICON_PATH)
	var weapons: Array = []
	for path in DEFAULT_STARTING_WEAPON_PATHS:
		var weapon = load(path)
		if weapon != null:
			weapons.append(weapon)
	_default_starting_weapons = weapons


func _register_effect_scripts() -> void:
	for script_name in EFFECT_SCRIPTS:
		var path: String = COMPAT_EFFECTS_DIR + script_name
		var effect_script = load(path)
		if effect_script == null:
			ModLoaderLog.error("无法载入内置效果脚本: " + path, MOD_NAME)
			continue
		ItemService.effects.append(effect_script)


# -----------------------------------------------------------------------------
#  安装内容
# -----------------------------------------------------------------------------

func _install_content() -> void:
	if _installed:
		return
	_installed = true

	var entries: Array = _read_entries()
	if entries.empty():
		ModLoaderLog.error("resources 里没有读到任何内容", MOD_NAME)
		return

	_clean_brolab_leftovers(entries)

	var characters: Array = []
	var items: Array = []
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if int(value.get("item_type", 1)) == 0:
			var character = _build_character(value)
			if character != null:
				characters.append(character)
		else:
			var item = _build_item(value)
			if item != null:
				items.append(item)

	_register_characters(characters)
	_register_items(items)
	_register_meme_boss_codex()
	_register_meme_stat()
	_register_name_translations()
	ProgressData.load_game_file()

	ModLoaderLog.success(
		"已注册 %d 个角色 / %d 个物品" % [characters.size(), items.size()], MOD_NAME)
	_self_check(characters, items)


# 把 _name_keys 里收集到的 <id>.to_upper() -> 显示名 注册进 TranslationServer。
# 注册得越早越好：描述文本是渲染时查表的，只要在玩家打开界面之前注册就行，
# 但放在内容注册完的同一帧里最省心。
func _register_name_translations() -> void:
	if _name_keys.size() == 0:
		return

	var registered: int = 0
	for locale in NAME_LOCALES:
		var translation := Translation.new()
		translation.locale = locale
		for name_key in _name_keys:
			translation.add_message(name_key, String(_name_keys[name_key]))
		TranslationServer.add_translation(translation)
		registered += 1

	ModLoaderLog.info("名字翻译键 %d 个，覆盖 %d 个语言"
			% [_name_keys.size(), registered], MOD_NAME)


# -----------------------------------------------------------------------------
#  meme 值：自定义属性
#
#  土豆兄弟的"属性"就是 ItemService.stats 里的一串 StatData。
#  原版 stats_container._ready() 里对 is_dlc_stat 的属性会自动多建一行，
#  所以只要 stat_name 唯一 + append 进 ItemService.stats，属性面板就会自己
#  冒出「meme值」这一行，不需要改 UI。
#  图片走运行时读字节（mod 里的 png 没有导入缓存，直接 load 拿不到）。
# -----------------------------------------------------------------------------

const MEME_STAT_NAME: String = "stat_meme"
const MEME_STAT_PATH: String = MOD_DIR + "meme/stat_meme.tres"
const MEME_STAT_ICON_PATH: String = MOD_DIR + "meme/stat_meme_icon.png"
const MEME_STAT_DISPLAY: String = "meme值"


func _register_meme_stat() -> void:
	var stat = load(MEME_STAT_PATH)
	if stat == null:
		ModLoaderLog.error("meme 属性资源没读到：%s" % MEME_STAT_PATH, MOD_NAME)
		return

	var stat_hash: int = Keys.generate_hash(MEME_STAT_NAME)
	for existing in ItemService.stats:
		if existing != null and Keys.generate_hash(String(existing.stat_name)) == stat_hash:
			return

	var icon: Texture = _load_png_texture(MEME_STAT_ICON_PATH, 0)
	if icon != null:
		stat.icon = icon
		stat.small_icon = icon

	ItemService.stats.append(stat)

	# 让数值也能显示出来：原版 Text.text() 只给 keys_needing_operator 里的属性
	# 补 "+" 并把数值拼到名字前面（裂口就是 "+5 最大生命"）。自定义属性不登记
	# 就只会显示 "meme值"，看不到具体数值。
	if not Text.keys_needing_operator.has(MEME_STAT_NAME):
		Text.keys_needing_operator[MEME_STAT_NAME] = [0]

	_name_keys["STAT_MEME"] = MEME_STAT_DISPLAY
	ModLoaderLog.info("已注册属性 %s（%s）" % [MEME_STAT_DISPLAY, MEME_STAT_NAME], MOD_NAME)


# -----------------------------------------------------------------------------
#  清理 0.1.x 留在 brolab 里的残余
#
#  0.1.x 会把 resources/*.json 和 icons/*.png 拷进 user://brolab。
#  现在不写了，但升级上来的用户那 107 个 json + 107 张图标还在，白占地方。
#  这里只删「文件名和 my_id 都跟本 mod 当前内容完全对上」的 json，
#  以及这些 json 引用的、没有被其它内容引用的图标。
#  所以 BroLab 自己的内容、以及任何被它们引用的图标，一律不动。
# -----------------------------------------------------------------------------

func _brolab_dir() -> String:
	ProgressData.init_save_paths()
	var save_path: String = ProgressData.SAVE_PATH
	var last_splitter: int = save_path.find_last("/")
	if last_splitter < 0:
		return ""
	return save_path.left(last_splitter).get_base_dir().plus_file("brolab")


func _clean_brolab_leftovers(entries: Array) -> void:
	if not BROLAB_CLEANUP_ENABLED:
		return

	var brolab_dir: String = _brolab_dir()
	if brolab_dir == "":
		return

	var dir := Directory.new()
	if dir.open(brolab_dir) != OK:
		return  # 没装过 BroLab 内容，没什么可清的

	# 文件名 -> my_id（旧规则：文件名和 my_id 都对得上才认领）+ 纯 my_id 集合
	var mine: Dictionary = {}
	var mine_ids: Dictionary = {}
	for value in entries:
		var source_file: String = String(value.get("_source_file", ""))
		var my_id: String = String(value.get("my_id", ""))
		if my_id != "":
			mine_ids[my_id] = true
		if source_file != "" and my_id != "":
			mine[source_file] = my_id

	# brolab 里现在有哪些 json
	var present: Array = []
	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			present.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# 第一步：挑出属于本 mod 的旧 json。
	# 认领条件（两条任一成立即可，都是"两边 my_id 对得上"）：
	#   a) 文件名 + my_id 都对得上（0.1.x 时代直接拷进 brolab 的那批）
	#   b) 文件里的 my_id 跟本 mod 现在的某个 my_id 完全相同
	#      （2.32.0 改名前是 item_brolab_*，所以只在用户把 resources 换回旧 id 时才会命中）
	# 对不上的（用户自己用 BroLab 编辑器做的东西）一律保留。
	var doomed: Dictionary = {}  # 文件名 -> relative_icon_path
	var survivors: Array = []
	for existing in present:
		var data: Dictionary = _read_json(brolab_dir.plus_file(existing), false)
		var existing_id: String = String(data.get("my_id", ""))
		var claim_by_file: bool = mine.has(existing) and existing_id == mine[existing]
		var claim_by_id: bool = existing_id != "" and mine_ids.has(existing_id)
		if claim_by_file or claim_by_id:
			doomed[existing] = String(data.get("relative_icon_path", ""))
		else:
			survivors.append(existing)

	# 先把要删的清单打进日志（用户可以先看日志再决定，删错了也能从这里找回来）
	if not doomed.empty():
		var doomed_ids: Array = []
		for existing in doomed.keys():
			var d2: Dictionary = _read_json(brolab_dir.plus_file(existing), false)
			doomed_ids.append("%s(%s)" % [existing, String(d2.get("my_id", ""))])
		ModLoaderLog.info("brolab 里与本 mod my_id 对得上、准备清理的 %d 个：%s"
				% [doomed.size(), PoolStringArray(doomed_ids).join(", ")], MOD_NAME)

	if doomed.empty():
		return

	# 第二步：还活着的 BroLab 内容引用的图标必须保留
	var protected: Dictionary = {}
	for existing in survivors:
		var data: Dictionary = _read_json(brolab_dir.plus_file(existing), false)
		var icon_name: String = _icon_file_name(data)
		if icon_name != "":
			protected[icon_name] = true

	# 第三步：删 json，顺手删掉只被这些 json 引用的图标
	var removed: int = 0
	var removed_icons: int = 0
	for existing in doomed.keys():
		var icon_name: String = _icon_file_name({"relative_icon_path": doomed[existing]})
		if icon_name != "" and not protected.has(icon_name):
			if dir.remove(brolab_dir.plus_file("icons").plus_file(icon_name)) == OK:
				removed_icons += 1
		if dir.remove(brolab_dir.plus_file(existing)) == OK:
			removed += 1

	ModLoaderLog.info(
		"清理了 0.1.x 残留在 brolab 里的 %d 个 json + %d 张图标"
		% [removed, removed_icons], MOD_NAME)


func _icon_file_name(data: Dictionary) -> String:
	var relative: String = String(data.get("relative_icon_path", "")).replace("\\", "/")
	if relative == "":
		return ""
	return relative.get_file()


# 启动自检：内容、贴图、效果、id 唯一性、有没有重复项。
# 全部正常时只打一行 OK，有问题就把问题列出来。
func _self_check(characters: Array, items: Array) -> void:
	var problems: Array = []

	for character in characters:
		if character.icon == null:
			problems.append("角色没图标: " + character.my_id)
		if character.item_appearances.empty():
			problems.append("角色没外观: " + character.my_id)
		elif character.item_appearances[0].get_sprite() == null:
			problems.append("角色没身体贴图: " + character.my_id)
		if character.effects.empty():
			problems.append("角色没效果: " + character.my_id)
		if character.starting_weapons.empty():
			problems.append("角色没初始武器: " + character.my_id)

	for item in items:
		if item.icon == null:
			problems.append("物品没图标: " + item.my_id)
		if item.effects.empty():
			problems.append("物品没效果: " + item.my_id)

	problems.append_array(_check_registered("角色", characters, ItemService.characters))
	problems.append_array(_check_registered("物品", items, ItemService.items))

	_pet_art_self_check()
	_xuebao_stats_self_check()
	_pick_self_check()

	if problems.empty():
		ModLoaderLog.success("自检通过", MOD_NAME)
	else:
		for problem in problems:
			ModLoaderLog.error("自检: " + problem, MOD_NAME)


# 雪豹宠物换皮自检：实例化 Bonk 狗场景，确认脚本扩展挂上了、换皮代码能跑通。
# 只取节点不进场（不进树，所以不会触发宠物自己的 _ready / reload_data）。
func _pet_art_self_check() -> void:
	var scene = load(PET_BASE_SCENE_PATH)
	if scene == null:
		ModLoaderLog.error("宠物自检: 载入失败 " + PET_BASE_SCENE_PATH, MOD_NAME)
		return

	var info: Dictionary = {}
	var inst = scene.instance()
	if inst == null:
		ModLoaderLog.error("宠物自检: 实例化失败", MOD_NAME)
		return

	var has_ext: bool = inst.has_method("bromeme_apply_xuebao_art")
	info["扩展"] = has_ext
	if has_ext:
		info["换皮"] = bool(inst.call("bromeme_apply_xuebao_art"))

	var offset = null
	if has_ext:
		offset = inst.call("bromeme_get_offset_node")
	var body = null
	var collar = null
	if offset != null:
		body = offset.get_node_or_null("body")
		collar = offset.get_node_or_null("collar")
	info["body节点"] = body != null
	info["贴图换成ImageTexture"] = body != null and body.texture is ImageTexture
	info["collar节点"] = collar != null
	info["狗头已隐藏"] = collar != null and not collar.visible
	var script_path: String = "无"
	if inst.get_script() != null:
		script_path = str(inst.get_script().resource_path)
	info["实例脚本"] = script_path

	var text: String = ""
	for key in info.keys():
		text += "%s=%s " % [key, str(info[key])]
	ModLoaderLog.info("宠物自检: " + text, MOD_NAME)
	inst.free()


# 雪豹数值自检：普攻和爆炸的伤害/倍率是不是一样（json 里是两层嵌套覆盖）
func _xuebao_stats_self_check() -> void:
	for item in ItemService.items:
		if item == null or item.my_id != "item_bromeme_xb_478":
			continue
		if item.effects.empty():
			ModLoaderLog.error("雪豹自检: 没有效果", MOD_NAME)
			return

		var pet_effect = item.effects[0]
		var attack = pet_effect.get("weapon_stats")
		var explosion = pet_effect.get("explosion_effect")

		var attack_damage: int = -1
		var explosion_damage: int = -1
		var attack_scaling: Array = []
		var explosion_scaling: Array = []

		if attack != null:
			attack_damage = int(attack.get("damage"))
			attack_scaling = attack.get("scaling_stats")
		if explosion != null:
			var stats = explosion.get("stats")
			if stats != null:
				explosion_damage = int(stats.get("damage"))
				explosion_scaling = stats.get("scaling_stats")

		var same: bool = attack_damage == explosion_damage and str(attack_scaling) == str(explosion_scaling)
		ModLoaderLog.info("雪豹自检: 普攻 damage=%d scaling=%s ｜ 爆炸 damage=%d scaling=%s ｜ 一致=%s" % [
				attack_damage, str(attack_scaling), explosion_damage, str(explosion_scaling), str(same)], MOD_NAME)
		return

	ModLoaderLog.error("雪豹自检: 在物品表里找不到 item_bromeme_xb_478", MOD_NAME)


# 4 选 1 自检：三个脚本扩展有没有挂上 + 两种卡能不能造出来
func _pick_self_check() -> void:
	var info: Dictionary = {}

	var candidates: Array = []
	for item in ItemService.items:
		if item == null or not is_instance_valid(item):
			continue
		if not String(item.my_id).begins_with("item_bromeme_"):
			continue
		candidates.append(item)

	info["ItemService扩展"] = ItemService.has_method("bromeme_build_pick_cards")
	info["候选道具"] = candidates.size()

	if ItemService.has_method("bromeme_make_fusion_pick") and candidates.size() >= 2:
		var fusion = ItemService.call("bromeme_make_fusion_pick", candidates[0], candidates[1])
		if fusion != null:
			info["组合卡"] = "%s（效果%d）" % [str(fusion.name), fusion.effects.size()]
		else:
			info["组合卡"] = "造不出来"
	else:
		info["组合卡"] = "跳过"

	if ItemService.has_method("bromeme_make_swap_pick"):
		var swap_text: String = "候选里没有属性效果"
		for item in candidates:
			var swap = ItemService.call("bromeme_make_swap_pick", item)
			if swap != null:
				swap_text = "%s→%s（%d 条效果，换过：%s，文本：%s）" % [
						str(item.name), str(swap.name), swap.effects.size(), str(swap.effects[0].key), str(swap.effects[0].text_key)]
				break
		info["换属性卡"] = swap_text
	else:
		info["换属性卡"] = "扩展没挂上"

	if ItemService.has_method("bromeme_make_job_pick"):
		info["价值比表"] = "%d 条" % ItemService.BROMEME_STAT_WORTH.size()
		info["转职卡"] = "需要开局里才有主属性，启动时不测"
	else:
		info["转职卡"] = "扩展没挂上"

	var excluded: int = 0
	if ItemService.has_method("bromeme_stat_excluded"):
		for key in Utils.get_primary_stat_keys():
			if ItemService.call("bromeme_stat_excluded", int(key)):
				excluded += 1
	info["排除属性(击杀数)"] = excluded

	if ItemService.has_method("bromeme_make_combo_pick") and candidates.size() >= 2:
		var combo = ItemService.call("bromeme_make_combo_pick", candidates[0], candidates[1])
		if combo != null:
			info["改造组合卡"] = "%s（效果%d）" % [str(combo.name), combo.effects.size()]
		else:
			info["改造组合卡"] = "造不出来"
	else:
		info["改造组合卡"] = "跳过"

	info["面板脚本"] = load(PICK_UI_SCRIPT_PATH) != null
	info["升级卡场景"] = load("res://ui/menus/upgrades/upgrade_ui.tscn") != null

	var logo_file := File.new()
	info["logo图"] = logo_file.file_exists(PICK_LOGO_PATH)

	# 专属道具（4 个本 mod 的 + 原版蝾螈）
	var exclusive_found: int = 0
	for id in ItemService.BROMEME_EXCLUSIVE_IDS:
		if ItemService.get_item_from_id(Keys.generate_hash(String(id))) != null:
			exclusive_found += 1
	info["专属道具"] = "%d/%d" % [exclusive_found, ItemService.BROMEME_EXCLUSIVE_IDS.size()]

	var chaos_found: int = 0
	for id in ItemService.BROMEME_CHAOS_IDS:
		if ItemService.get_item_from_id(Keys.generate_hash(String(id))) != null:
			chaos_found += 1
	info["混沌道具"] = "%d/%d" % [chaos_found, ItemService.BROMEME_CHAOS_IDS.size()]

	if ItemService.has_method("bromeme_make_character_pick"):
		var char_pick = ItemService.call("bromeme_make_character_pick")
		info["角色卡"] = String(char_pick.name) if char_pick != null else "造不出来"
	else:
		info["角色卡"] = "扩展没挂上"

	if ItemService.has_method("bromeme_watermark_icon") and candidates.size() > 0:
		var watermarked = ItemService.call("bromeme_watermark_icon", candidates[0].icon)
		info["logo水印"] = watermarked != null and watermarked.get_width() == 96
	else:
		info["logo水印"] = "跳过"

	if ItemService.has_method("bromeme_make_draw_pick"):
		var draw = ItemService.call("bromeme_make_draw_pick")
		if draw != null:
			info["随机抽取卡"] = "%s（效果%d）" % [str(draw.name), draw.effects.size()]
		else:
			info["随机抽取卡"] = "抽不到"
	else:
		info["随机抽取卡"] = "跳过"

	var main_script = load("res://main.gd")
	info["main扩展"] = _script_has_method(main_script, "_bromeme_show_pick_panel")

	var text: String = ""
	for key in info.keys():
		text += "%s=%s " % [key, str(info[key])]
	ModLoaderLog.info("4选1自检: " + text, MOD_NAME)


func _script_has_method(script, method_name: String) -> bool:
	if script == null:
		return false
	for method in script.get_script_method_list():
		if String(method.get("name", "")) == method_name:
			return true
	return false


func _check_registered(label: String, mine: Array, pool: Array) -> Array:
	var problems: Array = []
	var my_ids: Dictionary = {}
	for element in mine:
		if my_ids.has(element.my_id):
			problems.append("%s id 重复: %s" % [label, element.my_id])
		my_ids[element.my_id] = true

	var live: int = 0
	for element in pool:
		if element != null and my_ids.has(element.my_id):
			live += 1
	if live != my_ids.size():
		problems.append("%s 数量不对: 期望 %d，实际 %d" % [label, my_ids.size(), live])
	return problems

# -----------------------------------------------------------------------------
#  读取 resources/
# -----------------------------------------------------------------------------

func _read_entries() -> Array:
	var entries: Array = []
	var files: Array = _read_index()
	if files.empty():
		files = _list_resource_files()
	if files.empty():
		return entries

	for file_name in files:
		var value: Dictionary = _read_json(RES_DIR + file_name)
		if value.empty():
			continue
		if not value.has("my_id") or not value.has("datas"):
			ModLoaderLog.error("跳过缺少 my_id/datas 的文件: " + file_name, MOD_NAME)
			continue
		value["_source_file"] = file_name
		entries.append(value)

	return entries


func _read_index() -> Array:
	var index: Dictionary = _read_json(INDEX_FILE)
	if index.empty():
		return []
	var files = index.get("files", [])
	if typeof(files) != TYPE_ARRAY:
		return []
	return files


func _list_resource_files() -> Array:
	var files: Array = []
	var dir := Directory.new()
	if dir.open(RES_DIR) != OK:
		ModLoaderLog.error("无法打开 " + RES_DIR, MOD_NAME)
		return files

	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext == "json" and not file_name.begins_with("_"):
				files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()
	return files


func _read_json(path: String, log_errors: bool = true) -> Dictionary:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		if log_errors:
			ModLoaderLog.error("无法打开 " + path, MOD_NAME)
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parsed = parse_json(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		if log_errors:
			ModLoaderLog.error("JSON 解析失败: " + path, MOD_NAME)
		return {}
	return parsed


# -----------------------------------------------------------------------------
#  贴图
# -----------------------------------------------------------------------------

func _source_stem(value: Dictionary) -> String:
	return String(value.get("_source_file", "")).get_basename()


func _art_path(value: Dictionary, kind: String) -> String:
	var stem: String = _source_stem(value)
	if stem == "":
		return ""
	match kind:
		"char":
			return ART_CHAR_DIR + stem + ".png"
		"body":
			return ART_BODY_DIR + stem + ".png"
		_:
			return ART_ITEM_DIR + stem + ".png"


# 优先用 mod 自带的 art/，再退回 resources/icons/ 原图（运行时缩放）
func _resolve_texture(value: Dictionary, kind: String, fallback: Texture) -> Texture:
	var art_path: String = _art_path(value, kind)
	var texture: Texture = _load_png_texture(art_path, ICON_SIZE)
	if texture != null:
		return texture

	var relative_icon: String = String(value.get("relative_icon_path", ""))
	if relative_icon != "":
		texture = _load_png_texture(RES_DIR + relative_icon, ICON_SIZE)
		if texture != null:
			return texture

	return fallback


# 局内身体贴图：art/body/ 优先，没有就和图标共用（比如只改了脸/背景的）
func _resolve_body_texture(value: Dictionary, fallback: Texture) -> Texture:
	var body: Texture = _load_png_texture(_art_path(value, "body"), ICON_SIZE)
	if body != null:
		return body
	return fallback


# 读 mod 里的 png 造纹理（运行时字节解码）。
#
# ⚠️ 注意：这样造出来的 ImageTexture **没有 resource_path**，而原版
#   ItemAppearanceData.serialize() 只存 `sprite.resource_path` —— 所以角色外观
#   必须额外记住"贴图来源名"，读档后重新合成挂回（见 extensions/item_appearance_bromeme.gd
#   与 player_run_data 扩展）。曾试过把纹理落盘成 .tres 再用 load 拿回带路径的纹理，
#   但 mod 是从 zip 挂成**虚拟 res://**、磁盘上没有可写目录（实测 err=19），此路不通。
func _load_png_texture(path: String, size: int) -> Texture:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]

	var file := File.new()
	if file.open(path, File.READ) != OK:
		_texture_cache[path] = null
		return null

	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		ModLoaderLog.error("不是有效的 PNG: " + path, MOD_NAME)
		_texture_cache[path] = null
		return null

	if size > 0 and (image.get_width() != size or image.get_height() != size):
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)

	var texture := ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	texture.set_meta("bromeme_art", true)
	_texture_cache[path] = texture
	return texture


# -----------------------------------------------------------------------------
#  构造数据
# -----------------------------------------------------------------------------

func _build_character(value: Dictionary) -> CharacterData:
	var item := CharacterData.new()
	item.max_nb = -1
	item.wanted_tags = value.get("wanted_tags", [])
	item.tier = 0  # COMMON，和 BroLab 一致

	var body: Texture = _resolve_texture(value, "char", _default_character_icon)
	item.icon = body
	# 局内身体贴图可以和图标不一样（例如李文亚只把局内图抠掉背景，图标保持原样）
	# 外观里额外记住"贴图来源名"：运行时纹理没有 resource_path，
	# 原版存档存不了它，读档时靠这个名字重新合成（见 item_appearance_bromeme.gd）
	item.item_appearances = [_make_body_appearance(_resolve_body_texture(value, body), _source_stem(value))]

	var starting_weapons: Array = _resolve_starting_weapons(value.get("starting_weapons", []))
	item.starting_weapons = starting_weapons
	# 初始道具（例如挑战者的苍/赫）：注册顺序是"先角色后物品"，
	# 所以这里记下 id，等物品都注册完再由 _resolve_all_starting_items() 填上。
	item.set_meta("bromeme_starting_item_ids", value.get("starting_items", []))

	item.set_meta("bromeme_character", true)

	var filled = _fill_common(item, value)
	if filled == null:
		return null
	return filled


func _build_item(value: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.max_nb = int(value.get("max_nb", -1))
	item.tags = value.get("tags", [])
	item.tier = _tier_from_number(int(value.get("tier", 0)))
	# ⚠ 语义是反的，别被字段名骗了（这是照抄 BroLab brolab_manager.gd:518 的写法）：
	#     json unlocked_by_default = 1  ->  can_be_looted = false  ->  不进商店
	#     json unlocked_by_default = 0  ->  can_be_looted = true   ->  进商店
	# 原版 ItemService.init_unlocked_pool() 第一行就是 `if not item.can_be_looted: continue`。
	# 当前 24 件（meme 专属/混沌 + 李文亚系列 + 研究方向…）= 1（不进商店），
	# 另外 71 件 = 0（进商店）。要整体对调只改两边这 95 个字段值即可。
	# json 里写 "no_loot": true 的道具（8 个 meme 面板专属道具）是特例：
	# 它们"图鉴已解锁 + 不进商店/宝箱"，两个状态是解耦的。
	var no_loot: bool = bool(value.get("no_loot", false))
	item.unlocked_by_default = true
	item.can_be_looted = (not no_loot) and not int(value.get("unlocked_by_default", 0)) == 1
	item.icon = _resolve_texture(value, "item", _default_item_icon)

	var filled = _fill_common(item, value)
	if filled == null:
		return null
	return filled


func _fill_common(item, value: Dictionary):
	var my_id: String = String(value.get("my_id", ""))
	if my_id == "":
		ModLoaderLog.error("内容缺少 my_id，已跳过", MOD_NAME)
		return null

	item.my_id = my_id
	var display_name: String = String(value.get("name", my_id))
	item.name = display_name
	# 同一份显示名也注册成 <my_id>.to_upper() 的翻译键，供效果描述引用
	# （见 _name_keys 的说明）。
	if display_name != "":
		_name_keys[my_id.to_upper()] = display_name
	item.value = int(value.get("price", 1))
	# 图鉴里一律显示为已解锁（用户 2.42.2 的要求，仍然成立）。
	# "进不进商店/宝箱"是**另一个独立字段**：_build_item() 里的 can_be_looted
	# （json "no_loot": true 会让它为 false，那 8 个 meme 面板专属道具就是这样）。
	# 两者解耦，所以"图鉴已解锁 + 不进商店"是一个合法组合。
	item.unlocked_by_default = true
	item.effects = _build_effects(value)
	item.my_id_hash = Keys.generate_hash(my_id)
	return item


func _tier_from_number(tier_number: int) -> int:
	match tier_number:
		0:
			return 0  # COMMON
		1:
			return 1  # UNCOMMON
		2:
			return 2  # RARE
		3:
			return 3  # LEGENDARY
		_:
			return 0


func _make_body_appearance(texture: Texture, stem: String = "") -> Resource:
	var appearance := ItemAppearanceData.new()
	appearance.sprite = texture
	# 记下贴图来源名（art/char/<stem>.png）—— 运行时纹理没有 resource_path，
	# 原版 serialize 存不了它，读档要靠这个名字重新合成贴图
	if stem != "" and appearance.get("bromeme_sprite_stem") != null:
		appearance.set("bromeme_sprite_stem", stem)
	# position 0 = OTHER：不会被同 position 的其它外观顶掉（SKIN=14 会被顶掉）
	appearance.position = 0
	appearance.display_priority = 4  # VERY_HIGH
	# depth 低一点，这样帽子和状态图标还能画在身上
	appearance.depth = 0.0
	appearance.is_character_appearance = true
	return appearance


func _resolve_starting_weapons(saved_ids) -> Array:
	var weapons: Array = []
	if typeof(saved_ids) == TYPE_ARRAY and not saved_ids.empty():
		for weapon_data in ItemService.weapons:
			if weapon_data.my_id in saved_ids:
				weapons.append(weapon_data)
			if weapons.size() >= saved_ids.size():
				break
	if weapons.empty():
		return _default_starting_weapons
	return weapons


# -----------------------------------------------------------------------------
#  效果
# -----------------------------------------------------------------------------

func _build_effects(value: Dictionary) -> Array:
	var effects: Array = []
	var datas = value.get("datas", [])
	if typeof(datas) != TYPE_ARRAY:
		return effects

	for data in datas:
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var effect = _build_effect(data)
		if effect != null:
			effects.append(effect)

	return effects


func _remap_resource_path(path: String) -> String:
	if path.begins_with(BROLAB_RES_PREFIX):
		return COMPAT_RES_PREFIX + path.substr(BROLAB_RES_PREFIX.length())
	return path


func _build_effect(data: Dictionary) -> Resource:
	var base_path: String = _remap_resource_path(String(data.get("base_resource_path", "")))
	var changed = data.get("changed_key_values", {})

	if base_path == "" or typeof(changed) != TYPE_DICTIONARY:
		return null

	var effect = load(base_path)
	if effect == null:
		ModLoaderLog.error("无法载入效果资源: " + base_path, MOD_NAME)
		return null

	if changed.empty():
		return effect

	var duplicated_effect = effect.duplicate()
	# json 可以指定自定义效果脚本（例如苍/赫要动态算伤害文本）。
	# 必须在 set 属性之前换脚本：换脚本会重置脚本实例，之后设的属性才落在新脚本上。
	# 原版就是这么挂的（pet_effect.gd 的 script 在 .tres 里），对副本调用是安全的。
	var effect_script_path: String = String(changed.get("effect_script", ""))
	if effect_script_path != "":
		var effect_script = load(effect_script_path)
		if effect_script != null:
			duplicated_effect.set_script(effect_script)
		else:
			ModLoaderLog.error("效果脚本载入失败: " + effect_script_path, MOD_NAME)

	for changed_key in changed.keys():
		var key_name: String = String(changed_key)
		if key_name == "effect_script":
			continue
		if not key_name.ends_with("_RESOURCE"):
			duplicated_effect.set(key_name, changed[changed_key])
		else:
			# 子资源同样走 _build_effect，所以 json 里可以嵌套多层
			# （雪豹就是 effect -> explosion_effect -> stats 两层）
			var child = changed[changed_key]
			if typeof(child) != TYPE_DICTIONARY:
				continue
			var child_resource = _build_effect(child)
			if child_resource == null:
				continue
			duplicated_effect.set(key_name.trim_suffix("_RESOURCE"), child_resource)

	# Effect.duplicate() 复制的是原资源的 key_hash/custom_key_hash，
	# 而我们刚刚改了 key（例如 "item_snake" -> "item_bromeme_yan_56"，
	# 或 "stat_elemental_damage" -> "stat_ranged_damage"）。
	# 不重算的话效果会挂到原版那个键上：文字看着对，实际加错属性 /
	# 给错初始武器。BroLab 只靠 Effect._init() 里那个 call_deferred 兜底，
	# 这里显式重算，行为与 json 的本意一致。
	if duplicated_effect.has_method("_generate_hashes"):
		duplicated_effect.call("_generate_hashes")

	return duplicated_effect


# -----------------------------------------------------------------------------
#  注册（照搬 BroLab add_items 的行为，只是不再经过 brolab 文件）
# -----------------------------------------------------------------------------

func _register_characters(characters: Array) -> void:
	_drop_already_registered(ItemService.characters, characters)

	for character in characters:
		ItemService.characters.append(character)

		var id_hash: int = Keys.generate_hash(character.my_id)
		if not ProgressData.characters_unlocked.has(id_hash):
			ProgressData.characters_unlocked.append(id_hash)

		var has_diff_info: bool = false
		for diff_info in ProgressData.difficulties_unlocked:
			if id_hash == diff_info.character_id_hash:
				has_diff_info = true
				break
		if not has_diff_info:
			var character_diff_info = CharacterDifficultyInfo.new(character.my_id)
			for zone in ZoneService.zones:
				if zone.unlocked_by_default:
					character_diff_info.zones_difficulty_info.append(ZoneDifficultyInfo.new(zone.my_id))
			_set_max_selectable_difficulty(character_diff_info)
			ProgressData.difficulties_unlocked.append(character_diff_info)


func _register_items(items: Array) -> void:
	_drop_already_registered(ItemService.items, items)

	for item in items:
		ItemService.items.append(item)

		var id_hash: int = Keys.generate_hash(item.my_id)
		if item.unlocked_by_default and not ProgressData.items_unlocked.has(id_hash):
			ProgressData.items_unlocked.append(id_hash)

	ItemService.init_unlocked_pool()

	# 临时诊断（查完删除）：确认 8 件 meme 面板道具在 ItemService.items 里的真实 id
	var meme_ids: Array = []
	for it in ItemService.items:
		if it != null and is_instance_valid(it) and String(it.my_id).begins_with("item_bromeme_meme_"):
			meme_ids.append(String(it.my_id))
	ModLoaderLog.info("meme 道具 id 探针：共 %d 件 -> %s" % [
			meme_ids.size(), PoolStringArray(meme_ids).join(", ")], MOD_NAME)

	# 诊断：看清"解锁池"到底有没有把我们的道具算进去（物品全锁的排查用）
	var default_unlocked: int = 0
	var ours_missing: int = 0
	for item in items:
		if item == null:
			continue
		var ih: int = Keys.generate_hash(item.my_id)
		if item.unlocked_by_default:
			default_unlocked += 1
		if not ProgressData.items_unlocked.has(ih):
			ours_missing += 1
	ModLoaderLog.info("解锁诊断：本 mod 道具 %d 件（其中 unlocked_by_default %d 件），ProgressData.items_unlocked 共 %d 条，未在解锁表里的 %d 件" % [
			items.size(), default_unlocked, ProgressData.items_unlocked.size(), ours_missing], MOD_NAME)

	# 诊断：json 里标了 "no_loot": true 的道具（8 件 meme 面板专属道具）
	# 要求：图鉴已解锁（unlocked_by_default = true）+ 不进商店池/宝箱（can_be_looted = false）。
	# 注意"在表"可能为 True 是正常的 —— 决定能不能进池的是 can_be_looted，不是解锁表。
	var no_loot_names: Array = []
	var no_loot_bad: int = 0
	for item in items:
		if item == null or item.can_be_looted:
			continue
		var ih2: int = Keys.generate_hash(item.my_id)
		if not item.unlocked_by_default:
			no_loot_bad += 1
		no_loot_names.append("%s(解锁=%s,在表=%s)" % [
				item.my_id, str(item.unlocked_by_default), str(ProgressData.items_unlocked.has(ih2))])
	ModLoaderLog.info("不进池道具诊断：%d 件（其中图鉴未解锁的 %d 件）-> %s" % [
			no_loot_names.size(), no_loot_bad, PoolStringArray(no_loot_names).join(", ")], MOD_NAME)

	# 物品都注册完了，现在才能把角色的"初始道具"填上
	# （注册顺序是先角色后物品，所以 _build_character 那一步只能先记住 id）
	_resolve_all_starting_items()


# 把角色 json 里 starting_items 记下的 id 解析成真的 ItemData
func _resolve_all_starting_items() -> void:
	var filled: int = 0
	for character in ItemService.characters:
		if character == null or not is_instance_valid(character):
			continue
		var ids = character.get_meta("bromeme_starting_item_ids", [])
		if typeof(ids) != TYPE_ARRAY or ids.empty():
			continue
		var resolved: Array = []
		for item_id in ids:
			var item = ItemService.get_item_from_id(Keys.generate_hash(String(item_id)))
			if item != null:
				resolved.append(item)
			else:
				ModLoaderLog.error("初始道具找不到: %s（角色 %s）" % [item_id, character.my_id], MOD_NAME)
		character.starting_items = resolved
		filled += resolved.size()
		# 临时诊断：把角色的效果自定义键打出来 —— 原版 add_starting_items_and_weapons()
		# 只认 custom_key == "starting_item" 的效果，starting_items 字段只用于界面显示（查完删除）
		var ck_list: Array = []
		for ef in character.effects:
			if ef != null and is_instance_valid(ef) and String(ef.custom_key) != "":
				ck_list.append(String(ef.custom_key))
		ModLoaderLog.info("初始道具探针：角色=%s starting_items=%d 件，自定义键效果=[%s]" % [
				character.my_id, resolved.size(), PoolStringArray(ck_list).join(", ")], MOD_NAME)
	if filled > 0:
		ModLoaderLog.info("已填入初始道具 %d 件" % filled, MOD_NAME)


# 去重：如果 ItemService 里已经有同 my_id 的内容（旧版本往 brolab 拷过一份、
# 或者 mod 被加载了两次），先把旧的删掉再放我们这份。
# 这样无论用户有没有清理过 brolab，都不会出现两个同名角色/物品；
# 而且留下来的永远是我们这份（带局内贴图的那份）。
func _drop_already_registered(elements: Array, incoming: Array) -> void:
	var incoming_ids: Dictionary = {}
	for element in incoming:
		if element != null:
			incoming_ids[element.my_id] = true

	if incoming_ids.empty():
		return

	var dropped: Array = []
	var index: int = elements.size() - 1
	while index >= 0:
		var element = elements[index]
		if element != null and incoming_ids.has(element.my_id):
			dropped.append(element.my_id)
			elements.remove(index)
		index -= 1

	if not dropped.empty():
		ModLoaderLog.info(
			"清理了 %d 个重复项（多半是旧版 brolab 残留）" % dropped.size(), MOD_NAME)


func _set_max_selectable_difficulty(difficulty) -> void:
	var overall_max_selectable_difficulty: int = 0
	for difficulty_info in ProgressData.difficulties_unlocked:
		for zone_difficulty_info in difficulty_info.zones_difficulty_info:
			overall_max_selectable_difficulty = int(max(
				overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for zone_difficulty_info in difficulty.zones_difficulty_info:
		if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
			zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty


# -----------------------------------------------------------------------------
#  图鉴（codex）：把四个 memeboss 注册成敌人条目
#
#  图鉴里的敌人列表读的是 ItemService.entities（menu_codex.gd），条目要求：
#   · my_id 必须等于 boss 场景里的 enemy_id（meme_sunxiaochuan / meme_wangyuan /
#     meme_van / meme_hun5），因为 main.gd 用 enemy.enemy_id_hash 往
#     ProgressData.killed_enemies 记数，靠它对上"已击杀 N 只"
#   · name / behaviour_description 在 entity_description.gd 里是**直接赋值**给
#     Label.text 的，不查翻译表 —— 写翻译键就会原样显示成 key，所以这里直接写文本
#   · stats 指向 boss 自己的 *_stats.tres，图鉴里的血量/速度/伤害自动就对上了
#   · icon 走运行时读 PNG（mod 里的 png 没有导入缓存，load() 拿不到）
# -----------------------------------------------------------------------------

const ITEM_ENEMY_SCRIPT_PATH: String = "res://entities/units/enemies/ItemEnemy.gd"
const MEME_BOSS_CODEX_ICON_SIZE: int = 96

const MEME_BOSS_CODEX: Array = [
	{
		"id": "meme_sunxiaochuan",
		"name": "孙笑川",
		"behaviour": "把子弹摆成 N→M→S→L 再一起冲脸；半血后趁弹幕间隙冲刺",
		"stats": "meme/content/enemies/sunxiaochuan/sunxiaochuan_stats.tres",
		"icon": "meme/content/enemies/sunxiaochuan/sunxiaochuan.png",
	},
	{
		"id": "meme_wangyuan",
		"name": "王源",
		"behaviour": "三根烟（半血后两根）错峰吐椭圆 / 扇形 / 三列线性弹幕，半血后变慢并随机游走",
		"stats": "meme/content/enemies/wangyuan/wangyuan_stats.tres",
		"icon": "meme/content/enemies/wangyuan/wangyuan.png",
	},
	{
		"id": "meme_van",
		"name": "Van",
		"behaviour": "2 短 + 1 长连续冲刺，冷却期扇形弹幕；半血后起手两侧三连 + ♂ 弹幕",
		"stats": "meme/content/enemies/van/van_stats.tres",
		"icon": "meme/content/enemies/van/van.png",
	},
	{
		"id": "meme_hun5",
		"name": "魂5",
		"behaviour": "镰刀回旋 / 关刀横扫 / 一角鲸尖刺扇 / 后撤 + 激光 + 红色弩箭连发",
		"stats": "meme/content/enemies/hun5/hun5_stats.tres",
		"icon": "meme/content/enemies/hun5/hun5.png",
	},
	{
		"id": "meme_panren",
		"name": "叛忍",
		"behaviour": "瞬移到身后并在路径上撒尖刺 / 尖刺接冲刺 / 连续投掷红色手里剑 / 分散投掷手里剑",
		"stats": "meme/content/enemies/panren/panren_stats.tres",
		"icon": "meme/content/enemies/panren/panren.png",
	},
]


func _register_meme_boss_codex() -> void:
	var enemy_script = load(ITEM_ENEMY_SCRIPT_PATH)
	if enemy_script == null:
		ModLoaderLog.error("图鉴：找不到 %s" % ITEM_ENEMY_SCRIPT_PATH, MOD_NAME)
		return

	if ItemService.entities == null:
		ItemService.entities = []

	var entries: Array = []
	for data in MEME_BOSS_CODEX:
		var stats = load(MOD_DIR + String(data["stats"]))
		if stats == null:
			ModLoaderLog.error("图鉴：读不到 %s" % String(data["stats"]), MOD_NAME)
			continue

		var entry = enemy_script.new()
		entry.my_id = String(data["id"])
		entry.my_id_hash = Keys.generate_hash(entry.my_id)
		# 直接写显示文本：图鉴的这两行不做翻译查表（写 key 就会显示成 key）
		entry.name = String(data["name"])
		entry.behaviour_description = String(data["behaviour"])
		entry.icon = _load_png_texture(MOD_DIR + String(data["icon"]), MEME_BOSS_CODEX_ICON_SIZE)
		entry.stats = stats
		entry.tier = 3                       # LEGENDARY：图鉴边框颜色
		entry.value = 10
		entry.unlocked_by_default = false
		entry.can_be_looted = true
		entry.is_lockable = true
		entry.unlock_codex_descr_after_get_it = 1
		entry.is_cursed = false
		entry.curse_factor = 0.0
		entry.tracking_text = ""
		entry.effects = []
		entry.show_hp = true
		entry.show_dammage = true
		entry.show_speed = true
		entry.show_knoback_resistance = true
		entry.show_material_dropped = true
		entry.is_boss = false                # 四个都是按精英刷出来的（is_elite = true）
		entry.is_elite = true
		entries.append(entry)

	if entries.empty():
		return

	_drop_already_registered(ItemService.entities, entries)
	for entry in entries:
		ItemService.entities.append(entry)

	ModLoaderLog.info("图鉴：已注册 %d 个 memeboss" % entries.size(), MOD_NAME)
